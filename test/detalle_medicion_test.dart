// test/detalle_medicion_test.dart
//
// El detalle de la medición, puro: las medidas de los intervalos con
// series conocidas (pNN50, SD1, SD2, mínimo, máximo y medio), la limpieza
// de los intervalos, la FC por segundo, el detalle de una señal sintética
// y los rangos de referencia para adultos.

import 'dart:math' as math;

import 'package:app_cliniq/features/mediciones/data/models/medicion.dart';
import 'package:app_cliniq/features/mediciones/dominio/detalle_medicion.dart';
import 'package:app_cliniq/features/mediciones/dominio/procesamiento_ppg.dart';
import 'package:app_cliniq/features/mediciones/dominio/rangos_referencia.dart';
import 'package:app_cliniq/features/mediciones/escaner/motor_signos_camara.dart';
import 'package:app_cliniq/features/mediciones/escaner/serie_senal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/mediciones.dart';
import 'dobles/senales.dart';

/// Los instantes de unos latidos con estos intervalos (ms).
List<double> _latidos(List<double> rr) {
  final t = [1.0];
  for (final ms in rr) {
    t.add(t.last + ms / 1000);
  }
  return t;
}

void main() {
  group('Las medidas de los intervalos', () {
    test(
      'alternando 800 y 900 ms: pNN50 100 %, SD1 grande y SD2 casi nula',
      () {
        final rr = [for (var i = 0; i < 10; i++) i.isEven ? 800.0 : 900.0];
        final m = MetricasRr.de(rr)!;
        expect(m.intervalos, 10);
        expect(m.medio, 850);
        expect(m.sdnn, closeTo(52.70, 0.01)); // √(25000 / 9)
        expect(m.rmssd, 100);
        expect(m.pnn50, 100);
        expect(m.sd1, closeTo(74.54, 0.01)); // √0,5 · √(88888,9 / 8)
        expect(m.sd2, closeTo(0, 1));
      },
    );

    test('subiendo de a 10 ms: SD1 nula, pNN50 0 % y SD2 con la tendencia', () {
      final rr = [for (var i = 0; i < 10; i++) 800.0 + 10 * i];
      final m = MetricasRr.de(rr)!;
      expect(m.medio, 845);
      expect(m.rmssd, 10);
      expect(m.pnn50, 0);
      expect(m.sd1, closeTo(0, 1e-9));
      expect(m.sdnn, closeTo(30.28, 0.01));
      expect(m.sd2, closeTo(math.sqrt(2) * m.sdnn, 0.01));
    });

    test('constantes: todo en cero; con menos de tres, nada', () {
      final m = MetricasRr.de(List.filled(8, 1000.0))!;
      expect(m.medio, 1000);
      expect([m.sdnn, m.rmssd, m.pnn50, m.sd1, m.sd2], everyElement(0));
      expect(MetricasRr.de([800, 900]), isNull);
    });

    test('la limpieza quita un latido perdido y uno de más', () {
      final rr = <double>[800, 810, 790, 1600, 805, 400, 395, 800, 810, 790];
      final limpios = intervalosLimpios(_latidos(rr));
      final ms = limpios.map((i) => i.ms.round()).toList();
      expect(ms, isNot(contains(1600)));
      expect(ms, isNot(contains(400)));
      expect(ms, isNot(contains(395)));
      expect(ms.length, 7);
      // Fuera de 42–210 lpm tampoco cuenta.
      expect(intervalosLimpios(_latidos([200, 2000])), isEmpty);
    });
  });

  group('La FC por segundo', () {
    test('una sinusoide de 75 lpm da 75 en cada ventana', () {
      final senal = [
        for (var i = 0; i < 20 * 30; i++) math.sin(2 * math.pi * 1.25 * i / 30),
      ];
      final puntos = fcPorVentana(senal);
      expect(puntos.length, 13); // de 8 a 20 s
      expect(puntos.first.segundo, 8);
      for (final p in puntos) {
        expect(p.fc, closeTo(75, 1));
      }
      expect(fcPorVentana(senal.sublist(0, 100)), isEmpty);
    });
  });

  group('El detalle de una medición', () {
    test('dedo a 72 lpm durante 31 s: todo, con la variabilidad', () {
      final serie = SerieSenal.de(
        ModoEscaner.dedo,
        cuadrosDeDedo(Sintetizador(51).dedo(lpm: 72, segundos: 31)),
      );
      final r = const MotorInterno().analizar(serie);
      final d = r.detalle!;

      expect(d.duracion, closeTo(31, 0.2));
      expect(d.calidad, r.calidad);
      expect(d.onda.length, (DetalleMedicion.segundosOnda * 30).round());
      expect(d.latidosEnOnda.length, inInclusiveRange(10, 14));
      expect(d.latidos, inInclusiveRange(34, 40));
      expect(d.fcPorSegundo.length, greaterThan(20));
      expect(d.fcMinima, closeTo(72, 4));
      expect(d.fcMaxima, closeTo(72, 4));
      expect(d.metricas!.medio, closeTo(60000 / 72, 25));
      expect(d.vfcValida, isTrue);
      expect(d.picoLpm, closeTo(72, 2));
      final pico = d.espectro.reduce((a, b) => a.potencia > b.potencia ? a : b);
      expect(pico.potencia, 1);
      expect(pico.lpm, closeTo(72, 2));
      expect(d.espectro.first.lpm, closeTo(42, 1));
      expect(d.espectro.last.lpm, closeTo(210, 2));
      expect(d.respiracion.length, closeTo(31 * 5, 6));
      expect(d.respiracion.every((v) => v >= -1 && v <= 1), isTrue);
    });

    test('20 s alcanzan para los datos, no para la variabilidad', () {
      final serie = SerieSenal.de(
        ModoEscaner.dedo,
        cuadrosDeDedo(Sintetizador(52).dedo(lpm: 60, segundos: 20)),
      );
      final d = const MotorInterno().analizar(serie).detalle!;
      expect(d.calidadSuficiente, isTrue);
      expect(d.vfcValida, isFalse);
    });

    test('sin resultado válido no hay detalle', () {
      final serie = SerieSenal.de(
        ModoEscaner.dedo,
        cuadrosDeDedo(Sintetizador(53).plana(segundos: 20)),
      );
      expect(const MotorInterno().analizar(serie).detalle, isNull);
    });
  });

  group('Los rangos de referencia para adultos', () {
    test('los de cada tipo (no los que acepta el servidor)', () {
      expect(referenciaDelTipo(TipoMedicion.fc)!.texto(), '60–100');
      expect(referenciaDelTipo(TipoMedicion.fr)!.texto(), '12–20');
      expect(referenciaDelTipo(TipoMedicion.pa)!.texto(), '90–120');
      expect(referenciaDiastolica.texto(), '60–80');
      expect(referenciaDelTipo(TipoMedicion.spo2)!.texto(), '95–100');
      expect(
        referenciaDelTipo(TipoMedicion.temp)!.texto(decimales: 1),
        '36,0–37,5',
      );
      expect(referenciaDelTipo(TipoMedicion.glucosa)!.nota, 'en ayunas');
      expect(referenciaDelTipo(TipoMedicion.peso), isNull);
    });

    test('las etiquetas: «En rango (60–100)», «Alta» y «Baja»', () {
      expect(etiquetaDeRango(TipoMedicion.fc, 72), 'En rango (60–100)');
      expect(etiquetaDeRango(TipoMedicion.fc, 101), 'Alta');
      expect(etiquetaDeRango(TipoMedicion.fc, 55), 'Baja');
      expect(etiquetaDeRango(TipoMedicion.fr, 16), 'En rango (12–20)');
      expect(etiquetaDeRango(TipoMedicion.temp, 36.8), 'En rango (36,0–37,5)');
      expect(
        etiquetaDeRango(TipoMedicion.glucosa, 90),
        'En rango (70–100, en ayunas)',
      );
      expect(etiquetaDeRango(TipoMedicion.peso, 70), isNull);
    });

    test('la presión: cuentan la sistólica y la diastólica', () {
      expect(
        etiquetaDeRango(TipoMedicion.pa, 115, valor2: 75),
        'En rango (90–120 / 60–80)',
      );
      expect(etiquetaDeRango(TipoMedicion.pa, 115, valor2: 85), 'Alta');
      expect(etiquetaDeRango(TipoMedicion.pa, 85, valor2: 70), 'Baja');
      expect(
        estadoDeRango(TipoMedicion.pa, 130, valor2: 55),
        EstadoDeRango.alto,
      );
    });

    test('la leyenda de las gráficas', () {
      expect(leyendaDeReferencia(TipoMedicion.fc), 'Referencia para adultos');
      expect(
        leyendaDeReferencia(TipoMedicion.glucosa),
        'Referencia para adultos (en ayunas)',
      );
    });
  });
}
