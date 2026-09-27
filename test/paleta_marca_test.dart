// test/paleta_marca_test.dart

import 'package:app_cliniq/core/app/version_instalada.dart';
import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/network/api_client.dart';
import 'package:app_cliniq/core/red/estado_de_la_red.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/tema/paleta_marca.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/core/tema/tokens.dart';
import 'package:app_cliniq/features/auth/presentacion/login_page.dart';
import 'package:app_cliniq/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'dobles/adaptador_http.dart';
import 'dobles/clinica.dart';

/// Los colores de la marca salen de la configuración de la clínica
/// (`clinica.colorPrimario`, `clinica.colorAcento`); sin ellos, los de
/// siempre.
void main() {
  tearDown(() => PaletaMarca.actual = PaletaMarca.deSiempre);

  group('La paleta', () {
    test('sin colores configurados, la de siempre', () {
      expect(identical(PaletaMarca.desde(), PaletaMarca.deSiempre), isTrue);
      expect(
        identical(
          PaletaMarca.desde(
            primario: const Color(0xFF5A6E73),
            acento: const Color(0xFFD16F4B),
          ),
          PaletaMarca.deSiempre,
        ),
        isTrue,
      );
      expect(PaletaMarca.deSiempre.acentoClaro, const Color(0xFFE8956F));
    });

    test('con colores propios, los tonos se derivan con el mismo criterio', () {
      const azul = Color(0xFF1E5AA8);
      final paleta = PaletaMarca.desde(primario: azul);

      final base = HSLColor.fromColor(azul);
      final claro = HSLColor.fromColor(paleta.primarioClaro);

      expect(paleta.primario, azul);
      expect(claro.lightness, greaterThan(base.lightness));
      expect((claro.hue - base.hue).abs(), lessThan(2));
      // El acento, sin configurar, sigue siendo el de siempre.
      expect(paleta.acento, PaletaMarca.deSiempre.acento);
      expect(paleta.acentoClaro, PaletaMarca.deSiempre.acentoClaro);
      // Los encabezados bajan del primario hacia el fondo.
      expect(
        HSLColor.fromColor(paleta.encabezado.last).lightness,
        lessThan(HSLColor.fromColor(paleta.encabezado.first).lightness),
      );
    });

    test('aplicar cambia los tokens y el tema, y dice si cambió algo', () {
      expect(PaletaMarca.aplicar(acento: '#1E88E5'), isTrue);
      expect(AppColors.acento, const Color(0xFF1E88E5));
      expect(temaCliniq().colorScheme.primary, const Color(0xFF1E88E5));
      expect(AppGradientes.accion.colors.first, const Color(0xFF1E88E5));

      expect(PaletaMarca.aplicar(acento: '#1E88E5'), isFalse);
      expect(PaletaMarca.aplicar(), isTrue);
      expect(AppColors.acento, PaletaMarca.deSiempre.acento);
    });

    test('un color mal escrito no se usa: queda el de siempre', () {
      PaletaMarca.aplicar(primario: 'azul', acento: '#12');

      expect(AppColors.primario, PaletaMarca.deSiempre.primario);
      expect(AppColors.acento, PaletaMarca.deSiempre.acento);
    });
  });

  testWidgets('la aplicación arma su tema con los colores de la clínica', (
    tester,
  ) async {
    ZonaClinica.aplicar('America/Guayaquil');
    Servicios.cacheParaPruebas = CacheEnMemoria();
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Cliniq',
      packageName: 'ec.cliniq.sage.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    VersionInstalada.olvidar();
    SondeoDeRed.olvidarLaInstancia();

    ApiClient()
      ..dio.httpClientAdapter = AdaptadorHttpFalso({
        'GET /': (_) => (estado: 200, cuerpo: 'ok'),
        ...rutasDeLaClinica(
          config: configJson(
            clinica: {'colorPrimario': '#1E5AA8', 'colorAcento': '#1E88E5'},
          ),
        ),
      })
      ..token = null;

    await tester.pumpWidget(const CliniqApp());
    // Hasta que pasa la espera de los datos de la clínica.
    for (var i = 0; i < 20 && find.byType(LoginPage).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // El tema cambia con una transición: hasta que termine.
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(AppColors.primario, const Color(0xFF1E5AA8));
    expect(AppColors.acento, const Color(0xFF1E88E5));

    final tema = Theme.of(tester.element(find.byType(LoginPage)));
    expect(tema.colorScheme.primary, const Color(0xFF1E88E5));
  });
}
