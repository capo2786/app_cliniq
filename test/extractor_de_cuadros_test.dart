// test/extractor_de_cuadros_test.dart
//
// La extracción de cada cuadro de la cámara (YUV420, NV21 y BGRA; la yema
// del dedo y la piel del rostro dentro del óvalo) y la serie de números
// que sale de ella, con su JSON.

import 'dart:typed_data';

import 'package:app_cliniq/features/mediciones/escaner/extractor_de_cuadros.dart';
import 'package:app_cliniq/features/mediciones/escaner/serie_senal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/mediciones.dart';
import 'dobles/senales.dart';

/// Una imagen de un solo color en el formato pedido.

ImagenCruda _imagen(
  FormatoImagen formato, {
  required int r,
  required int g,
  required int b,
  int ancho = 64,
  int alto = 48,
}) {
  // Del RGB al YUV (BT.601, rango completo).
  final y = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
  final u = (128 - 0.168736 * r - 0.331264 * g + 0.5 * b).round().clamp(0, 255);
  final v = (128 + 0.5 * r - 0.418688 * g - 0.081312 * b).round().clamp(0, 255);

  switch (formato) {
    case FormatoImagen.bgra8888:
      final bytes = Uint8List(ancho * alto * 4);
      for (var i = 0; i < ancho * alto; i++) {
        bytes[i * 4] = b;
        bytes[i * 4 + 1] = g;
        bytes[i * 4 + 2] = r;
        bytes[i * 4 + 3] = 255;
      }
      return ImagenCruda(
        formato: formato,
        ancho: ancho,
        alto: alto,
        planos: [PlanoCrudo(bytes, bytesPorFila: ancho * 4, bytesPorPixel: 4)],
      );
    case FormatoImagen.nv21:
      final bytes = Uint8List(ancho * alto * 3 ~/ 2);
      bytes.fillRange(0, ancho * alto, y);
      for (var i = ancho * alto; i < bytes.length; i += 2) {
        bytes[i] = v;
        bytes[i + 1] = u;
      }
      return ImagenCruda(
        formato: formato,
        ancho: ancho,
        alto: alto,
        planos: [PlanoCrudo(bytes, bytesPorFila: ancho)],
      );
    case FormatoImagen.yuv420:
      return ImagenCruda(
        formato: formato,
        ancho: ancho,
        alto: alto,
        planos: [
          PlanoCrudo(
            Uint8List(ancho * alto)..fillRange(0, ancho * alto, y),
            bytesPorFila: ancho,
          ),
          // U y V intercalados (pixelStride 2), como en muchos Android.
          PlanoCrudo(
            Uint8List(ancho * alto ~/ 2)..fillRange(0, ancho * alto ~/ 2, u),
            bytesPorFila: ancho,
            bytesPorPixel: 2,
          ),
          PlanoCrudo(
            Uint8List(ancho * alto ~/ 2)..fillRange(0, ancho * alto ~/ 2, v),
            bytesPorFila: ancho,
            bytesPorPixel: 2,
          ),
        ],
      );
  }
}

const _piel = (r: 205, g: 150, b: 125);

void main() {
  group('Extraer cada cuadro', () {
    for (final formato in FormatoImagen.values) {
      test('dedo en ${formato.name}: la yema roja cubre la cámara', () {
        final cuadro = reducirDedo(
          _imagen(formato, r: 190, g: 30, b: 25),
          const Duration(milliseconds: 33),
        );
        expect(cuadro.momento, const Duration(milliseconds: 33));
        expect(cuadro.rojo, closeTo(190, 4));
        expect(cuadro.cobertura, 1);
        expect(cuadro.saturacion, 0);
      });
    }

    test('sin el dedo (la mesa, gris): cobertura cero', () {
      final cuadro = reducirDedo(
        _imagen(FormatoImagen.bgra8888, r: 120, g: 118, b: 115),
        Duration.zero,
      );
      expect(cuadro.cobertura, 0);
    });

    test('apretando demasiado, el rojo se quema', () {
      final cuadro = reducirDedo(
        _imagen(FormatoImagen.bgra8888, r: 255, g: 60, b: 40),
        Duration.zero,
      );
      expect(cuadro.saturacion, 1);
    });

    test('la piel por su color (YCbCr); el fondo azul no', () {
      expect(esPiel((r: 205.0, g: 150.0, b: 125.0)), isTrue);
      expect(esPiel((r: 60.0, g: 90.0, b: 200.0)), isFalse);
      expect(esPiel((r: 10.0, g: 8.0, b: 8.0)), isFalse);
    });

    test('rostro: promedia solo la piel y dice cuánta hay', () {
      final extractor = ExtractorDeRostro();
      final conCara = extractor.reducir(
        _imagen(
          FormatoImagen.nv21,
          r: _piel.r,
          g: _piel.g,
          b: _piel.b,
          ancho: 120,
          alto: 160,
        ),
        Duration.zero,
        rotacion: 270,
      );
      expect(conCara.cobertura, 1);
      expect(conCara.rojo, closeTo(_piel.r, 6));
      expect(conCara.verde, closeTo(_piel.g, 6));

      final sinCara = ExtractorDeRostro().reducir(
        _imagen(FormatoImagen.bgra8888, r: 60, g: 90, b: 200),
        Duration.zero,
      );
      expect(sinCara.cobertura, 0);
    });

    test('del óvalo de la pantalla al píxel del sensor girado', () {
      // Imagen del sensor de 640×480; derecha, 480×640.
      expect(aPixelDelSensor(0, 0, 0, 640, 480), (x: 0, y: 0));
      expect(aPixelDelSensor(0, 0, 90, 640, 480), (x: 0, y: 479));
      expect(aPixelDelSensor(0, 0, 270, 640, 480), (x: 639, y: 0));
      expect(aPixelDelSensor(0, 0, 180, 640, 480), (x: 639, y: 479));
      // El centro sigue en el centro.
      final centro = aPixelDelSensor(0.5, 0.5, 90, 640, 480);
      expect(centro.x, closeTo(320, 1));
      expect(centro.y, closeTo(240, 1));
    });
  });

  group('La serie: solo números', () {
    test('el JSON para analizar tiene la forma {metodo, t (ms), canales}', () {
      final serie = SerieSenal.de(
        ModoEscaner.dedo,
        cuadrosDeDedo(Sintetizador(1).dedo(lpm: 72, segundos: 2)),
      );
      final json = serie.aJsonParaAnalisis();

      expect(json.keys, ['metodo', 't', 'canales']);
      expect(json['metodo'], 'CAMARA_DEDO');
      expect((json['t'] as List).first, isA<int>());
      expect((json['canales'] as Map).keys, ['y', 'r']);
      expect((json['canales']['r'] as List).length, (json['t'] as List).length);

      final rostro = SerieSenal.de(
        ModoEscaner.rostro,
        cuadrosDeRostro(Sintetizador(1).rostro(lpm: 72, segundos: 2)),
      ).aJsonParaAnalisis();
      expect(rostro['metodo'], 'CAMARA_ROSTRO');
      expect((rostro['canales'] as Map).keys, ['r', 'g', 'b']);
    });

    test('se escribe y se vuelve a leer igual', () {
      final serie = SerieSenal.de(
        ModoEscaner.rostro,
        cuadrosDeRostro(Sintetizador(2).rostro(lpm: 60, segundos: 1)),
      );
      expect(SerieSenal.desdeJson(serie.aJson()), serie);
      expect(SerieSenal.desdeJson({'modo': 'pies'}), isNull);
    });
  });
}
