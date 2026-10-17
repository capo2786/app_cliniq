// test/marca_por_clinica_test.dart

import 'package:app_cliniq/core/configuracion/config_publica.dart';
import 'package:app_cliniq/core/tema/contraste.dart';
import 'package:app_cliniq/core/tema/paleta_marca.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/core/tema/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';

/// Los tokens nuevos de la marca de cada clínica: el fondo, la barra
/// lateral y el texto sobre el primario.
void main() {
  tearDown(() => PaletaMarca.actual = PaletaMarca.deSiempre);

  const blanco = Color(0xFFFFFFFF);

  group('El contraste', () {
    test('blanco sobre negro es 21 y un color consigo mismo 1', () {
      expect(
        contrasteEntre(blanco, const Color(0xFF000000)),
        closeTo(21, 0.01),
      );
      expect(contrasteEntre(blanco, blanco), 1);
    });

    test('un fondo claro se oscurece con su tono; uno oscuro se queda', () {
      const referencia = Color(0xFF0F171A);
      const claro = Color(0xFFE0F2FE);
      final oscuro = oscurecerComo(claro, referencia);

      expect(
        HSLColor.fromColor(oscuro).hue,
        closeTo(HSLColor.fromColor(claro).hue, 1),
      );
      expect(contrasteEntre(blanco, oscuro), greaterThanOrEqualTo(7));

      const yaOscuro = Color(0xFF050A0C);
      expect(oscurecerComo(yaOscuro, referencia), yaOscuro);
    });

    test('el texto sobre la acción: blanco sin preferido, el preferido si se '
        'lee, y si no el que más contraste', () {
      const acento = Color(0xFFD16F4B);
      const amarillo = Color(0xFFFFEB3B);

      expect(textoLegibleSobre(acento), blanco);
      expect(
        textoLegibleSobre(acento, preferido: const Color(0xFF111111)),
        const Color(0xFF111111),
      );
      // Amarillo sobre amarillo no se lee: el negro, que contrasta más.
      expect(
        textoLegibleSobre(amarillo, preferido: const Color(0xFFFFF59D)),
        const Color(0xFF111111),
      );
    });
  });

  group('La paleta con los tokens nuevos', () {
    test('sin ellos, la de siempre y los fondos de siempre', () {
      final paleta = PaletaMarca.desde();
      expect(paleta.fondo, const Color(0xFF0F171A));
      expect(paleta.superficie, const Color(0xFF162022));
      expect(paleta.textoSobreAccion, blanco);
    });

    test('el fondo y la barra de la clínica, oscuros, y el blanco se lee '
        'encima', () {
      expect(
        PaletaMarca.aplicar(
          fondo: '#F8FAFC',
          barra: '#1E293B',
          textoSobrePrimario: '#FFFFFF',
        ),
        isTrue,
      );

      for (final color in [
        AppColors.fondo,
        AppColors.superficie,
        AppColors.fondoDegradadoInicio,
        AppColors.fondoDegradadoMedio,
      ]) {
        expect(contrasteEntre(blanco, color), greaterThanOrEqualTo(4.5));
      }

      final tema = temaCliniq();
      expect(tema.scaffoldBackgroundColor, AppColors.fondo);
      expect(tema.appBarTheme.backgroundColor, AppColors.superficie);
      expect(tema.colorScheme.onPrimary, AppColors.textoSobreAccion);

      // Aplicar lo mismo no repinta; volver a nada, sí.
      expect(
        PaletaMarca.aplicar(
          fondo: '#F8FAFC',
          barra: '#1E293B',
          textoSobrePrimario: '#FFFFFF',
        ),
        isFalse,
      );
      expect(PaletaMarca.aplicar(), isTrue);
      expect(AppColors.fondo, const Color(0xFF0F171A));
    });

    test('sin barra, la superficie sigue al fondo', () {
      PaletaMarca.aplicar(fondo: '#E0F2FE');

      final fondo = HSLColor.fromColor(AppColors.fondo);
      final superficie = HSLColor.fromColor(AppColors.superficie);
      expect((superficie.hue - fondo.hue).abs(), lessThan(10));
      expect(superficie.lightness, greaterThan(fondo.lightness));
    });

    test('el texto sobre el primario va en la acción si se lee', () {
      PaletaMarca.aplicar(acento: '#FFC107', textoSobrePrimario: '#1A1A1A');
      expect(AppColors.textoSobreAccion, const Color(0xFF1A1A1A));

      PaletaMarca.aplicar(acento: '#0D47A1', textoSobrePrimario: '#0A0A0A');
      expect(AppColors.textoSobreAccion, blanco);
    });
  });

  group('La configuración pública', () {
    test('lee los tokens nuevos; un color mal escrito es null', () {
      final clinica = ConfigPublica.desdeJson(
        configJson(
          clinica: {
            'colorFondo': '#F8FAFC',
            'colorBarraLateral': '#1E293B',
            'colorTextoSobrePrimario': 'blanco',
          },
        ),
      ).clinica;

      expect(clinica.colorFondo, '#F8FAFC');
      expect(clinica.colorBarraLateral, '#1E293B');
      expect(clinica.colorTextoSobrePrimario, isNull);
    });

    test('sin ellos (un servidor anterior), la configuración vale igual', () {
      final clinica = ConfigPublica.desdeJson(configJson()).clinica;

      expect(clinica.colorFondo, isNull);
      expect(clinica.colorBarraLateral, isNull);
      expect(clinica.colorTextoSobrePrimario, isNull);
    });
  });
}
