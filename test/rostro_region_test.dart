// test/rostro_region_test.dart
//
// Del rostro detectado a lo que se mide: la frente y las mejillas desde
// los contornos, el promedio de solo la piel en una imagen sintética, el
// giro y el espejo de cada plataforma y la conversión desde ML Kit.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:app_cliniq/features/mediciones/escaner/extractor_de_cuadros.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/cuadro_de_camara.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/detector_mlkit.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/geometria.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/region_de_interes.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/rostro_detectado.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'dobles/rostro.dart';

void main() {
  group('La frente y las mejillas desde los contornos', () {
    final rostro = rostroSintetico();
    final c = rostro.contornos;
    final region = regionDesdeRostro(rostro);

    test('la frente queda sobre las cejas, dentro del óvalo', () {
      final cejas = Caja.de([
        ...c[ContornoRostro.cejaIzquierdaArriba]!,
        ...c[ContornoRostro.cejaDerechaArriba]!,
      ])!;
      final frente = Caja.de(region.frente)!;
      expect(frente.abajo, lessThan(cejas.abajo));
      expect(frente.alto, greaterThan(0.1 * rostro.caja.alto));
      final muestras = [
        for (final p in region.muestras())
          if (puntoEnPoligono(p, region.frente)) p,
      ];
      expect(muestras.length, greaterThan(100));
      for (final p in muestras) {
        expect(p.y, lessThan(cejas.abajo));
        expect(puntoEnPoligono(p, c[ContornoRostro.ovalo]!), isTrue);
      }
      // Ningún punto de los ojos cae en la frente.
      for (final p in c[ContornoRostro.ojoIzquierdo]!) {
        expect(region.contiene(p), isFalse);
      }
    });

    test('cada mejilla: bajo su ojo, al lado de la nariz, sobre el labio', () {
      final nariz = Caja.de(c[ContornoRostro.baseNariz]!)!;
      final labio = Caja.de(c[ContornoRostro.labioSuperiorArriba]!)!;
      final ojoIzq = Caja.de(c[ContornoRostro.ojoIzquierdo]!)!;
      final ojoDer = Caja.de(c[ContornoRostro.ojoDerecho]!)!;

      final izquierda = muestrasEnPoligono(region.mejillaIzquierda);
      final derecha = muestrasEnPoligono(region.mejillaDerecha);
      expect(izquierda.length, greaterThan(100));
      expect(derecha.length, greaterThan(100));
      for (final p in izquierda) {
        expect(p.x, lessThan(nariz.centro.x));
        expect(p.y, greaterThan(ojoIzq.abajo));
        expect(p.y, lessThan(labio.abajo));
        expect(puntoEnPoligono(p, c[ContornoRostro.ovalo]!), isTrue);
      }
      for (final p in derecha) {
        expect(p.x, greaterThan(nariz.centro.x));
        expect(p.y, greaterThan(ojoDer.abajo));
      }
      // Ni la nariz ni la boca entran.
      expect(region.contiene(c[ContornoRostro.baseNariz]![1]), isFalse);
      expect(region.contiene(c[ContornoRostro.labioInferiorAbajo]![4]), isFalse);
    });

    test('sin contornos: rectángulos dentro de la caja', () {
      final soloCaja = RostroDetectado(
        caja: const Caja(100, 100, 300, 350),
        anchoImagen: 480,
        altoImagen: 640,
        momento: Duration.zero,
      );
      final r = regionDesdeRostro(soloCaja);
      for (final pol in r.poligonos) {
        for (final p in pol) {
          expect(soloCaja.caja.contiene(p), isTrue);
        }
      }
      expect(Caja.de(r.mejillaIzquierda)!.centro.x, lessThan(200));
      expect(Caja.de(r.mejillaDerecha)!.centro.x, greaterThan(200));
    });

    test('la rejilla está acotada: el costo por cuadro no crece con la cara',
        () {
      final grande = regionDesdeRostro(rostroSintetico(ancho: 440));
      final total = grande.muestras(porZona: 300).length;
      expect(total, lessThanOrEqualTo(900));
      expect(total, greaterThan(300));
    });
  });

  group('El promedio de solo la piel', () {
    test('en la imagen sintética: ni el pelo, ni las cejas, ni el fondo', () {
      final rostro = rostroSintetico();
      final imagen = imagenDeRostro(rostro);
      final cuadro = CuadroDeCamara(imagen: imagen, momento: Duration.zero);
      final region = regionDesdeRostro(rostro);
      final candidatos = [
        for (final p in region.muestras()) cuadro.pixelDe(p),
      ];
      final piel = soloPiel(imagen, candidatos);
      // La frente sube hasta el pelo: algunos puntos quedan fuera.
      expect(piel.length, lessThan(candidatos.length));
      expect(piel.length, greaterThan(candidatos.length * 0.6));

      final cuadroPpg = promediarPixeles(
        imagen,
        piel,
        const Duration(milliseconds: 33),
        cobertura: piel.length / candidatos.length,
      );
      expect(cuadroPpg.rojo, closeTo(pielSintetica.r, 0.01));
      expect(cuadroPpg.verde, closeTo(pielSintetica.g, 0.01));
      expect(cuadroPpg.azul, closeTo(pielSintetica.b, 0.01));

      // Sin máscara, el promedio de la caja entera se ensucia de pelo y
      // fondo.
      final todo = [
        for (var y = 0; y < imagen.alto; y += 4)
          for (var x = 0; x < imagen.ancho; x += 4)
            if (rostro.caja.contiene(Punto(x.toDouble(), y.toDouble())))
              (x: x, y: y),
      ];
      final sucio = promediarPixeles(imagen, todo, Duration.zero, cobertura: 1);
      expect((sucio.rojo - pielSintetica.r).abs(), greaterThan(10));
    });

    test('sin píxeles: todo en cero y sin cobertura', () {
      final c = promediarPixeles(
        imagenBgra(4, 4, (_, _) => pielSintetica),
        const [],
        Duration.zero,
        cobertura: 0.5,
      );
      expect(c.rojo, 0);
      expect(c.cobertura, 0);
    });
  });

  group('El giro y el espejo de cada plataforma', () {
    test('iOS ya entrega derecho y espejado; Android, como el sensor', () {
      expect(
        orientacionDelCuadro(ios: true, frontal: true, orientacionSensor: 90),
        (rotacion: 0, espejar: false),
      );
      expect(
        orientacionDelCuadro(ios: false, frontal: true, orientacionSensor: 270),
        (rotacion: 270, espejar: true),
      );
      expect(
        orientacionDelCuadro(
          ios: false,
          frontal: true,
          orientacionSensor: 270,
          giroDispositivo: 90,
        ),
        (rotacion: 0, espejar: true),
      );
      expect(
        orientacionDelCuadro(
          ios: false,
          frontal: false,
          orientacionSensor: 90,
          giroDispositivo: 90,
        ),
        (rotacion: 0, espejar: false),
      );
    });

    test('del punto que ve la persona al píxel del sensor girado y espejado',
        () {
      // Un sensor apaisado de 64 × 48 girado 270° (la frontal de Android):
      // derecha mide 48 × 64.
      final imagen = imagenBgra(64, 48, (_, _) => pielSintetica);
      final cuadro = CuadroDeCamara(
        imagen: imagen,
        momento: Duration.zero,
        rotacion: 270,
        espejar: true,
      );
      expect(cuadro.anchoDerecho, 48);
      expect(cuadro.altoDerecho, 64);
      // Arriba a la izquierda en pantalla es arriba a la derecha de la
      // imagen derecha sin espejar: en el sensor, la esquina (63, 47).
      expect(cuadro.pixelDe(const Punto(0, 0)), (x: 63, y: 47));
      expect(cuadro.pixelDe(const Punto(47.9, 0)), (x: 63, y: 0));
    });
  });

  group('Desde ML Kit', () {
    Face cara(Rect caja, {Map<FaceContourType, FaceContour?>? contornos}) =>
        Face(
          boundingBox: caja,
          landmarks: const {},
          contours: contornos ?? const {},
          headEulerAngleY: 10,
          headEulerAngleZ: -4,
        );

    test('el más grande, espejado, con sus contornos y ángulos', () {
      final cuadro = CuadroDeCamara(
        imagen: imagenBgra(64, 48, (_, _) => pielSintetica),
        momento: const Duration(seconds: 2),
        rotacion: 270,
        espejar: true,
      );
      final rostro = rostroDesdeMlKit([
        cara(const Rect.fromLTWH(1, 1, 5, 5)),
        cara(
          const Rect.fromLTRB(8, 10, 28, 40),
          contornos: {
            FaceContourType.leftEye: FaceContour(
              type: FaceContourType.leftEye,
              points: const [math.Point(10, 20), math.Point(14, 21)],
            ),
            FaceContourType.noseBottom: null,
          },
        ),
      ], cuadro)!;

      expect(rostro.anchoImagen, 48);
      expect(rostro.altoImagen, 64);
      expect(rostro.caja, const Caja(20, 10, 40, 40));
      expect(rostro.contornos[ContornoRostro.ojoIzquierdo], const [
        Punto(38, 20),
        Punto(34, 21),
      ]);
      expect(rostro.contornos.containsKey(ContornoRostro.baseNariz), isFalse);
      expect(rostro.anguloY, -10);
      expect(rostro.anguloZ, 4);
      expect(rostro.momento, const Duration(seconds: 2));
    });

    test('sin caras: null', () {
      final cuadro = CuadroDeCamara(
        imagen: imagenBgra(8, 8, (_, _) => pielSintetica),
        momento: Duration.zero,
      );
      expect(rostroDesdeMlKit(const [], cuadro), isNull);
    });

    test('la entrada para ML Kit: NV21 o BGRA de un plano, con su giro', () {
      final bgra = imagenBgra(64, 48, (_, _) => pielSintetica);
      final entrada = entradaParaMlKit(
        CuadroDeCamara(imagen: bgra, momento: Duration.zero, rotacion: 90),
      );
      expect(entrada.metadata!.format, InputImageFormat.bgra8888);
      expect(entrada.metadata!.rotation, InputImageRotation.rotation90deg);
      expect(entrada.metadata!.bytesPerRow, 64 * 4);
      expect(entrada.metadata!.size.width, 64);

      final nv21 = ImagenCruda(
        formato: FormatoImagen.nv21,
        ancho: 8,
        alto: 4,
        planos: [PlanoCrudo(Uint8List(48), bytesPorFila: 8)],
      );
      expect(
        entradaParaMlKit(
          CuadroDeCamara(imagen: nv21, momento: Duration.zero, rotacion: 270),
        ).metadata!.format,
        InputImageFormat.nv21,
      );

      final yuv = ImagenCruda(
        formato: FormatoImagen.yuv420,
        ancho: 8,
        alto: 4,
        planos: [PlanoCrudo(Uint8List(48), bytesPorFila: 8)],
      );
      expect(
        () => entradaParaMlKit(
          CuadroDeCamara(imagen: yuv, momento: Duration.zero),
        ),
        throwsUnsupportedError,
      );
    });

    test('las opciones: contornos, modo rápido, sin clasificación', () {
      final o = DetectorMlKit.opciones();
      expect(o.enableContours, isTrue);
      expect(o.performanceMode, FaceDetectorMode.fast);
      expect(o.enableClassification, isFalse);
      expect(o.minFaceSize, inInclusiveRange(0.1, 0.3));
    });
  });
}
