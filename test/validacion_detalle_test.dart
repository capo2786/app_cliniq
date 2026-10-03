// test/validacion_detalle_test.dart
//
// La validación del detalle antes de enviarlo o guardarlo en la cola, con
// los límites del servidor (los del contrato y los que agregó el API), y
// que una medición con un detalle que no pasa se guarda igual, sin él.

import 'dart:convert';

import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/mediciones/data/cola_mediciones.dart';
import 'package:app_cliniq/features/mediciones/data/mediciones_service.dart';
import 'package:app_cliniq/features/mediciones/data/models/medicion.dart';
import 'package:app_cliniq/features/mediciones/dominio/detalle_medicion.dart';
import 'package:app_cliniq/features/mediciones/dominio/procesamiento_ppg.dart';
import 'package:app_cliniq/features/mediciones/dominio/validacion_detalle.dart';
import 'package:app_cliniq/features/mediciones/escaner/mediciones_del_resultado.dart';
import 'package:app_cliniq/features/mediciones/escaner/motor_signos_camara.dart';
import 'package:app_cliniq/features/mediciones/escaner/serie_senal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/mediciones.dart';
import 'dobles/senales.dart';

/// Un detalle que, por un error, se escribiría fuera de los límites.
class _DetalleRoto extends DetalleMedicion {
  const _DetalleRoto() : super(duracion: 30, calidad: 0.9);

  @override
  Map<String, dynamic> aJson() => {...super.aJson(), 'picoLpm': 500};

  @override
  DetalleMedicion sinRespiracion() => this;
}

DetalleMedicion _medido() {
  final serie = SerieSenal.de(
    ModoEscaner.dedo,
    cuadrosDeDedo(
      Sintetizador(81).dedo(lpm: 72, segundos: 31, respiracionRpm: 15),
    ),
  );
  return const MotorInterno().analizar(serie).detalle!;
}

Map<String, dynamic> _valido() =>
    jsonDecode(jsonEncode(_medido().aJson())) as Map<String, dynamic>;

MedicionNueva _pulso(DetalleMedicion detalle) => MedicionNueva(
  tipo: TipoMedicion.fc,
  valor: 72,
  metodo: MetodoMedicion.camaraRostro,
  calidad: 0.9,
  medidoEn: DateTime.utc(2026, 10, 3, 15),
  detalle: detalle,
);

void main() {
  group('Los límites del servidor', () {
    test('lo medido pasa', () {
      expect(problemaDelDetalle(_valido()), isNull);
      expect(detalleValido(_valido()), isTrue);
    });

    final rotos = <String, (String, void Function(Map<String, dynamic>))>{
      'un segundo de la FC después de 600 s': (
        'fc.s',
        (d) => ((d['fc'] as Map)['s'] as List)[0] = 601.0,
      ),
      'un segundo de los intervalos negativo': (
        'intervalos.s',
        (d) => ((d['intervalos'] as Map)['s'] as List)[0] = -1.0,
      ),
      'el pico fuera de 30–240': ('picoLpm', (d) => d['picoLpm'] = 250.0),
      'métricas sin un campo': (
        'metricas.sd1',
        (d) => (d['metricas'] as Map).remove('sd1'),
      ),
      'el intervalo medio fuera de 250–2000': (
        'metricas.medio',
        (d) => (d['metricas'] as Map)['medio'] = 200.0,
      ),
      'SDNN de más de 2000': (
        'metricas.sdnn',
        (d) => (d['metricas'] as Map)['sdnn'] = 2500.0,
      ),
      'pNN50 de más de 100': (
        'metricas.pnn50',
        (d) => (d['metricas'] as Map)['pnn50'] = 120.0,
      ),
      'un número como texto': ('duracion', (d) => d['duracion'] = '30'),
      'latidos con decimales': ('latidos', (d) => d['latidos'] = 37.5),
      'la duración fuera de 5–120': ('duracion', (d) => d['duracion'] = 200.0),
      'otra versión': ('v', (d) => d['v'] = 2),
      'un latido fuera de la onda': (
        'onda.latidos',
        (d) => (d['onda'] as Map)['latidos'] = [100000],
      ),
      'una FC imposible': (
        'fc.lpm',
        (d) => ((d['fc'] as Map)['lpm'] as List)[0] = 300.0,
      ),
      'pares de distinto largo': (
        'espectro',
        (d) => ((d['espectro'] as Map)['potencia'] as List).removeLast(),
      ),
      'la respiración fuera de −1…1': (
        'respiracion.valores',
        (d) => ((d['respiracion'] as Map)['valores'] as List)[0] = 3.0,
      ),
      'sin vfcValida': ('vfcValida', (d) => d.remove('vfcValida')),
      'más de 48 KB': ('tamaño', (d) => d['relleno'] = 'x' * 50000),
    };
    for (final MapEntry(key: caso, value: (campo, romper)) in rotos.entries) {
      test('$caso: no pasa ($campo)', () {
        final d = _valido();
        romper(d);
        expect(problemaDelDetalle(d), campo);
      });
    }

    test('sin métricas (null o ausentes) pasa', () {
      expect(detalleValido(_valido()..['metricas'] = null), isTrue);
      expect(detalleValido(_valido()..remove('metricas')), isTrue);
      expect(detalleValido(_valido()..remove('picoLpm')), isTrue);
      expect(detalleValido(_valido()..remove('respiracion')), isTrue);
      expect(detalleValido('detalle'), isFalse);
    });
  });

  group('aJson queda siempre dentro de los límites', () {
    test('lo que se sale se deja fuera', () {
      const d = DetalleMedicion(
        duracion: 30,
        calidad: 0.9,
        fcPorSegundo: [(segundo: 8, fc: 72), (segundo: 650, fc: 72)],
        intervalos: [(segundo: 1, ms: 800), (segundo: 700, ms: 800)],
        metricas: MetricasRr(
          intervalos: 36,
          medio: 3000,
          minimo: 700,
          maximo: 900,
          sdnn: 40,
          rmssd: 30,
          pnn50: 9,
          sd1: 21,
          sd2: 52,
        ),
        vfcValida: true,
        picoLpm: 260,
      );
      final json = d.aJson();
      expect((json['fc'] as Map)['s'], [8.0]);
      expect((json['intervalos'] as Map)['s'], [1.0]);
      expect(json['metricas'], isNull);
      expect(json['vfcValida'], isFalse);
      expect(json.containsKey('picoLpm'), isFalse);
      expect(problemaDelDetalle(json), isNull);
    });
  });

  group('Una medición nunca se pierde por su detalle', () {
    late CacheLocal cache;
    late DioGrabador api;
    late bool hayRed;

    setUp(() {
      cache = CacheEnMemoria();
      hayRed = true;
      api = DioGrabador({
        'POST /portal/mediciones': (_) {
          if (!hayRed) throw errorDeRed();
          return {'mediciones': <Object>[]};
        },
      });
    });

    test('con un detalle que no pasa, va sin él', () {
      final json = _pulso(const _DetalleRoto()).aJson();
      expect(json.containsKey('detalle'), isFalse);
      expect(json['valor'], 72);
      // Con uno bueno, sí.
      expect(_pulso(_medido()).aJson()['detalle'], isA<Map>());
    });

    test('desde el escáner: se guarda igual, sin el detalle', () async {
      final r = ResultadoEscaner(
        modo: ModoEscaner.rostro,
        calidad: 0.9,
        motor: 'interno-pos v1',
        fc: 72,
        detalle: const _DetalleRoto(),
      );
      final mediciones = medicionesDelResultado(
        r,
        medidoEn: DateTime.utc(2026, 10, 3, 15),
      );
      expect(mediciones.single.detalle, isNull);

      final cola = ColaMediciones(cache, MedicionesService(api.dio, cache));
      await cola.registrar('u1', mediciones: mediciones);
      final enviada =
          ((api.ultimo('POST /portal/mediciones').data as Map)['mediciones']
                      as List)
                  .single
              as Map;
      expect(enviada['tipo'], 'FC');
      expect(enviada.containsKey('detalle'), isFalse);
    });

    test('sin red: la cola la guarda sin el detalle que no pasa', () async {
      hayRed = false;
      final cola = ColaMediciones(cache, MedicionesService(api.dio, cache));
      final registro = await cola.registrar(
        'u1',
        mediciones: [_pulso(const _DetalleRoto())],
      );
      expect(registro, isA<RegistroPendiente>());

      final guardado = await cache.leer('mediciones-pendientes:u1') as List;
      final medicion = ((guardado.single as Map)['mediciones'] as List).single;
      expect((medicion as Map).containsKey('detalle'), isFalse);
      expect((await cola.pendientes('u1')).single.mediciones.single.valor, 72);
    });
  });
}
