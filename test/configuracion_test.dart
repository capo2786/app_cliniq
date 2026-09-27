// test/configuracion_test.dart

import 'package:app_cliniq/core/configuracion/config_publica.dart';
import 'package:app_cliniq/core/configuracion/config_publica_cubit.dart';
import 'package:app_cliniq/core/configuracion/config_publica_service.dart';
import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/core/fechas/instante.dart';
import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/network/api_interceptor.dart';
import 'package:app_cliniq/core/red/estado_de_la_red.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';

/// La configuración pública: de dónde sale, cómo se guarda, qué pasa sin red
/// y que nunca se inventan valores.
void main() {
  late CacheLocal cache;
  late bool hayRed;
  late Object? respuesta;
  late DioGrabador api;

  setUp(() {
    SondeoDeRed.olvidarLaInstancia();
    cache = CacheEnMemoria();
    hayRed = true;
    respuesta = configJson();
    api = DioGrabador({
      'GET /configuracion/publica': (_) {
        if (!hayRed) throw errorDeRed();
        return respuesta;
      },
    });
  });

  ConfigPublicaService servicio() => ConfigPublicaService(
    api.dio,
    cache,
    ahora: () => DateTime.utc(2026, 9, 28, 14),
  );

  group('El servicio', () {
    test('pide GET /configuracion/publica y lee todo lo que usa', () async {
      final cargada = await servicio().cargar();
      final config = cargada.config;

      expect(api.claves, ['GET /configuracion/publica']);
      expect(cargada.desdeCache, isFalse);
      expect(config.clinica.nombre, 'Clínica Andina');
      expect(config.clinica.telefonoEmergencia, '911');
      expect(config.clinica.logo, isNull);
      expect(config.clinica.zonaHoraria, 'America/Guayaquil');
      expect(config.agenda.horasMinimasCambio, 12);
      expect(config.agenda.horaInicioTarde, '12:00');
      expect(config.telemedicina.minutosAntes, 15);
      expect(config.telemedicina.maxArchivosConsulta, 30);
      expect(config.archivos.tamanoMaximoBytes, 20 * 1024 * 1024);
      expect(config.archivos.tipos, [
        'application/pdf',
        'image/jpeg',
        'image/png',
      ]);
      expect(config.seguridad.reenvioSegundos, 60);
      expect(config.general.validarCedula, isTrue);
      expect(config.general.soporteHorasSla, {
        'CRITICA': 4,
        'ALTA': 24,
        'MEDIA': 72,
        'BAJA': 120,
      });
      expect(config.general.soporteHorasAviso, 2);
      expect(config.clinico.diasGestacion, 280);
    });

    test('es pública: va sin el token aunque haya sesión, y un 401 ahí no '
        'vence la sesión', () async {
      var vencida = false;
      api.dio.interceptors.insert(
        0,
        ApiInterceptor(
          leerToken: () => 'jwt-de-la-sesion',
          alVencerLaSesion: () => vencida = true,
          sondeo: SondeoDeRed(api.dio),
        ),
      );

      await servicio().cargar();
      final pedido = api.ultimo('GET /configuracion/publica');
      expect(pedido.extra[rutaPublica], isTrue);
      expect(pedido.headers.containsKey('Authorization'), isFalse);

      respuesta = null;
      api.rutas['GET /configuracion/publica'] = (_) => throw errorHttp(401);
      await expectLater(servicio().descargar(), throwsA(anything));
      expect(vencida, isFalse);
    });

    test('guarda cada respuesta buena y, sin red, usa esa copia', () async {
      await servicio().cargar();
      expect(await cache.leer(ConfigPublicaService.claveCache), isNotNull);

      hayRed = false;
      final cargada = await servicio().cargar();

      expect(cargada.desdeCache, isTrue);
      expect(cargada.config.clinica.nombre, 'Clínica Andina');
      expect(cargada.guardadaEn, DateTime.utc(2026, 9, 28, 14));
    });

    test('la copia es de la clínica: sobrevive al cierre de sesión', () async {
      await servicio().cargar();
      await cache.vaciarDatosPersonales();

      expect(await servicio().guardada(), isNotNull);
    });

    test(
      'sin red y sin copia: no hay configuración (nada inventado)',
      () async {
        hayRed = false;

        await expectLater(
          servicio().cargar(),
          throwsA(isA<ConfiguracionNoDisponible>()),
        );
        expect(await servicio().guardada(), isNull);
      },
    );

    test(
      'una respuesta incompleta no se acepta ni pisa la copia buena',
      () async {
        await servicio().cargar();

        final incompleta = configJson();
        (incompleta['agenda'] as Map).remove('pasoMinutos');
        respuesta = incompleta;

        final cargada = await servicio().cargar();
        expect(cargada.desdeCache, isTrue);
        expect(cargada.config.agenda.pasoMinutos, 15);
      },
    );
  });

  group('La lectura es estricta con lo que se usa', () {
    test('un campo que falta dice cuál es', () {
      final json = configJson();
      (json['telemedicina'] as Map).remove('horasRespuesta');

      expect(
        () => ConfigPublica.desdeJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('telemedicina.horasRespuesta'),
          ),
        ),
      );
    });

    test('una sección que falta tampoco pasa', () {
      final json = configJson()..remove('seguridad');

      expect(() => ConfigPublica.desdeJson(json), throwsFormatException);
    });

    test('un número escrito como texto se acepta; una hora mal escrita no', () {
      expect(
        configDePrueba(agenda: {'horasMinimasCambio': '24'})
            .agenda
            .horasMinimasCambio,
        24,
      );
      expect(
        () => configDePrueba(agenda: {'horaInicioTarde': '25:00'}),
        throwsFormatException,
      );
      expect(
        () => configDePrueba(agenda: {'pasoMinutos': 0}),
        throwsFormatException,
      );
      expect(
        () => configDePrueba(agenda: {'recordatoriosActivos': 'sí'}),
        throwsFormatException,
      );
    });

    test('las horas de soporte por severidad: un objeto de enteros desde 1',
        () {
      expect(
        configDePrueba(
          general: {
            'soporteHorasSla': {'CRITICA': '6', 'BAJA': 200},
          },
        ).general.soporteHorasSla,
        {'CRITICA': 6, 'BAJA': 200},
      );
      expect(
        () => configDePrueba(general: {'soporteHorasSla': <String, int>{}}),
        throwsFormatException,
      );
      expect(
        () => configDePrueba(general: {'soporteHorasSla': 72}),
        throwsFormatException,
      );
      expect(
        () => configDePrueba(
          general: {
            'soporteHorasSla': {'ALTA': 0},
          },
        ),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('general.soporteHorasSla.ALTA'),
          ),
        ),
      );
    });

    test('los días de gestación salen de la sección clínica', () {
      expect(
        configDePrueba(clinico: {'diasGestacion': 283}).clinico.diasGestacion,
        283,
      );

      final json = configJson()..remove('clinico');
      expect(() => ConfigPublica.desdeJson(json), throwsFormatException);
    });

    test('los colores de marca son opcionales: si no son un color, no hay', () {
      expect(configDePrueba().clinica.colorPrimario, isNull);
      expect(
        configDePrueba(clinica: {'colorPrimario': '#1A2B3C'})
            .clinica
            .colorPrimario,
        '#1A2B3C',
      );
      expect(
        configDePrueba(clinica: {'colorAcento': 'rojo'}).clinica.colorAcento,
        isNull,
      );
    });
  });

  group('El cubit', () {
    test('enseña primero la copia y luego la del servidor', () async {
      await servicio().cargar();
      respuesta = configJson(clinica: {'nombre': 'Clínica Renovada'});

      final cubit = ConfigPublicaCubit(servicio());
      final estados = <ConfigPublicaState>[];
      final sub = cubit.stream.listen(estados.add);

      await cubit.cargar();
      await sub.cancel();

      expect(estados.first.config?.clinica.nombre, 'Clínica Andina');
      expect(estados.first.desdeCache, isTrue);
      expect(cubit.state.config?.clinica.nombre, 'Clínica Renovada');
      expect(cubit.state.desdeCache, isFalse);
      expect(cubit.state.error, isNull);

      await cubit.close();
    });

    test(
      'sin red y sin copia: error con su mensaje, sin configuración',
      () async {
        hayRed = false;
        final cubit = ConfigPublicaCubit(servicio());

        await cubit.cargar();

        expect(cubit.state.config, isNull);
        expect(cubit.state.error, mensajeSinConfiguracion);
        expect(() => cubit.config, throwsStateError);

        await cubit.close();
      },
    );

    test('sin red pero con copia: la copia, sin error', () async {
      await servicio().cargar();
      hayRed = false;
      final cubit = ConfigPublicaCubit(servicio());

      await cubit.cargar();

      expect(cubit.state.config, isNotNull);
      expect(cubit.state.desdeCache, isTrue);
      expect(cubit.state.error, isNull);

      await cubit.close();
    });

    test('cada configuración que entra se aplica (la zona horaria)', () async {
      final aplicadas = <ConfigPublica>[];
      final cubit = ConfigPublicaCubit(servicio(), alAplicar: aplicadas.add);

      await cubit.cargar();

      expect(aplicadas.single.clinica.zonaHoraria, 'America/Guayaquil');

      await cubit.close();
    });

    test('dos cargas seguidas comparten la petición', () async {
      final cubit = ConfigPublicaCubit(servicio());

      await Future.wait([cubit.cargar(), cubit.cargar()]);

      expect(api.claves, ['GET /configuracion/publica']);

      await cubit.close();
    });
  });

  group('La zona horaria de la configuración', () {
    tearDown(() => ZonaClinica.aplicar('America/Guayaquil'));

    test('Guayaquil: UTC−5, y el reloj de la clínica la usa', () {
      expect(ZonaClinica.aplicar('America/Guayaquil'), isTrue);
      expect(
        ZonaClinica.desfaseEn(DateTime.utc(2026, 9, 28, 14)),
        const Duration(hours: -5),
      );
      expect(
        enHoraDeLaClinica(DateTime.utc(2026, 9, 28, 14)),
        DateTime(2026, 9, 28, 9),
      );

      final reloj = RelojClinica.fijo(DateTime(2026, 9, 28, 9, 30));
      expect(reloj.ahora(), DateTime(2026, 9, 28, 9, 30));
      expect(reloj.instante(), DateTime.utc(2026, 9, 28, 14, 30));
    });

    test('otra zona, otro desfase (con horario de verano)', () {
      expect(ZonaClinica.aplicar('America/Bogota'), isTrue);
      expect(
        ZonaClinica.desfaseEn(DateTime.utc(2026, 9, 28, 14)),
        const Duration(hours: -5),
      );

      expect(ZonaClinica.aplicar('Europe/Madrid'), isTrue);
      expect(
        ZonaClinica.desfaseEn(DateTime.utc(2026, 7, 1, 12)),
        const Duration(hours: 2),
      );
      expect(
        ZonaClinica.desfaseEn(DateTime.utc(2026, 1, 15, 12)),
        const Duration(hours: 1),
      );
    });

    test('un nombre que no existe no cambia la zona en uso', () {
      ZonaClinica.aplicar('America/Guayaquil');

      expect(ZonaClinica.aplicar('Marte/Olympus'), isFalse);
      expect(ZonaClinica.nombre, 'America/Guayaquil');
    });
  });
}
