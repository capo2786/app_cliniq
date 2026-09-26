// tool/generar_iconos_test.dart

/// Genera los PNG del icono y del arranque desde el mismo `CustomPainter`
/// del logotipo que usa la aplicación (`PintorLogoCliniq`).
///
/// Así el icono del teléfono, la pantalla de arranque y el logotipo del
/// acceso son exactamente el mismo dibujo, sin un archivo de diseño aparte
/// que se desincronice. Se ejecuta a mano cuando cambia el logotipo:
///
/// ```bash
/// flutter test tool/generar_iconos_test.dart
/// dart run flutter_launcher_icons
/// dart run flutter_native_splash:create
/// ```
///
/// Vive en `tool/` y no en `test/` para que `flutter test` no lo corra con
/// las pruebas: escribe archivos.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:app_cliniq/core/presentacion/widgets/logo_cliniq.dart';
import 'package:app_cliniq/core/tema/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pinta un PNG cuadrado de `lado` píxeles.
///
/// - `fondo`: color de fondo a sangre, o transparente si es `null`.
/// - `insignia`: si se dibuja la pastilla clara redondeada detrás, como
///   `InsigniaCliniq` en la aplicación.
/// - `proporcion`: qué parte del lado ocupa el logotipo.
Future<void> pintar(
  String ruta, {
  required int lado,
  required double proporcion,
  Color? fondo,
  bool insignia = false,
}) async {
  final grabadora = ui.PictureRecorder();
  final lienzo = Canvas(grabadora);
  final tamano = Size.square(lado.toDouble());

  if (fondo != null) {
    lienzo.drawRect(Offset.zero & tamano, Paint()..color = fondo);
  }

  if (insignia) {
    final caja = Rect.fromCenter(
      center: tamano.center(Offset.zero),
      width: lado * 0.86,
      height: lado * 0.86,
    );
    lienzo.drawRRect(
      RRect.fromRectAndRadius(caja, Radius.circular(lado * 0.25)),
      Paint()..color = AppColors.fondoIcono,
    );
  }

  final ladoLogo = lado * proporcion;
  lienzo.save();
  lienzo.translate((lado - ladoLogo) / 2, (lado - ladoLogo) / 2);
  const PintorLogoCliniq().paint(lienzo, Size.square(ladoLogo));
  lienzo.restore();

  final imagen = await grabadora.endRecording().toImage(lado, lado);
  final bytes = await imagen.toByteData(format: ui.ImageByteFormat.png);

  final archivo = File(ruta)..createSync(recursive: true);
  archivo.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  testWidgets('genera los PNG del icono y del arranque', (tester) async {
    await tester.runAsync(() async {
      const carpeta = 'assets/images';

      // El logotipo solo, sin fondo: para quien lo necesite fuera de la app.
      await pintar('$carpeta/logo.png', lado: 1024, proporcion: 0.92);

      // Icono completo (iOS y Android anterior al 8): fondo claro cálido.
      // iOS no admite transparencia en el icono y redondea las esquinas solo.
      await pintar(
        '$carpeta/icono_app.png',
        lado: 1024,
        proporcion: 0.66,
        fondo: AppColors.fondoIcono,
      );

      // Primer plano del icono adaptable de Android. flutter_launcher_icons
      // ya le pone un margen del 16 % por lado y el sistema recorta con su
      // máscara: con el 80 % del lienzo, el anillo queda dentro de la zona
      // segura de 66 dp.
      await pintar(
        '$carpeta/icono_primer_plano.png',
        lado: 1024,
        proporcion: 0.8,
      );

      // Arranque: la misma pastilla clara del acceso, sobre el fondo oscuro.
      await pintar(
        '$carpeta/splash_logo.png',
        lado: 768,
        proporcion: 0.58,
        insignia: true,
      );

      // Android 12+: 1152 px con el dibujo dentro de un círculo de 768.
      await pintar(
        '$carpeta/splash_android12.png',
        lado: 1152,
        proporcion: 0.46,
      );
    });

    expect(File('assets/images/icono_app.png').existsSync(), isTrue);
  });
}
