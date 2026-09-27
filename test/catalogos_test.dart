// test/catalogos_test.dart

import 'package:app_cliniq/core/catalogos/catalogo_service.dart';
import 'package:app_cliniq/core/catalogos/catalogos_cubit.dart';
import 'package:app_cliniq/core/configuracion/config_publica_cubit.dart';
import 'package:app_cliniq/core/configuracion/config_publica_service.dart';
import 'package:app_cliniq/core/network/api_interceptor.dart';
import 'package:app_cliniq/core/presentacion/visual_del_servidor.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/arranque/presentacion/espera_datos_clinica.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';

/// Los catálogos: completos, públicos, con copia y sin listas de respaldo.
void main() {
  late CacheLocal cache;
  late bool hayRed;
  late Map<String, Object?> lote;
  late DioGrabador api;

  setUp(() {
    cache = CacheEnMemoria();
    hayRed = true;
    lote = catalogosJson();
    api = DioGrabador({
      'GET /catalogos/lote': (_) {
        if (!hayRed) throw errorDeRed();
        return lote;
      },
    });
  });

  CatalogoService servicio() => CatalogoService(api.dio, cache);

  group('El servicio', () {
    test('pide todas las claves de una vez, sin token', () async {
      await servicio().cargar();

      final pedido = api.ultimo('GET /catalogos/lote');
      expect(pedido.queryParameters['keys'], Catalogos.todos.join(','));
      expect(pedido.extra[rutaPublica], isTrue);
      expect(
        Catalogos.todos,
        containsAll([
          'ESPECIALIDAD',
          'MOTIVO_CANCELACION_PACIENTE',
          'PARENTESCO_DEPENDIENTE',
          'MODALIDAD_CITA',
          'PREPARACION_CITA',
          'CIUDAD',
          'SEXO',
          'TIPO_DOCUMENTO',
          'TIPO_SANGRE',
          'ESTADO_CITA',
          'ESTADO_CONSULTA',
        ]),
      );
    });

    test('conserva el elemento completo', () async {
      final cargados = await servicio().cargar();
      final telemedicina = cargados.listas[Catalogos.modalidadCita]![1];

      expect(telemedicina.codigo, 'TELEMEDICINA');
      expect(telemedicina.nombre, 'Telemedicina');
      expect(telemedicina.descripcion, 'Videollamada en vivo');
      expect(telemedicina.color, '#7a5cc7');
      expect(telemedicina.icono, 'video');
      expect(telemedicina.orden, 1);
      expect(
        cargados.listas[Catalogos.especialidad]!.first.esPorDefecto,
        isTrue,
      );
    });

    test(
      'lo que responde el servidor manda, aunque sea una lista vacía',
      () async {
        await servicio().cargar();

        lote = {...catalogosJson(), Catalogos.motivoCancelacionPaciente: []};
        final cargados = await servicio().cargar();

        expect(cargados.listas[Catalogos.motivoCancelacionPaciente], isEmpty);
        expect(cargados.desdeCache, isEmpty);
      },
    );

    test('sin red: la última copia de cada catálogo', () async {
      await servicio().cargar();
      hayRed = false;

      final cargados = await servicio().cargar();

      expect(cargados.desdeCache, Catalogos.todos.toSet());
      expect(cargados.faltantes, isEmpty);
      expect(cargados.listas[Catalogos.sexo]!.map((i) => i.nombre), [
        'Femenino',
        'Masculino',
        'Otro',
      ]);
    });

    test('un catálogo que no vino en la respuesta sale de la copia', () async {
      await servicio().cargar();
      lote = {...catalogosJson()}..remove(Catalogos.ciudad);

      final cargados = await servicio().cargar();

      expect(cargados.desdeCache, {Catalogos.ciudad});
      expect(cargados.listas[Catalogos.ciudad], isNotEmpty);
    });

    test(
      'sin red y sin copia: faltan, y no se inventa ninguna opción',
      () async {
        hayRed = false;

        final cargados = await servicio().cargar();

        expect(cargados.listas, isEmpty);
        expect(cargados.faltantes, Catalogos.todos.toSet());
      },
    );

    test('la copia vieja (solo nombres) no se usa', () async {
      await cache.guardar('catalogos:lote', {
        'MOTIVO_CANCELACION': ['Otro motivo'],
      });
      hayRed = false;

      final cargados = await servicio().cargar();

      expect(cargados.listas, isEmpty);
    });

    test('la copia es de la clínica: sobrevive al cierre de sesión', () async {
      await servicio().cargar();
      await cache.vaciarDatosPersonales();
      hayRed = false;

      expect((await servicio().cargar()).faltantes, isEmpty);
    });
  });

  group('El estado', () {
    final estado = catalogosDePrueba();

    test('etiquetas por código, el predeterminado y las listas de nombres', () {
      expect(estado.completos, isTrue);
      expect(estado.error, isNull);
      expect(estado.nombreDe(Catalogos.sexo, 'f'), 'Femenino');
      expect(
        estado.nombreDe(Catalogos.tipoDocumento, 'PASAPORTE'),
        'Pasaporte',
      );
      expect(estado.nombreDe(Catalogos.sexo, 'X'), isNull);
      expect(
        estado.porDefecto(Catalogos.especialidad)?.nombre,
        'Medicina General',
      );
      expect(estado.motivosCancelacion, [
        'No puedo asistir',
        'Ya me siento mejor',
      ]);
      expect(estado.parentescosDependiente, ['Hijo/a', 'Madre', 'Tutor legal']);
    });

    test('si falta alguno, no están completos y hay error', () {
      final incompleto = CatalogosState(
        listas: {Catalogos.sexo: estado.items(Catalogos.sexo)},
        cargados: true,
      );

      expect(incompleto.completos, isFalse);
      expect(incompleto.error, mensajeSinCatalogos);
    });
  });

  group('El cubit', () {
    test('carga todo y queda completo', () async {
      final cubit = CatalogosCubit(servicio());

      await cubit.cargar();

      expect(cubit.state.completos, isTrue);
      expect(cubit.state.faltantes, isEmpty);

      await cubit.close();
    });

    test('un refresco sin red conserva lo que ya tenía', () async {
      final cubit = CatalogosCubit(servicio());
      await cubit.cargar();

      hayRed = false;
      await cache.guardar(CatalogoService.claveCache, null);
      await cubit.cargar();

      expect(cubit.state.completos, isTrue);

      await cubit.close();
    });

    test('sin red y sin copia: el error para ofrecer «Reintentar»', () async {
      hayRed = false;
      final cubit = CatalogosCubit(servicio());

      await cubit.cargar();

      expect(cubit.state.completos, isFalse);
      expect(cubit.state.error, mensajeSinCatalogos);

      await cubit.close();
    });
  });

  group('Iconos y colores del servidor', () {
    test('los nombres del panel tienen su icono; uno desconocido, el '
        'genérico', () {
      expect(iconoDelServidor('video'), Icons.videocam_outlined);
      expect(
        iconoDelServidor('calendario-mas'),
        iconosDelPanel['calendario-mas'],
      );
      expect(iconoDelServidor('uno-que-no-existe'), iconoGenerico);
      expect(iconoDelServidor(''), iconoGenerico);
      expect(iconoDelServidor(null), iconoGenerico);
    });

    test('los colores del panel, o nada si no son un color', () {
      expect(colorDelServidor('#5a6e73'), const Color(0xFF5A6E73));
      expect(colorDelServidor('#fff'), const Color(0xFFFFFFFF));
      expect(colorDelServidor('#805A6E73'), const Color(0x805A6E73));
      expect(colorDelServidor(''), isNull);
      expect(colorDelServidor('azul'), isNull);
    });
  });

  group('Sin datos de la clínica no se entra', () {
    Widget app({
      required ConfigPublicaCubit config,
      required CatalogosCubit catalogos,
    }) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: config),
        BlocProvider.value(value: catalogos),
      ],
      child: MaterialApp(
        theme: temaCliniq(),
        home: const EsperaDatosDeLaClinica(child: Text('Dentro')),
      ),
    );

    testWidgets('sin red y sin copia: el aviso con «Reintentar»; al volver la '
        'red, entra', (tester) async {
      var hayRedConfig = false;
      final apiConfig = DioGrabador({
        'GET /configuracion/publica': (_) {
          if (!hayRedConfig) throw errorDeRed();
          return configJson();
        },
      });
      hayRed = false;

      final config = ConfigPublicaCubit(
        ConfigPublicaService(apiConfig.dio, cache),
      );
      final catalogos = CatalogosCubit(servicio());

      await tester.pumpWidget(app(config: config, catalogos: catalogos));
      config.cargar();
      catalogos.cargar();
      // Espera a que las dos cargas terminen (sin red: en error).
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sin-datos-de-la-clinica')), findsOneWidget);
      expect(find.text(mensajeSinConfiguracion), findsOneWidget);
      expect(find.text('Dentro'), findsNothing);

      hayRedConfig = true;
      hayRed = true;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(config.state.lista, isTrue);
      expect(catalogos.state.completos, isTrue);
      expect(find.text('Dentro'), findsOneWidget);

      await config.close();
      await catalogos.close();
    });

    testWidgets('con los datos ya cargados, entra directo', (tester) async {
      await tester.pumpWidget(
        conDatosDeLaClinica(
          MaterialApp(
            theme: temaCliniq(),
            home: const EsperaDatosDeLaClinica(child: Text('Dentro')),
          ),
        ),
      );

      expect(find.text('Dentro'), findsOneWidget);
    });
  });
}
