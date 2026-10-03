// lib/features/mediciones/escaner/widgets/midiendo/malla_rostro.dart

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../../../core/tema/tokens.dart';
import '../../rostro/delaunay.dart';
import '../../rostro/geometria.dart';
import '../../rostro/rostro_detectado.dart';
import '../../rostro/suavizado.dart';

/// La malla de alambre sobre la cara: triángulos finos entre los puntos de
/// los contornos que **detectó ML Kit** y nada más (sin detección no se
/// dibuja nada). Los puntos brillan y laten al ritmo de la FC en vivo; sin
/// ella, con un ritmo neutro y lento.
///
/// ML Kit detecta ~10 veces por segundo; entre una detección y otra los
/// puntos se mueven suaves ([SuavizadorDePuntos]) a 60 cuadros por
/// segundo. La malla aparece y desaparece con un fundido. Con las
/// animaciones del sistema apagadas no hay latido ni recorrido: los puntos
/// van directo a cada detección.
class MallaDelRostro extends StatefulWidget {
  final ValueListenable<RostroDetectado?> rostro;

  /// La FC en vivo (lpm), si ya se puede enseñar.
  final double? fc;

  final Color color;

  const MallaDelRostro({
    super.key,
    required this.rostro,
    required this.color,
    this.fc,
  });

  /// El latido cuando todavía no hay FC: lento y neutro.
  static const double ritmoNeutro = 45;

  @override
  State<MallaDelRostro> createState() => _MallaDelRostroState();
}

class _MallaDelRostroState extends State<MallaDelRostro>
    with SingleTickerProviderStateMixin {
  final SuavizadorDePuntos _suavizador = SuavizadorDePuntos();
  late final Ticker _ticker = createTicker(_alTic);
  List<(int, int)> _aristas = const [];
  double _anchoImagen = 1;
  double _altoImagen = 1;
  bool _visible = false;
  Duration _anterior = Duration.zero;
  double _fase = 0;
  bool _sinAnimaciones = false;

  @override
  void initState() {
    super.initState();
    widget.rostro.addListener(_alDetectar);
    _alDetectar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sinAnimaciones = MediaQuery.disableAnimationsOf(context);
    if (_sinAnimaciones) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _anterior = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant MallaDelRostro antes) {
    super.didUpdateWidget(antes);
    if (antes.rostro != widget.rostro) {
      antes.rostro.removeListener(_alDetectar);
      widget.rostro.addListener(_alDetectar);
    }
  }

  @override
  void dispose() {
    widget.rostro.removeListener(_alDetectar);
    _ticker.dispose();
    super.dispose();
  }

  void _alDetectar() {
    final rostro = widget.rostro.value;
    final puntos = rostro?.puntos ?? const <Punto>[];
    if (rostro == null || puntos.length < 3) {
      if (_visible) setState(() => _visible = false);
      return;
    }
    // Una cara que vuelve no viaja desde donde se fue: salta.
    if (!_visible) _suavizador.limpiar();
    _suavizador.fijarObjetivo(puntos);
    if (_sinAnimaciones) _suavizador.avanzar(const Duration(days: 1));
    setState(() {
      _aristas = aristasDe(triangular(puntos));
      _anchoImagen = rostro.anchoImagen;
      _altoImagen = rostro.altoImagen;
      _visible = true;
    });
  }

  void _alTic(Duration transcurrido) {
    final dt = transcurrido - _anterior;
    _anterior = transcurrido;
    final lpm = widget.fc ?? MallaDelRostro.ritmoNeutro;
    _fase = (_fase + dt.inMicroseconds / 1e6 * lpm / 60) % 1;
    _suavizador.avanzar(dt);
    if (_visible || !_suavizador.vacio) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Un latido: sube rápido y baja; entre latidos, en reposo.
    final pulso = _sinAnimaciones
        ? 0.0
        : math.pow(math.max(0.0, math.cos(2 * math.pi * _fase)), 6).toDouble();
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 320),
      child: CustomPaint(
        key: const Key('escaner-malla'),
        size: Size.infinite,
        painter: _PintorMalla(
          puntos: _suavizador.puntos,
          aristas: _aristas,
          anchoImagen: _anchoImagen,
          altoImagen: _altoImagen,
          pulso: pulso,
          color: widget.color,
        ),
      ),
    );
  }
}

class _PintorMalla extends CustomPainter {
  final List<Punto> puntos;
  final List<(int, int)> aristas;
  final double anchoImagen;
  final double altoImagen;
  final double pulso;
  final Color color;

  _PintorMalla({
    required this.puntos,
    required this.aristas,
    required this.anchoImagen,
    required this.altoImagen,
    required this.pulso,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (puntos.length < 3) return;
    final ajuste = AjusteCubrir(
      anchoImagen: anchoImagen,
      altoImagen: altoImagen,
      anchoVista: size.width,
      altoVista: size.height,
    );
    final enVista = [for (final p in puntos) _offset(ajuste.aVista(p))];

    final alambre = Path();
    for (final (a, b) in aristas) {
      if (a >= enVista.length || b >= enVista.length) continue;
      alambre
        ..moveTo(enVista[a].dx, enVista[a].dy)
        ..lineTo(enVista[b].dx, enVista[b].dy);
    }
    canvas.drawPath(
      alambre,
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Cada punto con su brillo: un halo ancho y tenue, uno medio y el
    // centro claro. El halo crece con el latido.
    final r = 1.6 + 0.9 * pulso;
    Paint punto(Color c, double ancho) => Paint()
      ..color = c
      ..strokeWidth = ancho
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawPoints(
        ui.PointMode.points,
        enVista,
        punto(color.withValues(alpha: 0.10 + 0.22 * pulso), r * 5),
      )
      ..drawPoints(
        ui.PointMode.points,
        enVista,
        punto(color.withValues(alpha: 0.45 + 0.25 * pulso), r * 2.4),
      )
      ..drawPoints(
        ui.PointMode.points,
        enVista,
        punto(AppColors.texto.withValues(alpha: 0.9), r),
      );
  }

  static Offset _offset(Punto p) => Offset(p.x, p.y);

  @override
  bool shouldRepaint(covariant _PintorMalla antes) =>
      !identical(antes.puntos, puntos) ||
      antes.pulso != pulso ||
      antes.color != color ||
      !identical(antes.aristas, aristas);
}
