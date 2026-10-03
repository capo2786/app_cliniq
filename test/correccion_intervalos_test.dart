// test/correccion_intervalos_test.dart
//
// La corrección de los intervalos entre latidos (la misma que la del
// servidor): cada regla con casos sintéticos, una serie limpia que no se
// toca, un 620/860 aislado que se corrige, las diferencias solo entre
// intervalos consecutivos, el afinado parabólico de los picos y el RMSSD de
// una serie de RR conocida con los picos a 30 Hz.

import 'dart:math' as math;

import 'package:app_cliniq/features/mediciones/dominio/detalle_medicion.dart';
import 'package:app_cliniq/features/mediciones/dominio/procesamiento_ppg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/senales.dart';

/// Los instantes de unos latidos con estos intervalos (ms).
List<double> _latidos(List<double> rr, {double inicio = 1}) {
  final t = [inicio];
  for (final ms in rr) {
    t.add(t.last + ms / 1000);
  }
  return t;
}

List<int> _ms(IntervalosCorregidos c) => [
  for (final i in c.intervalos) i.ms.round(),
];

/// El RMSSD de verdad de una serie (ms).
double _rmssd(List<double> rr) {
  var suma = 0.0;
  for (var i = 1; i < rr.length; i++) {
    suma += math.pow(rr[i] - rr[i - 1], 2);
  }
  return math.sqrt(suma / (rr.length - 1));
}

/// Una onda de pulso muestreada a [fs] con un latido en cada instante de
/// [latidos]: el pico sistólico y la onda dícrota, como campanas.
List<double> _pulso(List<double> latidos, {double fs = 30}) {
  final n = (latidos.last * fs).ceil() + 15;
  return List<double>.generate(n, (i) {
    final t = i / fs;
    var v = 0.0;
    for (final l in latidos) {
      final d = t - l;
      if (d.abs() > 1) continue;
      v += math.exp(-d * d / (2 * 0.09 * 0.09));
      v += 0.35 * math.exp(-math.pow(d - 0.28, 2) / (2 * 0.07 * 0.07));
    }
    return v;
  });
}

/// 45 intervalos alrededor de 800 ms con una variación que se arrastra de
/// un latido al siguiente (AR(1)), como un corazón en reposo.
List<double> _serieEnReposo(int semilla) {
  final azar = Sintetizador(semilla);
  var x = 0.0;
  return [for (var i = 0; i < 45; i++) 800 + (x = 0.5 * x + 30 * azar.gauss())];
}

void main() {
  group('Las reglas, una por una', () {
    test('una serie limpia no se toca', () {
      final rr = <double>[800, 812, 795, 805, 790, 808, 799, 803, 811, 796];
      final c = corregirIntervalos(_latidos(rr));
      expect(_ms(c), rr.map((v) => v.round()));
      expect(c.corregidos, 0);
      expect(
        c.intervalos.map((i) => i.segundo),
        _latidos(rr).skip(1).map((t) => closeTo(t, 1e-9)),
      );
    });

    test('un 620/860 aislado: el latido va al punto medio y cuenta 2', () {
      final rr = <double>[740, 745, 735, 742, 620, 860, 738, 744, 736, 741];
      final latidos = _latidos(rr);
      final c = corregirIntervalos(latidos);
      expect(_ms(c), [740, 745, 735, 742, 740, 740, 738, 744, 736, 741]);
      expect(c.corregidos, 2);
      // El latido compartido queda justo entre sus vecinos.
      expect(
        c.intervalos[4].segundo,
        closeTo((latidos[4] + latidos[6]) / 2, 1e-9),
      );
      // Y al revés (largo y después corto), igual.
      final alReves = corregirIntervalos(
        _latidos([740, 745, 735, 860, 620, 742, 738, 744]),
      );
      expect(_ms(alReves), [740, 745, 735, 740, 740, 742, 738, 744]);
      expect(alReves.corregidos, 2);
    });

    test('el 620/860 ya no infla la variabilidad', () {
      final rr = <double>[
        for (var i = 0; i < 30; i++) 740 + (i.isEven ? 6.0 : -6.0),
      ];
      rr[10] = 620;
      rr[11] = 860;
      final sinCorregir = MetricasRr.de(rr)!;
      final corregida = MetricasRr.deCorregidos(
        corregirIntervalos(_latidos(rr)),
      )!;
      expect(sinCorregir.rmssd, greaterThan(40));
      expect(corregida.rmssd, lessThan(15));
      expect(corregida.pnn50, 0);
      expect(corregida.corregidos, 2);
    });

    test('un latido perdido se parte en dos iguales y cuenta 1', () {
      final rr = <double>[800, 805, 795, 1600, 802, 798, 804, 800];
      final latidos = _latidos(rr);
      final c = corregirIntervalos(latidos);
      expect(_ms(c), [800, 805, 795, 800, 800, 802, 798, 804, 800]);
      expect(c.corregidos, 1);
      expect(c.intervalos[3].segundo, closeTo(latidos[3] + 0.8, 1e-9));
      expect(c.intervalos[4].segundo, closeTo(latidos[4], 1e-9));
    });

    test('un latido de más: dos cortos se juntan en uno y cuenta 1', () {
      final rr = <double>[800, 805, 795, 450, 352, 802, 798, 804];
      final c = corregirIntervalos(_latidos(rr));
      expect(_ms(c), [800, 805, 795, 802, 802, 798, 804]);
      expect(c.corregidos, 1);
    });

    test('lo que no cuadra con ninguna regla se descarta y también cuenta', () {
      final rr = <double>[800, 805, 795, 1010, 802, 798, 804, 800];
      final c = corregirIntervalos(_latidos(rr));
      expect(_ms(c), [800, 805, 795, 802, 798, 804, 800]);
      expect(c.corregidos, 1);
      // Fuera de 42–210 lpm tampoco cuenta.
      expect(corregirIntervalos(_latidos([200, 2000])).intervalos, isEmpty);
      expect(corregirIntervalos([1.0]).intervalos, isEmpty);
    });

    test('las reglas sueltas', () {
      expect(esPicoMalUbicado(620, 860, 740), isTrue);
      expect(esPicoMalUbicado(860, 620, 740), isTrue);
      expect(esPicoMalUbicado(700, 780, 740), isFalse); // ni corto ni largo
      expect(esPicoMalUbicado(500, 860, 740), isFalse); // no suman 2m
      expect(esLatidoPerdido(1480, 740), isTrue);
      expect(esLatidoPerdido(1200, 740), isFalse);
      expect(esLatidoDeMas(400, 340, 740), isTrue);
      expect(esLatidoDeMas(400, 700, 740), isFalse);
    });
  });

  group('Las diferencias sucesivas', () {
    test('solo entre dos intervalos válidos y consecutivos', () {
      final rr = <double>[800, 820, 795, 1010, 805, 790, 810];
      final c = corregirIntervalos(_latidos(rr));
      // Sin el de 1010: 820−800 y 795−820, y después 790−805 y 810−790
      // (795 → 805 no, porque hubo uno descartado en medio).
      expect(
        diferenciasSucesivas(c.intervalos),
        [20, -25, -15, 20].map((d) => closeTo(d, 1e-6)),
      );
      expect(paresSucesivos(c.intervalos), hasLength(4));
      final m = MetricasRr.deCorregidos(c)!;
      expect(m.intervalos, 6);
      expect(m.rmssd, closeTo(math.sqrt((400 + 625 + 225 + 400) / 4), 1e-6));
    });

    test('se reconocen con los segundos redondeados a una décima', () {
      const a = (segundo: 10.0, ms: 800.0);
      const seguido = (segundo: 10.8, ms: 810.0); // empieza en 9,99
      const conHueco = (segundo: 11.6, ms: 800.0); // empieza en 10,8
      expect(sonConsecutivos(a, seguido), isTrue);
      expect(sonConsecutivos(a, conHueco), isFalse);
    });
  });

  group('El afinado de los picos', () {
    test('la parábola encuentra el vértice entre dos muestras', () {
      // Una parábola con el vértice en 10,3 (muestras).
      final x = [
        for (var i = 0; i < 20; i++) -math.pow(i - 10.3, 2).toDouble(),
      ];
      expect(desplazamientoParabolico(x, 10), closeTo(0.3, 1e-9));
      expect(refinarPicos(x, [10], fs: 30).single, closeTo(10.3 / 30, 1e-9));
      // En el borde no se mueve.
      expect(desplazamientoParabolico(x, 0), 0);
    });

    for (final semilla in [1, 2, 3, 5, 8]) {
      test('picos a 30 Hz de una serie conocida: el RMSSD queda a ±8 ms '
          '(semilla $semilla)', () {
        final rr = _serieEnReposo(semilla);
        final latidos = _latidos(rr, inicio: 0.5);
        final real = _rmssd(rr);
        final senal = _pulso(latidos);

        final picos = detectarPicos(senal);
        expect(picos, hasLength(latidos.length));
        final afinada = MetricasRr.deCorregidos(corregirIntervalos(picos))!;
        expect(afinada.rmssd, closeTo(real, 8));
        expect(afinada.sdnn, closeTo(MetricasRr.de(rr)!.sdnn, 8));

        // Pegados a un cuadro, el error es mayor.
        final pegados = [for (final p in picos) (p * 30).round() / 30];
        final cuantizada = MetricasRr.deCorregidos(
          corregirIntervalos(pegados),
        )!;
        expect(
          (cuantizada.rmssd - real).abs(),
          greaterThan((afinada.rmssd - real).abs()),
        );

        // Y con todo el procesamiento (filtro incluido), también.
        final analisis = analizarSenal([
          for (var i = 0; i < senal.length; i++) i / 30,
        ], senal);
        final completa = MetricasRr.deCorregidos(
          corregirIntervalos(analisis.latidos),
        )!;
        expect(completa.rmssd, closeTo(real, 8));
        expect(completa.corregidos, 0);
      });
    }
  });

  group('Cuándo se enseña la variabilidad', () {
    MetricasRr metricas({required int intervalos, required int corregidos}) =>
        MetricasRr(
          intervalos: intervalos,
          medio: 800,
          minimo: 700,
          maximo: 900,
          sdnn: 40,
          rmssd: 30,
          pnn50: 10,
          sd1: 21,
          sd2: 52,
          corregidos: corregidos,
        );

    bool valida({
      double calidad = 0.85,
      double duracion = 30,
      int intervalos = 36,
      int corregidos = 2,
    }) => DetalleMedicion.variabilidadValida(
      calidad: calidad,
      duracion: duracion,
      metricas: metricas(intervalos: intervalos, corregidos: corregidos),
    );

    test('con buena calidad, 30 s, 20 intervalos y hasta un 10 % '
        'corregidos', () {
      expect(valida(), isTrue);
      expect(valida(corregidos: 3), isTrue); // 3 ≤ 3,6
      expect(valida(corregidos: 4), isFalse); // 4 > 3,6
      expect(valida(calidad: 0.6), isFalse);
      expect(valida(duracion: 25), isFalse);
      expect(valida(intervalos: 19, corregidos: 0), isFalse);
      expect(
        DetalleMedicion.variabilidadValida(
          calidad: 0.9,
          duracion: 30,
          metricas: null,
        ),
        isFalse,
      );
    });
  });
}
