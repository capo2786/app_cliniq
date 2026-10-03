// test/mediciones_datos_test.dart
//
// Las mediciones del paciente: el modelo, las reglas (rangos del servidor,
// la hora, cómo se enseña un valor, la calidad), el servicio de
// `/portal/mediciones` y la cola sin red en la caché (Hive).

import 'package:app_cliniq/core/red/estado_de_la_red.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/mediciones/data/cola_mediciones.dart';
import 'package:app_cliniq/features/mediciones/data/mediciones_service.dart';
import 'package:app_cliniq/features/mediciones/data/models/medicion.dart';
import 'package:app_cliniq/features/mediciones/dominio/reglas_mediciones.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/mediciones.dart';

void main() {
  setUp(SondeoDeRed.olvidarLaInstancia);

  group('El modelo', () {
    test('lee una medición de la API con su instante real', () {
      final m = Medicion.desdeJson(medicionJson())!;

      expect(m.id, 'm1');
      expect(m.tipo, TipoMedicion.pa);
      expect(m.valor, 128);
      expect(m.valor2, 82);
      expect(m.unidad, 'mmHg');
      expect(m.metodo, MetodoMedicion.dispositivo);
      expect(m.contexto, ContextoMedicion.reposo);
      expect(m.medidoEn, DateTime.utc(2026, 10, 3, 15, 20));
      expect(m.experimental, isFalse);
      expect(m.usada, isFalse);
    });

    test('las de la cámara son experimentales aunque no lo diga', () {
      final m = Medicion.desdeJson(
        medicionJson(
          tipo: 'FC',
          valor: 78,
          metodo: 'CAMARA_DEDO',
          calidad: 0.82,
          experimental: null,
        ),
      )!;
      expect(m.experimental, isTrue);
      expect(m.calidad, 0.82);
    });

    test('sin tipo conocido, sin valor o sin fecha, se salta', () {
      expect(Medicion.desdeJson(medicionJson(tipo: 'COLESTEROL')), isNull);
      expect(Medicion.desdeJson({...medicionJson(), 'valor': null}), isNull);
      expect(Medicion.desdeJson({...medicionJson(), 'medidoEn': ''}), isNull);
    });

    test('lo que se envía: sin unidad (la fija el servidor) ni vacíos', () {
      final nueva = MedicionNueva(
        tipo: TipoMedicion.fc,
        valor: 78,
        metodo: MetodoMedicion.camaraDedo,
        calidad: 0.8,
        notas: 'motor: interno-ppg v1',
        medidoEn: DateTime.utc(2026, 10, 3, 15, 20),
      );

      expect(nueva.aJson(), {
        'tipo': 'FC',
        'valor': 78,
        'metodo': 'CAMARA_DEDO',
        'calidad': 0.8,
        'notas': 'motor: interno-ppg v1',
        'medidoEn': '2026-10-03T15:20:00.000Z',
      });
      expect(nueva.adjuntaA(citaId: 'c9').aJson()['citaId'], 'c9');
      expect(MedicionNueva.desdeJson(nueva.aJson()), nueva);
    });
  });

  group('Las reglas', () {
    test('los rangos del servidor, uno por tipo', () {
      expect(validarValores(TipoMedicion.fc, 78), isNull);
      expect(validarValores(TipoMedicion.fc, 29), contains('30 y 220 lpm'));
      expect(validarValores(TipoMedicion.fr, 61), isNotNull);
      expect(validarValores(TipoMedicion.spo2, 69), isNotNull);
      expect(validarValores(TipoMedicion.spo2, 100), isNull);
      expect(validarValores(TipoMedicion.temp, 43.1), isNotNull);
      expect(validarValores(TipoMedicion.temp, 36.8), isNull);
      expect(validarValores(TipoMedicion.glucosa, 19), isNotNull);
      expect(validarValores(TipoMedicion.peso, 0.5), isNotNull);
      expect(validarValores(TipoMedicion.peso, 72.4), isNull);
      expect(validarValores(TipoMedicion.fc, null), 'Escribe el valor.');
    });

    test('la presión: las dos y la sistólica mayor', () {
      expect(validarValores(TipoMedicion.pa, 120, 80), isNull);
      expect(validarValores(TipoMedicion.pa, 120), contains('diastólica'));
      expect(validarValores(TipoMedicion.pa, 270, 80), contains('sistólica'));
      expect(validarValores(TipoMedicion.pa, 120, 170), contains('30 y 160'));
      expect(validarValores(TipoMedicion.pa, 90, 90), contains('mayor'));
    });

    test(
      'la hora: ni en el futuro (5 min de margen) ni de hace más de 30 días',
      () {
        final ahora = DateTime.utc(2026, 10, 3, 15);
        expect(validarMomento(ahora, ahora), isNull);
        expect(
          validarMomento(ahora.add(const Duration(minutes: 4)), ahora),
          isNull,
        );
        expect(
          validarMomento(ahora.add(const Duration(minutes: 6)), ahora),
          contains('futuro'),
        );
        expect(
          validarMomento(ahora.subtract(const Duration(days: 31)), ahora),
          contains('30 días'),
        );
      },
    );

    test('cómo se lee y se escribe un valor', () {
      expect(leerNumero('36,8'), 36.8);
      expect(leerNumero(' 78 '), 78);
      expect(leerNumero('abc'), isNull);
      expect(valorLegible(TipoMedicion.fc, 78), '78 lpm');
      expect(valorLegible(TipoMedicion.pa, 120, valor2: 80), '120/80 mmHg');
      expect(valorLegible(TipoMedicion.temp, 36.8), '36,8 °C');
      expect(valorLegible(TipoMedicion.peso, 72), '72,0 kg');
    });

    test('la calidad en palabras', () {
      expect(nivelDeCalidad(0.9), NivelCalidad.buena);
      expect(nivelDeCalidad(0.7), NivelCalidad.buena);
      expect(nivelDeCalidad(0.5), NivelCalidad.regular);
      expect(nivelDeCalidad(0.2), NivelCalidad.baja);
    });

    test('qué se ofrece en el formulario', () {
      expect(metodosDelFormulario(TipoMedicion.pa), [
        MetodoMedicion.dispositivo,
      ]);
      expect(
        metodosDelFormulario(TipoMedicion.fc),
        contains(MetodoMedicion.manual),
      );
      expect(contextosDelTipo(TipoMedicion.glucosa), [
        ContextoMedicion.ayunas,
        ContextoMedicion.posprandial,
      ]);
      expect(contextosDelTipo(TipoMedicion.temp), isEmpty);
      // La cámara nunca se ofrece a mano, y nunca para presión ni SpO2.
      for (final tipo in TipoMedicion.values) {
        expect(metodosDelFormulario(tipo).any((m) => m.esCamara), isFalse);
      }
    });
  });

  group('El servicio', () {
    late CacheLocal cache;
    late DioGrabador api;
    late Object? respuesta;
    late bool hayRed;

    setUp(() {
      cache = CacheEnMemoria();
      hayRed = true;
      respuesta = {
        'items': [medicionJson()],
        'total': 30,
        'page': 1,
        'limit': 20,
      };
      api = DioGrabador({
        'GET /portal/mediciones': (_) {
          if (!hayRed) throw errorDeRed();
          return respuesta;
        },
        'POST /portal/mediciones': (pedido) {
          if (!hayRed) throw errorDeRed();
          return {
            'mediciones': [medicionJson(id: 'nueva')],
          };
        },
        'DELETE /portal/mediciones/m1': (_) => null,
      });
    });

    MedicionesService servicio() => MedicionesService(api.dio, cache);

    test('el titular sin pacienteId; un dependiente, con el suyo', () async {
      await servicio().listar('u1');
      expect(api.ultimo('GET /portal/mediciones').queryParameters, isEmpty);

      await servicio().listar('u1', pacienteId: 'd1');
      expect(api.ultimo('GET /portal/mediciones').queryParameters, {
        'pacienteId': 'd1',
      });
    });

    test('lee {items, total, page, limit} y sabe si hay más', () async {
      final pagina = await servicio().listar('u1');
      expect(pagina.mediciones.single.id, 'm1');
      expect(pagina.hayMas, isTrue);
      expect(pagina.parametroPagina, 'page');

      await servicio().listar('u1', pagina: 2);
      expect(api.ultimo('GET /portal/mediciones').queryParameters, {'page': 2});
    });

    test(
      'también {items, hayMas}, los nombres en español y una lista sola',
      () {
        expect(
          MedicionesService.leerPagina({
            'items': [medicionJson()],
            'hayMas': true,
          }).hayMas,
          isTrue,
        );
        final espanol = MedicionesService.leerPagina({
          'items': <Object>[],
          'total': 5,
          'pagina': 1,
          'limite': 20,
        });
        expect(espanol.hayMas, isFalse);
        expect(espanol.parametroPagina, 'pagina');
        expect(
          MedicionesService.leerPagina([medicionJson()]).mediciones,
          hasLength(1),
        );
        expect(
          () => MedicionesService.leerPagina('<html>'),
          throwsFormatException,
        );
      },
    );

    test('sin red, la copia guardada; sin copia, el error', () async {
      hayRed = false;
      await expectLater(servicio().listar('u1'), throwsA(isA<DioException>()));

      hayRed = true;
      await servicio().listar('u1');
      hayRed = false;
      final copia = await servicio().listar('u1');
      expect(copia.desdeCache, isTrue);
      expect(copia.mediciones.single.id, 'm1');
      expect(copia.guardadaEn, isNotNull);

      // La copia es de la persona: se borra al cerrar sesión.
      await cache.vaciarDatosPersonales();
      expect(await servicio().guardada('u1'), isNull);
    });

    test('POST con pacienteId y las mediciones; DELETE por id', () async {
      final creadas = await servicio().enviar(
        pacienteId: 'd1',
        mediciones: [medicionNueva()],
      );
      expect(creadas.single.id, 'nueva');

      final cuerpo = api.ultimo('POST /portal/mediciones').data as Map;
      expect(cuerpo['pacienteId'], 'd1');
      expect((cuerpo['mediciones'] as List).single['tipo'], 'FC');

      await servicio().eliminar('m1');
      expect(api.claves.last, 'DELETE /portal/mediciones/m1');
    });
  });

  group('La cola sin red', () {
    late CacheLocal cache;
    late DioGrabador api;
    late Object? Function(RequestOptions) alEnviar;

    setUp(() {
      cache = CacheEnMemoria();
      alEnviar = (_) => {'mediciones': <Object>[]};
      api = DioGrabador({
        'POST /portal/mediciones': (pedido) => alEnviar(pedido),
      });
    });

    ColaMediciones cola() => ColaMediciones(
      cache,
      MedicionesService(api.dio, cache),
      ahora: () => DateTime.utc(2026, 10, 3, 15),
    );

    test('con red, se envía y no queda nada', () async {
      final resultado = await cola().registrar(
        'u1',
        mediciones: [medicionNueva()],
      );
      expect(resultado, isA<RegistroEnviado>());
      expect(await cola().pendientes('u1'), isEmpty);
    });

    test('sin red, queda en Hive (cifrada) y se envía al volver', () async {
      alEnviar = (_) => throw errorDeRed();
      final c = cola();
      var avisos = 0;
      c.cambios.addListener(() => avisos++);

      final resultado = await c.registrar(
        'u1',
        pacienteId: 'd1',
        mediciones: [medicionNueva()],
      );
      expect(resultado, isA<RegistroPendiente>());
      expect(avisos, 1);

      final pendientes = await c.pendientes('u1');
      expect(pendientes.single.pacienteId, 'd1');
      expect(pendientes.single.mediciones.single.valor, 78);
      expect(cache.leer('mediciones-pendientes:u1'), completion(isA<List>()));

      // Sigue sin red: nada cambia.
      expect((await c.enviarPendientes('u1')).quedan, 1);

      alEnviar = (_) => {'mediciones': <Object>[]};
      final sincronizado = await c.enviarPendientes('u1');
      expect(sincronizado.enviados, 1);
      expect(sincronizado.quedan, 0);
      expect(await c.pendientes('u1'), isEmpty);

      final cuerpo = api.ultimo('POST /portal/mediciones').data as Map;
      expect(cuerpo['pacienteId'], 'd1');
    });

    test('un rechazo al registrar con red se propaga y no se guarda', () async {
      alEnviar = (_) => throw errorHttp(
        409,
        'El escáner con la cámara está apagado en esta clínica.',
      );
      await expectLater(
        cola().registrar('u1', mediciones: [medicionNueva()]),
        throwsA(isA<DioException>()),
      );
      expect(await cola().pendientes('u1'), isEmpty);
    });

    test('al enviar lo pendiente, un 400 lo marca y no se reintenta', () async {
      alEnviar = (_) => throw errorDeRed();
      final c = cola();
      await c.registrar('u1', mediciones: [medicionNueva()]);
      await c.registrar('u1', mediciones: [medicionNueva(valor: 80)]);

      var llamadas = 0;
      alEnviar = (pedido) {
        llamadas++;
        final valor = ((pedido.data as Map)['mediciones'] as List).first;
        if (valor['valor'] == 78) {
          throw errorHttp(400, 'La medición tiene más de 30 días.');
        }
        return {'mediciones': <Object>[]};
      };

      final r = await c.enviarPendientes('u1');
      expect(r.enviados, 1);
      expect(r.rechazados, 1);
      final quedan = await c.pendientes('u1');
      expect(quedan.single.rechazo, 'La medición tiene más de 30 días.');

      // No se vuelve a intentar.
      await c.enviarPendientes('u1');
      expect(llamadas, 2);

      await c.descartar('u1', quedan.single.idLocal);
      expect(await c.pendientes('u1'), isEmpty);
    });

    test('con el servidor caído, se queda todo para la próxima', () async {
      alEnviar = (_) => throw errorDeRed();
      final c = cola();
      await c.registrar('u1', mediciones: [medicionNueva()]);
      await c.registrar('u1', mediciones: [medicionNueva()]);

      var llamadas = 0;
      alEnviar = (_) {
        llamadas++;
        throw errorHttp(503);
      };
      final r = await c.enviarPendientes('u1');
      expect(r.quedan, 2);
      expect(llamadas, 1);
      expect((await c.pendientes('u1')).every((e) => !e.rechazado), isTrue);
    });

    test('dos envíos que se cruzan comparten el mismo', () async {
      alEnviar = (_) => throw errorDeRed();
      final c = cola();
      await c.registrar('u1', mediciones: [medicionNueva()]);

      var llamadas = 0;
      alEnviar = (_) {
        llamadas++;
        return {'mediciones': <Object>[]};
      };
      await Future.wait([c.enviarPendientes('u1'), c.enviarPendientes('u1')]);
      expect(llamadas, 1);
    });

    test('lo pendiente es de la persona: se borra al cerrar sesión', () async {
      alEnviar = (_) => throw errorDeRed();
      await cola().registrar('u1', mediciones: [medicionNueva()]);
      await cache.vaciarDatosPersonales();
      expect(await cola().pendientes('u1'), isEmpty);
    });
  });
}
