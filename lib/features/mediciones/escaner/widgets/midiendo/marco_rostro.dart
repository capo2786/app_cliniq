// lib/features/mediciones/escaner/widgets/midiendo/marco_rostro.dart

import 'package:flutter/material.dart';

import '../../../../../core/tema/tokens.dart';
import '../../rostro/guia_encuadre.dart';

/// El marco grande donde va la cara: el 80 % del ancho, en proporción de
/// rostro, centrado en [centroDelMarco] (un poco arriba del medio, para
/// dejar sitio al panel de abajo). Si no cabe a lo alto, se achica.
Rect marcoEn(Size pantalla) {
  var ancho = pantalla.width * 0.8;
  var alto = ancho / 0.78;
  final maximo = pantalla.height * 0.56;
  if (alto > maximo) {
    alto = maximo;
    ancho = alto * 0.78;
  }
  return Rect.fromCenter(
    center: Offset(pantalla.width / 2, pantalla.height * centroDelMarco.y),
    width: ancho,
    height: alto,
  );
}

/// Cómo está el encuadre, para el color de las esquinas: blanco al buscar,
/// ámbar al ajustar y verde al medir.
enum EstadoDelMarco { buscando, ajustando, midiendo }

/// La viñeta oscura fuera del marco y las cuatro esquinas, que «respiran»
/// (escala de 1,00 a 1,03) y cambian de color con una transición.
class MarcoConEsquinas extends StatefulWidget {
  final EstadoDelMarco estado;

  const MarcoConEsquinas({super.key, required this.estado});

  @override
  State<MarcoConEsquinas> createState() => _MarcoConEsquinasState();
}

class _MarcoConEsquinasState extends State<MarcoConEsquinas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _respiro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _respiro.stop();
    } else if (!_respiro.isAnimating) {
      _respiro.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _respiro.dispose();
    super.dispose();
  }

  Color get _color => switch (widget.estado) {
    EstadoDelMarco.buscando => AppColors.texto,
    EstadoDelMarco.ajustando => AppColors.alerta,
    EstadoDelMarco.midiendo => AppColors.exito,
  };

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: _color),
      duration: const Duration(milliseconds: 420),
      builder: (context, color, _) => AnimatedBuilder(
        animation: _respiro,
        builder: (context, _) => CustomPaint(
          key: const Key('escaner-esquinas'),
          size: Size.infinite,
          painter: _PintorMarco(
            color: color ?? _color,
            escala: 1 + 0.03 * Curves.easeInOut.transform(_respiro.value),
          ),
        ),
      ),
    );
  }
}

class _PintorMarco extends CustomPainter {
  final Color color;
  final double escala;

  _PintorMarco({required this.color, required this.escala});

  @override
  void paint(Canvas canvas, Size size) {
    final base = marcoEn(size);
    final marco = Rect.fromCenter(
      center: base.center,
      width: base.width * escala,
      height: base.height * escala,
    );
    final radio = marco.width * 0.16;

    // La viñeta: oscuro fuera del marco.
    final fuera = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(base, Radius.circular(radio)));
    canvas.drawPath(fuera, Paint()..color = AppColors.veloOvalo);

    // Las cuatro esquinas: un arco y dos tramos rectos cada una.
    final lado = marco.shortestSide * 0.16;
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final l = marco.left, t = marco.top, r = marco.right, b = marco.bottom;
    final esquinas = Path()
      // Arriba a la izquierda.
      ..moveTo(l, t + radio + lado)
      ..lineTo(l, t + radio)
      ..arcToPoint(Offset(l + radio, t), radius: Radius.circular(radio))
      ..lineTo(l + radio + lado, t)
      // Arriba a la derecha.
      ..moveTo(r - radio - lado, t)
      ..lineTo(r - radio, t)
      ..arcToPoint(Offset(r, t + radio), radius: Radius.circular(radio))
      ..lineTo(r, t + radio + lado)
      // Abajo a la derecha.
      ..moveTo(r, b - radio - lado)
      ..lineTo(r, b - radio)
      ..arcToPoint(Offset(r - radio, b), radius: Radius.circular(radio))
      ..lineTo(r - radio - lado, b)
      // Abajo a la izquierda.
      ..moveTo(l + radio + lado, b)
      ..lineTo(l + radio, b)
      ..arcToPoint(Offset(l, b - radio), radius: Radius.circular(radio))
      ..lineTo(l, b - radio - lado);
    canvas.drawPath(esquinas, trazo);
  }

  @override
  bool shouldRepaint(covariant _PintorMarco antes) =>
      antes.color != color || antes.escala != escala;
}

/// La línea de barrido: recorre el marco de arriba abajo cada ~2,5 s. No
/// sale de ninguna detección: es solo una señal de que se está midiendo.
/// Con las animaciones apagadas del sistema no se dibuja.
class LineaDeBarrido extends StatefulWidget {
  final Color color;

  const LineaDeBarrido({super.key, required this.color});

  @override
  State<LineaDeBarrido> createState() => _LineaDeBarridoState();
}

class _LineaDeBarridoState extends State<LineaDeBarrido>
    with SingleTickerProviderStateMixin {
  late final AnimationController _avance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _avance.stop();
    } else if (!_avance.isAnimating) {
      _avance.repeat();
    }
  }

  @override
  void dispose() {
    _avance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _avance,
      builder: (context, _) => CustomPaint(
        key: const Key('escaner-barrido'),
        size: Size.infinite,
        painter: _PintorBarrido(
          avance: Curves.easeInOut.transform(_avance.value),
          color: widget.color,
        ),
      ),
    );
  }
}

class _PintorBarrido extends CustomPainter {
  final double avance;
  final Color color;

  _PintorBarrido({required this.avance, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final marco = marcoEn(size).deflate(10);
    final y = marco.top + marco.height * avance;
    // El brillo detrás de la línea, que se desvanece hacia arriba.
    final estela = Rect.fromLTRB(marco.left, y - 36, marco.right, y);
    canvas.drawRect(
      estela,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.22)],
        ).createShader(estela),
    );
    final linea = Rect.fromLTRB(marco.left, y - 1, marco.right, y + 1);
    canvas.drawRect(
      linea,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0.9),
            color.withValues(alpha: 0),
          ],
        ).createShader(linea),
    );
  }

  @override
  bool shouldRepaint(covariant _PintorBarrido antes) =>
      antes.avance != avance || antes.color != color;
}
