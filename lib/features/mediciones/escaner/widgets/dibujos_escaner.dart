// lib/features/mediciones/escaner/widgets/dibujos_escaner.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/tema/tokens.dart';
import '../extractor_de_cuadros.dart';

/// La ilustración del modo dedo: la espalda del teléfono con la cámara y el
/// flash, y la yema cubriendo los dos.
class DibujoDedo extends StatelessWidget {
  final double alto;

  const DibujoDedo({super.key, this.alto = 170});

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Ilustración: la yema del dedo índice cubre la cámara trasera y el '
        'flash a la vez',
    child: SizedBox(
      height: alto,
      child: AspectRatio(
        aspectRatio: 0.75,
        child: CustomPaint(painter: _PintorDedo(AppColors.acentoClaro)),
      ),
    ),
  );
}

class _PintorDedo extends CustomPainter {
  final Color acento;

  _PintorDedo(this.acento);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // El teléfono, de espaldas.
    final telefono = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.04, w * 0.64, h * 0.92),
      Radius.circular(w * 0.1),
    );
    canvas.drawRRect(telefono, Paint()..color = AppColors.tarjeta);
    canvas.drawRRect(
      telefono,
      Paint()
        ..color = AppColors.bordeCampo
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // La cámara y el flash.
    final camara = Offset(w * 0.36, h * 0.16);
    final flash = Offset(w * 0.36, h * 0.27);
    canvas.drawCircle(camara, w * 0.07, Paint()..color = AppColors.lente);
    canvas.drawCircle(
      camara,
      w * 0.07,
      Paint()
        ..color = AppColors.bordeCampo
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(flash, w * 0.035, Paint()..color = AppColors.alerta);

    // La yema, cubriendo los dos, con el resplandor rojo del flash.
    final centro = Offset(w * 0.38, h * 0.22);
    canvas.drawCircle(
      centro,
      w * 0.2,
      Paint()
        ..color = acento.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawOval(
      Rect.fromCenter(center: centro, width: w * 0.3, height: h * 0.26),
      Paint()..color = AppColors.yema.withValues(alpha: 0.92),
    );
    // El resto del dedo, hacia abajo.
    final dedo = Path()
      ..moveTo(w * 0.24, h * 0.24)
      ..lineTo(w * 0.22, h * 0.98)
      ..lineTo(w * 0.54, h * 0.98)
      ..lineTo(w * 0.53, h * 0.24)
      ..close();
    canvas.drawPath(
      dedo,
      Paint()..color = AppColors.yema.withValues(alpha: 0.92),
    );
  }

  @override
  bool shouldRepaint(covariant _PintorDedo antes) => antes.acento != acento;
}

/// El óvalo del modo rostro sobre la vista de la cámara: oscurece lo de
/// fuera y marca el borde. Usa el mismo [Ovalo] que el extractor, así lo
/// que la persona encaja es lo que se mide.
class OvaloDelRostro extends StatelessWidget {
  final Ovalo ovalo;
  final Color color;

  const OvaloDelRostro({
    super.key,
    this.ovalo = const Ovalo(),
    required this.color,
  });

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PintorOvalo(ovalo, color), size: Size.infinite);
}

class _PintorOvalo extends CustomPainter {
  final Ovalo ovalo;
  final Color color;

  _PintorOvalo(this.ovalo, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(ovalo.cx * size.width, ovalo.cy * size.height),
      width: 2 * ovalo.rx * size.width,
      height: 2 * ovalo.ry * size.height,
    );
    final fuera = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(rect);
    canvas.drawPath(fuera, Paint()..color = AppColors.veloOvalo);
    canvas.drawOval(
      rect,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorOvalo antes) =>
      antes.color != color || antes.ovalo != ovalo;
}

/// La ilustración del modo rostro: una cara dentro del óvalo.
class DibujoRostro extends StatelessWidget {
  final double alto;

  const DibujoRostro({super.key, this.alto = 170});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Ilustración: el rostro dentro del óvalo, de frente y con buena luz',
    child: SizedBox(
      height: alto,
      child: AspectRatio(
        aspectRatio: 0.75,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.tarjeta,
            borderRadius: BorderRadius.circular(18),
          ),
          child: CustomPaint(painter: _PintorCara(AppColors.acentoClaro)),
        ),
      ),
    ),
  );
}

class _PintorCara extends CustomPainter {
  final Color acento;

  _PintorCara(this.acento);

  @override
  void paint(Canvas canvas, Size size) {
    const ovalo = Ovalo();
    final w = size.width;
    final h = size.height;
    final cara = Rect.fromCenter(
      center: Offset(ovalo.cx * w, ovalo.cy * h),
      width: 2 * ovalo.rx * w * 0.86,
      height: 2 * ovalo.ry * h * 0.92,
    );
    canvas.drawOval(
      cara,
      Paint()..color = AppColors.yema.withValues(alpha: 0.85),
    );
    // Las regiones que se miden: la frente y las mejillas.
    final region = Paint()..color = acento.withValues(alpha: 0.35);
    for (final r in ovalo.regiones) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(r.x0 * w, r.y0 * h, r.x1 * w, r.y1 * h),
          const Radius.circular(6),
        ),
        region,
      );
    }
    final borde = Rect.fromCenter(
      center: Offset(ovalo.cx * w, ovalo.cy * h),
      width: 2 * ovalo.rx * w,
      height: 2 * ovalo.ry * h,
    );
    canvas.drawOval(
      borde,
      Paint()
        ..color = acento
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorCara antes) => antes.acento != acento;
}

/// La onda del pulso en vivo.
class OndaEnVivo extends StatelessWidget {
  final List<double> onda;
  final Color color;
  final double alto;

  const OndaEnVivo({
    super.key,
    required this.onda,
    required this.color,
    this.alto = 90,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: alto,
    width: double.infinity,
    child: CustomPaint(painter: _PintorOnda(onda, color)),
  );
}

class _PintorOnda extends CustomPainter {
  final List<double> onda;
  final Color color;

  _PintorOnda(this.onda, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final medio = size.height / 2;
    canvas.drawLine(
      Offset(0, medio),
      Offset(size.width, medio),
      Paint()
        ..color = AppColors.bordeCampo
        ..strokeWidth = 1,
    );
    if (onda.length < 2) return;

    final trazo = Path();
    for (var i = 0; i < onda.length; i++) {
      final x = size.width * i / (onda.length - 1);
      final y = medio - onda[i].clamp(-1, 1) * (size.height * 0.42);
      if (i == 0) {
        trazo.moveTo(x, y);
      } else {
        trazo.lineTo(x, y);
      }
    }
    canvas.drawPath(
      trazo,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorOnda antes) =>
      !identical(antes.onda, onda) || antes.color != color;
}

/// El círculo que late mientras se mide con el dedo: no hay vista previa
/// (con el dedo encima solo se vería rojo).
class LatidoDelDedo extends StatefulWidget {
  final Color color;

  const LatidoDelDedo({super.key, required this.color});

  @override
  State<LatidoDelDedo> createState() => _LatidoDelDedoState();
}

class _LatidoDelDedoState extends State<LatidoDelDedo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animacion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _animacion.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _animacion,
    builder: (context, _) {
      final escala = 0.9 + 0.1 * math.sin(_animacion.value * math.pi);
      return Transform.scale(
        scale: escala,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [widget.color, widget.color.withValues(alpha: 0.15)],
            ),
          ),
          child: const Icon(
            Icons.fingerprint_rounded,
            color: Colors.white,
            size: 54,
          ),
        ),
      );
    },
  );
}
