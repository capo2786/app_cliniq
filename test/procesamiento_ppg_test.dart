// test/procesamiento_ppg_test.dart
//
// El procesamiento de la PPG del escáner experimental, con señales
// sintéticas (test/dobles/senales.dart): el remuestreo, la tendencia, el
// filtro, el espectro, el conteo de picos, la calidad, la FC a 60, 72 y 110
// lpm con ruido, deriva y artefactos, la señal plana, la FR y POS.

import 'dart:math' as math;

import 'package:app_cliniq/features/mediciones/dominio/procesamiento_ppg.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/senales.dart';

const _frecuencias = [60.0, 72.0, 110.0];
const _semillas = 20;

List<double> _seno(double hz, {double segundos = 30, double amplitud = 1}) => [
  for (var i = 0; i < segundos * frecuenciaAnalisis; i++)
    amplitud * math.sin(2 * math.pi * hz * i / frecuenciaAnalisis),
];

double _desviacion(List<double> x) {
  final m = x.reduce((a, b) => a + b) / x.length;
  return math.sqrt(
    x.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) / x.length,
  );
}

/// El peor error (lpm) y la peor calidad de [_semillas] señales.
({double errorMaximo, double calidadMinima, int conFr}) _barrido(
  double lpm,
  Serie Function(Sintetizador s) generar,
) {
  var error = 0.0;
  var calidad = 1.0;
  var conFr = 0;
  for (var semilla = 1; semilla <= _semillas; semilla++) {
    final serie = generar(Sintetizador(semilla * 31 + lpm.toInt()));
    final r = analizarSenal(serie.tiempos, serie.valores);
    error = math.max(
      error,
      r.fc == null ? double.infinity : (r.fc! - lpm).abs(),
    );
    calidad = math.min(calidad, r.calidad.valor);
    if (r.fr != null) conFr++;
  }
  return (errorMaximo: error, calidadMinima: calidad, conFr: conFr);
}

void main() {
  group('remuestrear', () {
    test('lleva tiempos irregulares a una rejilla de 30 Hz', () {
      final t = [0.0, 0.031, 0.069, 0.1, 0.13, 0.171, 0.2];
      final v = [for (final x in t) 3 * x + 1];

      final r = remuestrear(t, v);

      expect(r.length, 7); // 0 a 0,2 s cada 1/30 s
      for (var i = 0; i < r.length; i++) {
        expect(r[i], closeTo(3 * (i / 30) + 1, 1e-9));
      }
    });

    test('descarta tiempos repetidos o que van hacia atrás', () {
      final r = remuestrear([0, 0.1, 0.1, 0.05, 0.2], [0, 1, 99, 99, 2]);

      expect(r.first, 0);
      expect(r.last, closeTo(2, 1e-9));
      expect(r.every((v) => v <= 2), isTrue);
    });

    test('cuenta los cuadros por segundo que llegaron', () {
      final t = Sintetizador(1).tiempos(fps: 24, perdidos: 0);
      expect(cuadrosPorSegundo(t), closeTo(24, 0.3));
    });
  });

  group('quitar la tendencia (smoothness priors)', () {
    test('se lleva una deriva lenta y conserva el pulso', () {
      final pulso = _seno(1.2);
      final conDeriva = [
        for (var i = 0; i < pulso.length; i++)
          pulso[i] + 40 + 0.5 * i / 30 + 0.02 * math.pow(i / 30, 2),
      ];

      final limpia = quitarTendencia(conDeriva, corteHz: 0.3);
      final centro = limpia.sublist(60, limpia.length - 60);
      final original = pulso.sublist(60, pulso.length - 60);

      expect(_desviacion(centro), closeTo(_desviacion(original), 0.05));
      for (var i = 0; i < centro.length; i++) {
        expect(centro[i], closeTo(original[i], 0.1));
      }
    });
  });

  group('filtro pasa banda Butterworth', () {
    final filtro = pasaBanda(fcMinimaHz, fcMaximaHz);

    test('pasa la banda del pulso y corta lo de fuera', () {
      expect(gananciaDe(filtro, 1.5, 30), closeTo(1, 0.02));
      expect(gananciaDe(filtro, fcMinimaHz, 30), closeTo(math.sqrt1_2, 0.02));
      expect(gananciaDe(filtro, fcMaximaHz, 30), closeTo(math.sqrt1_2, 0.03));
      expect(gananciaDe(filtro, 0.2, 30), lessThan(0.01));
      // Una sola pasada; ida y vuelta, la ganancia se eleva al cuadrado.
      expect(gananciaDe(filtro, 8, 30), lessThan(0.02));
    });

    test('ida y vuelta: no corre los picos (fase cero)', () {
      final entrada = _seno(1.2, segundos: 10);
      final salida = filtrarIdaYVuelta(entrada, filtro);

      final picosEntrada = detectarPicos(entrada);
      final picosSalida = detectarPicos(salida);
      expect(picosSalida.length, picosEntrada.length);
      for (var k = 1; k < picosEntrada.length - 1; k++) {
        expect(picosSalida[k], closeTo(picosEntrada[k], 1 / 30));
      }
    });

    test('quita una oscilación de 0,15 Hz', () {
      final salida = filtrarIdaYVuelta(_seno(0.15, amplitud: 10), filtro);
      expect(_desviacion(salida.sublist(90, 810)), lessThan(0.01));
    });

    test('arranca en régimen: un nivel de 180 no deja un escalón', () {
      final salida = filtrarIdaYVuelta([
        for (final v in _seno(1.2, segundos: 10)) 180 + v,
      ], filtro);
      expect(salida.take(15).every((v) => v.abs() < 1.2), isTrue);
      expect(
        salida.skip(salida.length - 15).every((v) => v.abs() < 1.2),
        isTrue,
      );
    });
  });

  group('espectro (FFT con fftea, Welch)', () {
    test('el pico de una sinusoide cae en su frecuencia', () {
      final pico = picoEnBanda(welch(_seno(1.3)), fcMinimaHz, fcMaximaHz)!;

      expect(pico.frecuencia, closeTo(1.3, 0.01));
      expect(pico.prominencia, greaterThan(0.95));
      expect(pico.enElBorde, isFalse);
    });

    test('la varianza de una banda es la de la señal (Parseval)', () {
      final espectro = welch(_seno(0.25, amplitud: 3), segundosSegmento: 60);
      expect(espectro.varianzaEntre(0.1, 0.5), closeTo(4.5, 0.05));
    });

    test('con un armónico más fuerte, elige la fundamental', () {
      final x = [
        for (var i = 0; i < 900; i++)
          math.sin(2 * math.pi * 0.9 * i / 30) +
              1.3 * math.sin(2 * math.pi * 1.8 * i / 30),
      ];
      final pico = picoEnBanda(welch(x), fcMinimaHz, fcMaximaHz)!;
      expect(pico.frecuencia, closeTo(0.9, 0.02));
    });

    test('un pico pegado al borde no cuenta', () {
      final pico = picoEnBanda(
        welch(_seno(0.105), segundosSegmento: 60, puntos: 8192),
        frMinimaHz,
        frMaximaHz,
        margenBordeHz: 0.02,
      )!;
      expect(pico.enElBorde, isTrue);
    });
  });

  group('conteo de picos', () {
    test('cuenta los latidos de 72 lpm', () {
      final picos = detectarPicos(_seno(1.2, segundos: 10));
      expect(picos.length, inInclusiveRange(11, 13));

      final conteo = fcPorPicos(picos)!;
      expect(conteo.fc, closeTo(72, 0.5));
      expect(conteo.variacion, lessThan(0.02));
    });

    test('con menos de cuatro latidos no hay FC', () {
      expect(fcPorPicos([0.5, 1.3, 2.1]), isNull);
    });
  });

  group('FC con señales sintéticas (modo dedo)', () {
    for (final lpm in _frecuencias) {
      test('$lpm lpm limpia: ±3 lpm y calidad buena', () {
        final r = _barrido(lpm, (s) => s.dedo(lpm: lpm, ruido: 0.05));
        expect(r.errorMaximo, lessThanOrEqualTo(3));
        expect(r.calidadMinima, greaterThanOrEqualTo(0.7));
      });

      test('$lpm lpm con ruido moderado: ±5 lpm', () {
        final r = _barrido(lpm, (s) => s.dedo(lpm: lpm, ruido: 1));
        expect(r.errorMaximo, lessThanOrEqualTo(5));
        expect(r.calidadMinima, greaterThanOrEqualTo(0.6));
      });

      test('$lpm lpm con deriva diez veces el pulso: ±3 lpm', () {
        final r = _barrido(
          lpm,
          (s) => s.dedo(lpm: lpm, ruido: 0.2, deriva: 10),
        );
        expect(r.errorMaximo, lessThanOrEqualTo(3));
        expect(r.calidadMinima, greaterThanOrEqualTo(0.7));
      });

      test('$lpm lpm con tres movimientos bruscos: ±5 lpm', () {
        final r = _barrido(
          lpm,
          (s) => s.dedo(lpm: lpm, ruido: 0.2, artefactos: 3),
        );
        expect(r.errorMaximo, lessThanOrEqualTo(5));
      });
    }

    test('la precisión obtenida, en una tabla', () {
      final filas = <String>[];
      for (final lpm in _frecuencias) {
        final limpia = _barrido(lpm, (s) => s.dedo(lpm: lpm, ruido: 0.05));
        final ruido = _barrido(lpm, (s) => s.dedo(lpm: lpm, ruido: 1));
        filas.add(
          '${lpm.toInt()} lpm: limpia ±${limpia.errorMaximo.toStringAsFixed(2)}'
          ' · ruido ±${ruido.errorMaximo.toStringAsFixed(2)}',
        );
        expect(limpia.errorMaximo, lessThan(1));
        expect(ruido.errorMaximo, lessThan(2));
      }
      debugPrint(
        'Precisión (peor de $_semillas semillas): ${filas.join('; ')}',
      );
    });
  });

  group('calidad baja', () {
    test('una señal plana: calidad cero y sin FC', () {
      for (var semilla = 1; semilla <= 5; semilla++) {
        final plana = Sintetizador(semilla).plana();
        final r = analizarSenal(plana.tiempos, plana.valores);

        expect(r.calidad.valor, lessThan(0.1));
        expect(r.calidad.motivo, MotivoCalidad.senalPlana);
        expect(r.fc, isNull);
        expect(r.fr, isNull);
      }
    });

    test('solo ruido, sin pulso: calidad baja', () {
      for (var semilla = 1; semilla <= 10; semilla++) {
        final ruido = Sintetizador(semilla).soloRuido();
        final r = analizarSenal(ruido.tiempos, ruido.valores);
        expect(r.calidad.valor, lessThan(0.4));
        expect(r.fr, isNull);
      }
    });

    test('menos de ocho segundos: no hay resultado', () {
      final corta = Sintetizador(1).dedo(lpm: 72, segundos: 5);
      final r = analizarSenal(corta.tiempos, corta.valores);
      expect(r.fc, isNull);
      expect(r.calidad.motivo, MotivoCalidad.pocosDatos);
    });

    test('la cámara a 5 cuadros por segundo: pocos cuadros', () {
      final lenta = Sintetizador(1).dedo(lpm: 72, fps: 5);
      final r = analizarSenal(lenta.tiempos, lenta.valores);
      expect(r.fc, isNull);
      expect(r.calidad.motivo, MotivoCalidad.pocosCuadros);
    });

    test('la yema sin cubrir la cámara baja la calidad y lo dice', () {
      final serie = Sintetizador(1).dedo(lpm: 72);
      final r = analizarSenal(
        serie.tiempos,
        serie.valores,
        dedo: const CondicionesDedo(cobertura: 0.4, saturacion: 0),
      );
      expect(r.calidad.valor, lessThan(0.1));
      expect(r.calidad.motivo, MotivoCalidad.sinCobertura);
    });

    test('la imagen quemada baja la calidad y lo dice', () {
      final serie = Sintetizador(1).dedo(lpm: 72);
      final r = analizarSenal(
        serie.tiempos,
        serie.valores,
        dedo: const CondicionesDedo(cobertura: 1, saturacion: 0.9),
      );
      expect(r.calidad.valor, lessThan(0.1));
      expect(r.calidad.motivo, MotivoCalidad.saturada);
    });

    test('el desacuerdo entre el espectro y los picos baja la calidad', () {
      final acuerdo = calcularCalidad(
        prominencia: 0.8,
        desacuerdo: 1,
        variacion: 0.05,
      );
      final desacuerdo = calcularCalidad(
        prominencia: 0.8,
        desacuerdo: 20,
        variacion: 0.05,
      );
      final desorden = calcularCalidad(
        prominencia: 0.8,
        desacuerdo: 20,
        variacion: 0.5,
      );
      expect(acuerdo.valor, greaterThan(0.9));
      // Sin acuerdo, como mucho «regular».
      expect(desacuerdo.valor, lessThanOrEqualTo(0.6));
      expect(desorden.valor, lessThan(0.5));
      expect(desorden.motivo, MotivoCalidad.movimiento);
    });
  });

  group('frecuencia respiratoria', () {
    for (final lpm in _frecuencias) {
      for (final rpm in [10.0, 15.0, 20.0]) {
        test('$rpm rpm con el pulso a $lpm lpm: ±2 rpm', () {
          for (var semilla = 1; semilla <= 6; semilla++) {
            final serie = Sintetizador(semilla)
                .dedo(lpm: lpm, ruido: 0.1, respiracionRpm: rpm);
            final r = analizarSenal(serie.tiempos, serie.valores);
            expect(r.fr, isNotNull, reason: 'semilla $semilla');
            expect(r.fr!, closeTo(rpm, 2));
          }
        });
      }
    }

    test('sin respiración en la señal no se inventa una', () {
      for (final lpm in _frecuencias) {
        expect(_barrido(lpm, (s) => s.dedo(lpm: lpm, ruido: 0.05)).conFr, 0);
        expect(_barrido(lpm, (s) => s.dedo(lpm: lpm, ruido: 0.5)).conFr, 0);
        expect(_barrido(lpm, (s) => s.dedo(lpm: lpm, ruido: 1)).conFr, 0);
        expect(
          _barrido(lpm, (s) => s.dedo(lpm: lpm, ruido: 0.2, deriva: 10)).conFr,
          0,
        );
      }
    });

    test('con calidad por debajo de 0,6 no se da', () {
      final serie = Sintetizador(1)
          .dedo(lpm: 72, ruido: 0.1, respiracionRpm: 15);
      final r = analizarSenal(
        serie.tiempos,
        serie.valores,
        dedo: const CondicionesDedo(cobertura: 0.7, saturacion: 0),
      );
      expect(r.calidad.valor, lessThan(calidadMinimaFr));
      expect(r.fc, isNotNull);
      expect(r.fr, isNull);
    });
  });

  group('POS (modo rostro)', () {
    for (final lpm in _frecuencias) {
      test('$lpm lpm con una luz que parpadea a 1,6 Hz: ±5 lpm', () {
        for (var semilla = 1; semilla <= 8; semilla++) {
          final s = Sintetizador(semilla).rostro(lpm: lpm, brillo: 3);
          final r = analizarRostro(s.tiempos, s.rojo, s.verde, s.azul);
          expect(r.fc, isNotNull);
          expect(r.fc!, closeTo(lpm, 5), reason: 'semilla $semilla');
        }
      });
    }

    test('el canal verde solo se engaña con el parpadeo; POS no', () {
      final s = Sintetizador(3).rostro(lpm: 72, brillo: 3);
      final verde = analizarSenal(s.tiempos, [for (final v in s.verde) -v]);
      final conPos = analizarRostro(s.tiempos, s.rojo, s.verde, s.azul);

      expect((verde.fc! - 72).abs(), greaterThan(10));
      expect((conPos.fc! - 72).abs(), lessThan(3));
    });

    test('sin parpadeo y quieto: ±3 lpm', () {
      for (final lpm in _frecuencias) {
        final s = Sintetizador(7).rostro(lpm: lpm);
        final r = analizarRostro(s.tiempos, s.rojo, s.verde, s.azul);
        expect(r.fc!, closeTo(lpm, 3));
      }
    });
  });
}
