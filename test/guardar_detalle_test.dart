// test/guardar_detalle_test.dart
//
// El detalle se guarda con el pulso de la cámara: en el cuerpo del POST
// (solo en la FC de la cámara), en la cola sin red (con un tamaño
// razonable) y al volver la red; y la medición completa se pide con
// `GET /portal/mediciones/:id`, con su copia para verla sin red.

import 'dart:convert';

import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/mediciones/data/cola_mediciones.dart';
import 'package:app_cliniq/features/mediciones/data/mediciones_service.dart';
import 'package:app_cliniq/features/mediciones/data/models/medicion.dart';
import 'package:app_cliniq/features/mediciones/dominio/detalle_medicion.dart';
import 'package:app_cliniq/features/mediciones/escaner/mediciones_del_resultado.dart';
import 'package:app_cliniq/features/mediciones/escaner/motor_signos_camara.dart';
import 'package:app_cliniq/features/mediciones/escaner/serie_senal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/mediciones.dart';
import 'dobles/senales.dart';

/// Un resultado del escáner de verdad, con su detalle.
ResultadoEscaner _resultado({int semilla = 71, double? respiracionRpm = 15}) {
  final serie = SerieSenal.de(
    ModoEscaner.dedo,
    cuadrosDeDedo(
      Sintetizador(semilla)
          .dedo(lpm: 72, segundos: 31, respiracionRpm: respiracionRpm),
    ),
  );
  return const MotorInterno().analizar(serie);
}

void main() {
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

  MedicionesService servicio() => MedicionesService(api.dio, cache);

  group('Las mediciones del resultado', () {
    test('la FC lleva el detalle; la FR, no', () {
      final r = _resultado();
      final mediciones = medicionesDelResultado(
        r,
        medidoEn: DateTime.utc(2026, 10, 3, 15),
      );
      expect(mediciones.first.tipo, TipoMedicion.fc);
      expect(mediciones.first.detalle, isNotNull);
      final json = mediciones.first.aJson();
      expect((json['detalle'] as Map)['v'], 1);
      if (mediciones.length > 1) {
        expect(mediciones[1].detalle, isNull);
        expect(mediciones[1].aJson().containsKey('detalle'), isFalse);
      }
    });

    test('sin FR, el detalle va sin la onda de la respiración', () {
      final r = _resultado();
      final sinFr = ResultadoEscaner(
        modo: r.modo,
        calidad: r.calidad,
        motor: r.motor,
        fc: r.fc,
        detalle: r.detalle,
      );
      final fc = medicionesDelResultado(
        sinFr,
        medidoEn: DateTime.utc(2026, 10, 3, 15),
      ).single;
      expect(r.detalle!.respiracion, isNotEmpty);
      expect(fc.detalle!.respiracion, isEmpty);
      expect((fc.aJson()['detalle'] as Map).containsKey('respiracion'), false);
    });

    test('un detalle en otra medición que no es la FC de la cámara no se '
        'envía', () {
      final detalle = _resultado().detalle;
      final delAparato = MedicionNueva(
        tipo: TipoMedicion.fc,
        valor: 78,
        metodo: MetodoMedicion.dispositivo,
        medidoEn: DateTime.utc(2026, 10, 3, 15),
        detalle: detalle,
      );
      expect(delAparato.admiteDetalle, isFalse);
      expect(delAparato.aJson().containsKey('detalle'), isFalse);
    });
  });

  group('En la cola sin red', () {
    test('se guarda con su detalle, ocupa poco y sale entero al volver la '
        'red', () async {
      final cola = ColaMediciones(cache, servicio());
      final mediciones = medicionesDelResultado(
        _resultado(),
        medidoEn: DateTime.utc(2026, 10, 3, 15),
      );

      hayRed = false;
      final registro = await cola.registrar('u1', mediciones: mediciones);
      expect(registro, isA<RegistroPendiente>());

      // Lo que queda en Hive: el envío entero, con el detalle.
      final guardado = await cache.leer('mediciones-pendientes:u1');
      final bytes = utf8.encode(jsonEncode(guardado)).length;
      expect(bytes, lessThan(20 * 1024));

      final pendiente = (await cola.pendientes('u1')).single;
      final leido = pendiente.mediciones.first.detalle!;
      expect(
        leido,
        DetalleMedicion.desdeJson(mediciones.first.detalle!.aJson()),
      );

      hayRed = true;
      final sincronizacion = await cola.enviarPendientes('u1');
      expect(sincronizacion.enviados, 1);
      final enviado =
          ((api.ultimo('POST /portal/mediciones').data as Map)['mediciones']
                      as List)
                  .first
              as Map;
      expect(enviado['detalle'], mediciones.first.detalle!.aJson());
    });

    test('un detalle roto en la cola no impide enviar la medición', () {
      final json = _nuevaJson()..['detalle'] = {'v': 1, 'onda': 'rota'};
      final leida = MedicionNueva.desdeJson(json)!;
      expect(leida.valor, 78);
      expect(leida.detalle, isNull);
    });
  });

  group('La medición completa', () {
    late Map<String, dynamic> completa;

    setUp(() {
      completa = medicionJson(
        id: 'fc9',
        tipo: 'FC',
        valor: 74,
        metodo: 'CAMARA_ROSTRO',
        calidad: 0.86,
        contexto: null,
      )..['detalle'] = _resultado().detalle!.aJson();
      api.rutas['GET /portal/mediciones/fc9'] = (_) {
        if (!hayRed) throw errorDeRed();
        return completa;
      };
    });

    test('la lista solo dice tieneDetalle; la completa trae el detalle', () {
      final enLista = Medicion.desdeJson(
        medicionJson(id: 'fc9', tipo: 'FC', metodo: 'CAMARA_ROSTRO')
          ..['tieneDetalle'] = true,
      )!;
      expect(enLista.tieneDetalle, isTrue);
      expect(enLista.detalle, isNull);

      final leida = Medicion.desdeJson(completa)!;
      expect(leida.tieneDetalle, isTrue);
      expect(leida.detalle!.latidos, greaterThan(30));

      final anterior = Medicion.desdeJson(medicionJson(tipo: 'FC'))!;
      expect(anterior.tieneDetalle, isFalse);
    });

    test(
      'GET /portal/mediciones/:id, también envuelta en «medicion»',
      () async {
        final obtenida = await servicio().obtener('u1', 'fc9');
        expect(api.claves, ['GET /portal/mediciones/fc9']);
        expect(obtenida.medicion.detalle, isNotNull);
        expect(obtenida.desdeCache, isFalse);
        expect(
          MedicionesService.leerMedicion({'medicion': completa})!.id,
          'fc9',
        );
      },
    );

    test('sin red: la copia de la última vez; sin copia, el error', () async {
      await servicio().obtener('u1', 'fc9');
      hayRed = false;
      final copia = await servicio().obtener('u1', 'fc9');
      expect(copia.desdeCache, isTrue);
      expect(copia.guardadaEn, isNotNull);
      expect(copia.medicion.detalle, isNotNull);

      api.rutas['GET /portal/mediciones/otra'] = (_) => throw errorDeRed();
      await expectLater(servicio().obtener('u1', 'otra'), throwsA(anything));
    });

    test('ajena o borrada: el 404 sube tal cual', () async {
      api.rutas['GET /portal/mediciones/ajena'] = (_) => throw errorHttp(404);
      await expectLater(
        servicio().obtener('u1', 'ajena'),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'estado',
            404,
          ),
        ),
      );
    });

    test(
      'se guardan solo las últimas copias, y borrar quita la suya',
      () async {
        for (var i = 0; i < MedicionesService.copiasDeMediciones + 3; i++) {
          api.rutas['GET /portal/mediciones/m$i'] = (_) =>
              medicionJson(id: 'm$i');
          await servicio().obtener('u1', 'm$i');
        }
        final copias = await cache.leer('mediciones-completas:u1') as Map;
        expect(copias.length, MedicionesService.copiasDeMediciones);
        expect(copias.containsKey('m0'), isFalse);
        expect(copias.containsKey('m12'), isTrue);

        api.rutas['DELETE /portal/mediciones/m12'] = (_) => null;
        await servicio().eliminar('m12', uid: 'u1');
        expect(await servicio().completaGuardada('u1', 'm12'), isNull);
        expect(await servicio().completaGuardada('u1', 'm11'), isNotNull);
      },
    );
  });
}

/// Una medición de la cola, como JSON.
Map<String, dynamic> _nuevaJson() => medicionNueva().aJson();
