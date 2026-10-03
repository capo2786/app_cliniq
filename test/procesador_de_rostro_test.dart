// test/procesador_de_rostro_test.dart
//
// Cada cuadro del modo rostro con un detector falso: el ritmo de la
// detección (como mucho ~9 por segundo y sin bloquear), el promedio en
// cada cuadro con la última región conocida, el costo acotado y el
// respaldo por color de piel si ML Kit falla.

import 'dart:async';

import 'package:app_cliniq/features/mediciones/escaner/rostro/cuadro_de_camara.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/detector_de_rostro.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/procesador_de_rostro.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/rostro_detectado.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/rostro.dart';

/// Un detector que no responde hasta que la prueba quiere.
class _DetectorLento implements DetectorDeRostro {
  final List<Completer<RostroDetectado?>> pendientes = [];

  @override
  Future<RostroDetectado?> detectar(CuadroDeCamara cuadro) {
    final c = Completer<RostroDetectado?>();
    pendientes.add(c);
    return c.future;
  }

  @override
  Future<void> cerrar() async {}
}

void main() {
  final rostro = rostroSintetico();
  final imagen = imagenDeRostro(rostro);

  CuadroDeCamara cuadro(int i) => CuadroDeCamara(
    imagen: imagen,
    momento: Duration(milliseconds: 33 * i),
  );

  test('detecta como mucho unas 10 veces por segundo', () {
    final detector = DetectorFalso(respuesta: (_) => rostro);
    final procesador = ProcesadorDeRostro(crearDetector: () => detector);
    for (var i = 0; i < 60; i++) {
      procesador.procesar(cuadro(i)); // 2 s a 30 cuadros por segundo
    }
    expect(detector.llamadas.length, inInclusiveRange(18, 20));
    for (var k = 1; k < detector.llamadas.length; k++) {
      expect(
        detector.llamadas[k] - detector.llamadas[k - 1],
        greaterThanOrEqualTo(const Duration(milliseconds: 95)),
      );
    }
  });

  test(
    'nunca bloquea: con una detección en curso, los cuadros siguen',
    () async {
      final detector = _DetectorLento();
      final procesador = ProcesadorDeRostro(crearDetector: () => detector);
      for (var i = 0; i < 30; i++) {
        final c = procesador.procesar(cuadro(i));
        expect(c.rostro, isNull); // todavía no hay respuesta
      }
      expect(detector.pendientes, hasLength(1));

      detector.pendientes.single.complete(rostro);
      await Future<void>.delayed(Duration.zero);
      final conRostro = procesador.procesar(cuadro(30));
      expect(conRostro.rostro, same(rostro));
      expect(detector.pendientes, hasLength(2));
    },
  );

  test('el promedio sigue en cada cuadro con la última región conocida', () {
    var hayRostro = true;
    final detector = DetectorFalso(
      respuesta: (c) => hayRostro ? rostroSintetico(momento: c.momento) : null,
    );
    final procesador = ProcesadorDeRostro(crearDetector: () => detector);

    final primero = procesador.procesar(cuadro(0));
    expect(primero.rostro, isNotNull);
    expect(primero.rojo, closeTo(pielSintetica.r, 0.01));
    expect(primero.cobertura, greaterThan(0.6));
    expect(primero.porColorDePiel, isFalse);
    expect(procesador.pixelesPorCuadro, inInclusiveRange(200, 900));

    // Se va el rostro: el cuadro lo dice, pero el color se sigue midiendo
    // donde estaba.
    hayRostro = false;
    for (var i = 1; i < 10; i++) {
      final c = procesador.procesar(cuadro(i));
      expect(c.rojo, closeTo(pielSintetica.r, 0.01));
      if (i >= 4) expect(c.rostro, isNull);
    }
  });

  test('una detección vieja ya no cuenta como rostro', () async {
    final detector = _DetectorLento();
    final procesador = ProcesadorDeRostro(crearDetector: () => detector);
    procesador.procesar(cuadro(0));
    detector.pendientes.single.complete(rostro); // del momento 0
    await Future<void>.delayed(Duration.zero);
    expect(procesador.procesar(cuadro(10)).rostro, isNotNull);
    // La siguiente detección no responde y pasa más de un segundo.
    expect(procesador.procesar(cuadro(50)).rostro, isNull);
  });

  test(
    'dos fallos seguidos de ML Kit: sigue por color de piel, sin cortar',
    () async {
      final detector = DetectorFalso(fallar: (_) => true);
      final procesador = ProcesadorDeRostro(crearDetector: () => detector);
      var i = 0;
      while (!procesador.porColorDePiel && i < 30) {
        procesador.procesar(cuadro(i++));
        await Future<void>.delayed(Duration.zero);
      }
      expect(procesador.porColorDePiel, isTrue);
      expect(detector.llamadas, hasLength(2));
      expect(detector.cierres, 1);

      final c = procesador.procesar(cuadro(i));
      expect(c.porColorDePiel, isTrue);
      expect(c.rostro, isNull);
      // El óvalo del respaldo cae en la cara de la imagen sintética.
      expect(c.cobertura, greaterThan(0.3));
      expect(c.rojo, closeTo(pielSintetica.r, 1));
    },
  );

  test(
    'un fallo suelto no basta: si la siguiente responde, sigue ML Kit',
    () async {
      var llamadas = 0;
      final detector = DetectorFalso(
        fallar: (_) => ++llamadas == 1,
        respuesta: (_) => rostro,
      );
      final procesador = ProcesadorDeRostro(crearDetector: () => detector);
      for (var i = 0; i < 20; i++) {
        procesador.procesar(cuadro(i));
        await Future<void>.delayed(Duration.zero);
      }
      expect(procesador.porColorDePiel, isFalse);
    },
  );

  test(
    'si el detector no se puede crear, por color de piel desde el inicio',
    () {
      final procesador = ProcesadorDeRostro(
        crearDetector: () => throw UnsupportedError('sin ML Kit'),
      );
      expect(procesador.porColorDePiel, isTrue);
      expect(procesador.procesar(cuadro(0)).porColorDePiel, isTrue);
      expect(ProcesadorDeRostro().porColorDePiel, isTrue);
    },
  );
}
