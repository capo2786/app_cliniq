// test/rostro_geometria_test.dart
//
// La geometría pura del rostro: punto en polígono, el ajuste que cubre la
// pantalla, la triangulación de Delaunay (Bowyer–Watson) y el suavizado
// de los puntos entre detecciones.

import 'dart:math' as math;

import 'package:app_cliniq/features/mediciones/escaner/rostro/delaunay.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/geometria.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/suavizado.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/rostro.dart';

/// El área (positiva) del casco convexo de unos puntos (Andrew).
double _areaDelCasco(List<Punto> puntos) {
  final p = puntos.toSet().toList()
    ..sort((a, b) => a.x != b.x ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
  double cruz(Punto o, Punto a, Punto b) =>
      (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);
  final abajo = <Punto>[];
  for (final q in p) {
    while (abajo.length >= 2 &&
        cruz(abajo[abajo.length - 2], abajo.last, q) <= 0) {
      abajo.removeLast();
    }
    abajo.add(q);
  }
  final arriba = <Punto>[];
  for (final q in p.reversed) {
    while (arriba.length >= 2 &&
        cruz(arriba[arriba.length - 2], arriba.last, q) <= 0) {
      arriba.removeLast();
    }
    arriba.add(q);
  }
  final casco = [...abajo..removeLast(), ...arriba..removeLast()];
  return areaConSigno(casco).abs();
}

double _area(List<Punto> v, Triangulo t) =>
    areaConSigno([v[t.$1], v[t.$2], v[t.$3]]);

/// Comprueba que los triángulos son válidos (área positiva), que no se
/// solapan (sus áreas suman la del casco convexo) y que ninguno tiene un
/// punto dentro de su círculo (Delaunay).
void _esUnaTriangulacionDeDelaunay(List<Punto> puntos, List<Triangulo> ts) {
  expect(ts, isNotEmpty);
  var suma = 0.0;
  for (final t in ts) {
    final area = _area(puntos, t);
    expect(area, greaterThan(0), reason: 'el triángulo $t no tiene área');
    suma += area;
  }
  expect(suma, closeTo(_areaDelCasco(puntos), 1e-6 * suma + 1e-9));

  for (final (a, b, c) in ts) {
    final pa = puntos[a], pb = puntos[b], pc = puntos[c];
    // El circuncentro y su radio.
    final d =
        2 *
        (pa.x * (pb.y - pc.y) + pb.x * (pc.y - pa.y) + pc.x * (pa.y - pb.y));
    final a2 = pa.x * pa.x + pa.y * pa.y;
    final b2 = pb.x * pb.x + pb.y * pb.y;
    final c2 = pc.x * pc.x + pc.y * pc.y;
    final centro = Punto(
      (a2 * (pb.y - pc.y) + b2 * (pc.y - pa.y) + c2 * (pa.y - pb.y)) / d,
      (a2 * (pc.x - pb.x) + b2 * (pa.x - pc.x) + c2 * (pb.x - pa.x)) / d,
    );
    final radio = centro.distanciaA(pa);
    for (final q in puntos) {
      expect(
        centro.distanciaA(q),
        greaterThanOrEqualTo(radio * (1 - 1e-9)),
        reason: 'el punto $q cae dentro del círculo de ($a, $b, $c)',
      );
    }
  }
}

void main() {
  group('Geometría', () {
    const cuadrado = [Punto(0, 0), Punto(10, 0), Punto(10, 10), Punto(0, 10)];

    test('punto en polígono: dentro, fuera y en una forma cóncava', () {
      expect(puntoEnPoligono(const Punto(5, 5), cuadrado), isTrue);
      expect(puntoEnPoligono(const Punto(15, 5), cuadrado), isFalse);
      expect(puntoEnPoligono(const Punto(-1, -1), cuadrado), isFalse);

      // Una «U»: el hueco del medio está fuera.
      const u = [
        Punto(0, 0),
        Punto(3, 0),
        Punto(3, 7),
        Punto(7, 7),
        Punto(7, 0),
        Punto(10, 0),
        Punto(10, 10),
        Punto(0, 10),
      ];
      expect(puntoEnPoligono(const Punto(5, 3), u), isFalse);
      expect(puntoEnPoligono(const Punto(1, 3), u), isTrue);
      expect(puntoEnPoligono(const Punto(5, 9), u), isTrue);
      expect(puntoEnPoligono(const Punto(1, 1), const []), isFalse);
    });

    test('la caja, el área y el centroide', () {
      final caja = Caja.de(cuadrado)!;
      expect(caja.ancho, 10);
      expect(caja.centro, const Punto(5, 5));
      expect(Caja.de(const []), isNull);
      expect(areaConSigno(cuadrado), 100);
      expect(centroideDe(cuadrado), const Punto(5, 5));
      expect(caja.normalizada(20, 40), const Caja(0, 0, 0.5, 0.25));
    });

    test('cubrir la pantalla: escala y recorte centrados', () {
      // Una imagen 3:4 en una pantalla alargada: se recortan los lados.
      final ajuste = AjusteCubrir(
        anchoImagen: 480,
        altoImagen: 640,
        anchoVista: 390,
        altoVista: 844,
      );
      expect(ajuste.escala, closeTo(844 / 640, 1e-9));
      expect(ajuste.dy, closeTo(0, 1e-9));
      expect(ajuste.dx, lessThan(0));
      final centro = ajuste.aVista(const Punto(240, 320));
      expect(centro.x, closeTo(195, 1e-9));
      expect(centro.y, closeTo(422, 1e-9));
      final vuelta = ajuste.aImagen(ajuste.aVista(const Punto(10, 20)));
      expect(vuelta.x, closeTo(10, 1e-9));
      expect(vuelta.y, closeTo(20, 1e-9));
    });
  });

  group('Delaunay (Bowyer–Watson)', () {
    test('un triángulo y un cuadrado', () {
      final tres = [const Punto(0, 0), const Punto(4, 0), const Punto(0, 3)];
      expect(triangular(tres), hasLength(1));
      _esUnaTriangulacionDeDelaunay(tres, triangular(tres));

      const cuatro = [Punto(0, 0), Punto(10, 0), Punto(10, 6), Punto(0, 6)];
      final ts = triangular(cuatro);
      expect(ts, hasLength(2));
      _esUnaTriangulacionDeDelaunay(cuatro, ts);
      expect(aristasDe(ts), hasLength(5));
    });

    test('una rejilla con puntos alineados y en un mismo círculo', () {
      final rejilla = [
        for (var y = 0; y < 5; y++)
          for (var x = 0; x < 5; x++) Punto(x * 10.0, y * 10.0),
      ];
      final ts = triangular(rejilla);
      expect(ts, hasLength(32)); // 2 por cada uno de los 16 cuadrados
      _esUnaTriangulacionDeDelaunay(rejilla, ts);
    });

    test('sin triángulos: menos de tres puntos, repetidos o en una recta', () {
      expect(triangular(const [Punto(0, 0), Punto(1, 1)]), isEmpty);
      expect(
        triangular(const [Punto(0, 0), Punto(0, 0), Punto(0, 0)]),
        isEmpty,
      );
      expect(
        triangular(const [Punto(0, 0), Punto(1, 1), Punto(2, 2), Punto(3, 3)]),
        isEmpty,
      );
    });

    test('los repetidos se usan una vez', () {
      const puntos = [Punto(0, 0), Punto(4, 0), Punto(4, 0), Punto(0, 3)];
      final ts = triangular(puntos);
      expect(ts, hasLength(1));
      expect(
        ts.single.$1 == 2 || ts.single.$2 == 2 || ts.single.$3 == 2,
        isFalse,
      );
    });

    test('~130 puntos al azar: válida, sin solapes y de Delaunay', () {
      for (final semilla in [1, 2, 3, 7, 11, 42]) {
        final azar = math.Random(semilla);
        final puntos = [
          for (var i = 0; i < 130; i++)
            Punto(
              (azar.nextDouble() * 480).roundToDouble(),
              (azar.nextDouble() * 640).roundToDouble(),
            ),
        ];
        _esUnaTriangulacionDeDelaunay(puntos, triangular(puntos));
      }
    });

    test('los contornos de un rostro (133 puntos, con alineados)', () {
      final puntos = rostroSintetico().puntos;
      expect(puntos, hasLength(133));
      final ts = triangular(puntos);
      _esUnaTriangulacionDeDelaunay(puntos.toSet().toList(), [
        // Reindexa a la lista sin repetidos para la comprobación.
        for (final (a, b, c) in ts)
          (
            puntos.toSet().toList().indexOf(puntos[a]),
            puntos.toSet().toList().indexOf(puntos[b]),
            puntos.toSet().toList().indexOf(puntos[c]),
          ),
      ]);
    });
  });

  group('Suavizado entre detecciones', () {
    test('se acerca al objetivo sin pasarse y llega', () {
      final s = SuavizadorDePuntos(tau: const Duration(milliseconds: 100));
      s.fijarObjetivo(const [Punto(0, 0)]);
      expect(s.puntos, const [Punto(0, 0)]);

      s.fijarObjetivo(const [Punto(100, 0)]);
      s.avanzar(const Duration(milliseconds: 100));
      // 1 − e⁻¹ ≈ 63 % del camino.
      expect(s.puntos.single.x, closeTo(100 * (1 - math.exp(-1)), 1e-6));
      for (var i = 0; i < 60; i++) {
        s.avanzar(const Duration(milliseconds: 16));
        expect(s.puntos.single.x, lessThanOrEqualTo(100));
      }
      expect(s.puntos.single.x, closeTo(100, 0.1));
    });

    test('a 60 cuadros por segundo, entre detecciones a 9 por segundo, el '
        'movimiento es continuo', () {
      final s = SuavizadorDePuntos();
      var anterior = 0.0;
      var mayorSalto = 0.0;
      for (var cuadro = 0; cuadro < 120; cuadro++) {
        if (cuadro % 7 == 0) s.fijarObjetivo([Punto(cuadro * 2.0, 0)]);
        s.avanzar(const Duration(microseconds: 16667));
        final x = s.puntos.single.x;
        mayorSalto = math.max(mayorSalto, (x - anterior).abs());
        anterior = x;
      }
      // Sin suavizar, cada detección saltaría 14 px de golpe.
      expect(mayorSalto, lessThan(5));
    });

    test(
      'si cambia la cantidad de puntos, salta directo; limpiar lo olvida',
      () {
        final s = SuavizadorDePuntos()
          ..fijarObjetivo(const [Punto(0, 0)])
          ..fijarObjetivo(const [Punto(5, 5), Punto(6, 6)]);
        expect(s.puntos, const [Punto(5, 5), Punto(6, 6)]);
        s.limpiar();
        expect(s.vacio, isTrue);
        s.avanzar(const Duration(milliseconds: 16));
        expect(s.vacio, isTrue);
      },
    );
  });
}
