// test/formato_detalle_test.dart
//
// El formato `detalle` (v1) del «Detalle de la medición»: `aJson` y
// `desdeJson` de ida y vuelta, el redondeo, los límites del contrato, el
// tamaño y la tolerancia a un JSON roto.

import 'dart:convert';

import 'package:app_cliniq/features/mediciones/dominio/detalle_medicion.dart';
import 'package:app_cliniq/features/mediciones/dominio/formato_detalle.dart';
import 'package:app_cliniq/features/mediciones/dominio/procesamiento_ppg.dart';
import 'package:app_cliniq/features/mediciones/escaner/motor_signos_camara.dart';
import 'package:app_cliniq/features/mediciones/escaner/serie_senal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/mediciones.dart';
import 'dobles/senales.dart';

/// El detalle de una medición sintética de verdad: dedo a 72 lpm, 31 s.
DetalleMedicion _medido() {
  final serie = SerieSenal.de(
    ModoEscaner.dedo,
    cuadrosDeDedo(
      Sintetizador(61).dedo(lpm: 72, segundos: 31, respiracionRpm: 15),
    ),
  );
  return const MotorInterno().analizar(serie).detalle!;
}

/// Por el cable: JSON de texto y de vuelta.
Map<String, dynamic> _porElCable(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

/// Un detalle válido y pequeño, para romperlo de a una cosa.
Map<String, dynamic> _valido() => {
  'v': 1,
  'duracion': 30.0,
  'calidad': 0.82,
  'latidos': 37,
  'onda': {
    'fs': 30.0,
    'valores': [0.1, 0.5, 1.0, 0.2, -0.4],
    'latidos': [2],
  },
  'fc': {
    's': [8.0, 9.0],
    'lpm': [78.1, 79.0],
  },
  'intervalos': {
    's': [1.8, 2.6],
    'ms': [758.0, 790.0],
  },
  'metricas': {
    'intervalos': 36,
    'medio': 758,
    'minimo': 690,
    'maximo': 830,
    'sdnn': 41.2,
    'rmssd': 28.4,
    'pnn50': 9.1,
    'sd1': 20.1,
    'sd2': 55.3,
    'corregidos': 2,
  },
  'vfcValida': true,
  'espectro': {
    'lpm': [42.0, 43.3],
    'potencia': [0.03, 1.0],
  },
  'picoLpm': 79.0,
  'respiracion': {
    'fs': 5.0,
    'valores': [0.1, -0.2],
  },
};

bool _redondeado(double x, int decimales) {
  var escala = 1.0;
  for (var i = 0; i < decimales; i++) {
    escala *= 10;
  }
  return ((x * escala) - (x * escala).round()).abs() < 1e-6;
}

void main() {
  group('Ida y vuelta', () {
    test('lo medido sale en el formato v1 y vuelve igual', () {
      final d = _medido();
      final json = _porElCable(d.aJson());

      expect(json['v'], 1);
      expect(json.keys, containsAll(['onda', 'fc', 'intervalos', 'espectro']));
      expect((json['metricas'] as Map)['corregidos'], isA<int>());
      expect(json['vfcValida'], d.vfcValida);
      expect(json.containsKey('respiracion'), isTrue);

      final leido = DetalleMedicion.desdeJson(json)!;
      expect(leido.latidos, d.latidos);
      expect(leido.onda, hasLength(d.onda.length));
      expect(leido.latidosEnOnda, d.latidosEnOnda);
      expect(leido.intervalos, hasLength(d.intervalos.length));
      expect(leido.fcPorSegundo, hasLength(d.fcPorSegundo.length));
      expect(leido.espectro, hasLength(d.espectro.length));
      expect(leido.metricas!.rmssd, closeTo(d.metricas!.rmssd, 0.05));
      expect(leido.vfcValida, d.vfcValida);
      expect(leido.picoLpm, closeTo(d.picoLpm!, 0.05));
      expect(leido.respiracion, hasLength(d.respiracion.length));
      // Ya redondeado, la segunda vuelta no cambia nada.
      expect(DetalleMedicion.desdeJson(_porElCable(leido.aJson())), leido);
    });

    test('redondea: 3 decimales en la onda, la respiración y la potencia; '
        '1 en lo demás', () {
      final json = _porElCable(_medido().aJson());
      final onda = json['onda'] as Map;
      final valores = (onda['valores'] as List).cast<num>();
      expect(valores.every((v) => _redondeado(v.toDouble(), 3)), isTrue);
      expect(valores.any((v) => !_redondeado(v.toDouble(), 2)), isTrue);
      final rr = ((json['intervalos'] as Map)['ms'] as List).cast<num>();
      expect(rr.every((v) => _redondeado(v.toDouble(), 1)), isTrue);
      final potencia = ((json['espectro'] as Map)['potencia'] as List)
          .cast<num>();
      expect(potencia.every((v) => _redondeado(v.toDouble(), 3)), isTrue);
      expect(_redondeado((json['calidad'] as num).toDouble(), 2), isTrue);
      final metricas = json['metricas'] as Map;
      expect(_redondeado((metricas['rmssd'] as num).toDouble(), 1), isTrue);
    });

    test('ocupa mucho menos de 48 KB', () {
      final bytes = utf8.encode(jsonEncode(_medido().aJson())).length;
      expect(bytes, lessThan(maximoBytesDetalle ~/ 3));
    });

    test('sin respiración, no la lleva', () {
      final json = _medido().sinRespiracion().aJson();
      expect(json.containsKey('respiracion'), isFalse);
      expect(DetalleMedicion.desdeJson(json)!.respiracion, isEmpty);
    });
  });

  group('Los límites del formato', () {
    test('lo que se pasa se recorta, y los índices siguen a la onda', () {
      final d = DetalleMedicion(
        duracion: 200,
        calidad: 1.4,
        onda: [for (var i = 0; i < 1200; i++) i.isEven ? 0.5 : -0.5],
        latidosEnOnda: const [10, 400, 1100],
        latidos: 480,
        fcPorSegundo: [
          for (var s = 0; s < 200; s++) (segundo: s.toDouble(), fc: 75.0),
          (segundo: 201, fc: 260),
        ],
        intervalos: [
          for (var i = 0; i < 450; i++) (segundo: i * 0.8, ms: 800.0),
          (segundo: 400, ms: 2400),
        ],
        espectro: [
          for (var i = 0; i < 300; i++) (lpm: 30.0 + i * 0.7, potencia: 0.5),
        ],
        respiracion: List.filled(1000, 2.0),
      );
      final json = _porElCable(d.aJson());
      final onda = json['onda'] as Map;

      expect(json['duracion'], 120);
      expect(json['calidad'], 1);
      expect(json['latidos'], 400);
      expect(onda['valores'], hasLength(900));
      // Se quedan los últimos 900: el 10 se va, 400 y 1100 se corren 300.
      expect(onda['latidos'], [100, 800]);
      expect((json['fc'] as Map)['lpm'], hasLength(150));
      expect((json['fc'] as Map)['lpm'], isNot(contains(260)));
      expect((json['intervalos'] as Map)['ms'], hasLength(400));
      expect((json['intervalos'] as Map)['ms'], isNot(contains(2400)));
      expect((json['espectro'] as Map)['lpm'], hasLength(256));
      final respiracion = (json['respiracion'] as Map)['valores'] as List;
      expect(respiracion, hasLength(900));
      expect(respiracion.every((v) => v == 1), isTrue);
      expect(json['metricas'], isNull);
      expect(json.containsKey('picoLpm'), isFalse);
      expect(DetalleMedicion.desdeJson(json), isNotNull);
    });
  });

  group('La tolerancia a un JSON roto', () {
    test('uno válido se lee y las claves desconocidas no estorban', () {
      final json = _valido()..['algoNuevo'] = {'x': 1};
      final d = DetalleMedicion.desdeJson(json)!;
      expect(d.latidos, 37);
      expect(d.latidosEnOnda, [2]);
      expect(d.metricas!.corregidos, 2);
      expect(d.vfcValida, isTrue);
      expect(d.fsRespiracion, 5);
    });

    test('sin lo opcional (métricas, pico y respiración) también', () {
      final json = _valido()
        ..['metricas'] = null
        ..remove('picoLpm')
        ..remove('respiracion');
      final d = DetalleMedicion.desdeJson(json)!;
      expect(d.metricas, isNull);
      expect(d.vfcValida, isFalse); // sin métricas no hay variabilidad
      expect(d.picoLpm, isNull);
      expect(d.respiracion, isEmpty);
    });

    final rotos = <String, void Function(Map<String, dynamic>)>{
      'otra versión': (j) => j['v'] = 2,
      'sin versión': (j) => j.remove('v'),
      'sin duración': (j) => j.remove('duracion'),
      'latidos con decimales': (j) => j['latidos'] = 3.5,
      'sin onda': (j) => j.remove('onda'),
      'onda.valores con un texto': (j) =>
          (j['onda'] as Map)['valores'] = [0.1, 'x'],
      'onda.valores con un NaN': (j) =>
          (j['onda'] as Map)['valores'] = [0.1, double.nan],
      'un latido fuera de la onda': (j) => (j['onda'] as Map)['latidos'] = [9],
      'pares de distinto largo': (j) =>
          (j['intervalos'] as Map)['ms'] = [758.0],
      'fc que no es un objeto': (j) => j['fc'] = [1, 2],
      'métricas incompletas': (j) => (j['metricas'] as Map).remove('sd1'),
      'corregidos negativos': (j) => (j['metricas'] as Map)['corregidos'] = -1,
      'respiración rota': (j) => j['respiracion'] = {'fs': 5},
      'pico que no es un número': (j) => j['picoLpm'] = 'alto',
    };
    for (final MapEntry(key: caso, value: romper) in rotos.entries) {
      test('$caso: null, sin lanzar', () {
        final json = _valido();
        romper(json);
        expect(DetalleMedicion.desdeJson(json), isNull);
      });
    }

    test('lo que ni siquiera es un objeto: null', () {
      for (final cosa in <Object?>[null, 'detalle', 42, <Object>[]]) {
        expect(DetalleMedicion.desdeJson(cosa), isNull);
      }
    });
  });

  test('las métricas y el detalle se comparan por su valor', () {
    final a = DetalleMedicion.desdeJson(_valido());
    final b = DetalleMedicion.desdeJson(_valido());
    expect(a, b);
    expect(
      MetricasRr.deCorregidos(corregirIntervalos([1, 1.8, 2.6, 3.4, 4.2])),
      MetricasRr.deCorregidos(corregirIntervalos([1, 1.8, 2.6, 3.4, 4.2])),
    );
  });
}
