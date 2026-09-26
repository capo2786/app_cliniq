import 'package:flutter/material.dart';

import '../../tema/tokens.dart';

/// El logotipo de Cliniq: un anillo gris azulado con una cruz terracota.
///
/// Se dibuja con código y no con una imagen: se ve nítido en cualquier
/// tamaño, no pesa nada y es exactamente el mismo que genera el icono de la
/// aplicación y la pantalla de arranque (ver `tool/generar_iconos_test.dart`).
class LogoCliniq extends StatelessWidget {
  final double tamano;

  const LogoCliniq({super.key, this.tamano = 64});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cliniq',
      image: true,
      child: CustomPaint(
        size: Size.square(tamano),
        painter: const PintorLogoCliniq(),
      ),
    );
  }
}

/// El dibujo del logotipo, suelto para poder pintarlo también en un lienzo
/// fuera de la interfaz (el generador de iconos).
class PintorLogoCliniq extends CustomPainter {
  final Color colorAnillo;
  final Color colorCruz;

  const PintorLogoCliniq({
    this.colorAnillo = AppColors.primario,
    this.colorCruz = AppColors.acento,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final lado = size.shortestSide;
    final centro = size.center(Offset.zero);

    // El anillo: un trazo del 11 % del lado, dentro del cuadro.
    final grosorAnillo = lado * 0.11;
    canvas.drawCircle(
      centro,
      (lado - grosorAnillo) / 2,
      Paint()
        ..color = colorAnillo
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosorAnillo
        ..isAntiAlias = true,
    );

    // La cruz: dos barras redondeadas que se cruzan en el centro.
    final largo = lado * 0.48;
    final grosor = lado * 0.17;
    final radio = Radius.circular(grosor * 0.28);
    final pintura = Paint()
      ..color = colorCruz
      ..isAntiAlias = true;

    final horizontal = Rect.fromCenter(
      center: centro,
      width: largo,
      height: grosor,
    );
    final vertical = Rect.fromCenter(
      center: centro,
      width: grosor,
      height: largo,
    );

    final cruz = Path()
      ..addRRect(RRect.fromRectAndRadius(horizontal, radio))
      ..addRRect(RRect.fromRectAndRadius(vertical, radio));

    canvas.drawPath(cruz, pintura);
  }

  @override
  bool shouldRepaint(covariant PintorLogoCliniq oldDelegate) =>
      oldDelegate.colorAnillo != colorAnillo ||
      oldDelegate.colorCruz != colorCruz;
}

/// El logotipo sobre su pastilla clara, como se ve en el acceso y el
/// arranque: el anillo gris azulado necesita algo de luz detrás para no
/// perderse en el fondo oscuro.
class InsigniaCliniq extends StatelessWidget {
  final double tamano;

  const InsigniaCliniq({super.key, this.tamano = 96});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      padding: EdgeInsets.all(tamano * 0.16),
      decoration: BoxDecoration(
        color: AppColors.fondoIcono.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(tamano * 0.29),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: AppColors.acento.withValues(alpha: 0.28),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: LogoCliniq(tamano: tamano * 0.68),
    );
  }
}
