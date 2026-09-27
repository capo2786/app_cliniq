// test/encuestas_test.dart

import 'package:app_cliniq/core/configuracion/config_publica.dart';
import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/network/api_client.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/almacen_claves.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/storage/credenciales_service.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/auth/data/almacen_de_sesion.dart';
import 'package:app_cliniq/features/auth/providers/auth_bloc.dart';
import 'package:app_cliniq/features/auth/providers/auth_state.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/encuestas/data/encuestas_service.dart';
import 'package:app_cliniq/features/encuestas/presentacion/encuesta_page.dart';
import 'package:app_cliniq/features/encuestas/presentacion/widgets/aviso_encuestas.dart';
import 'package:app_cliniq/features/encuestas/providers/encuesta_cubit.dart';
import 'package:app_cliniq/features/encuestas/providers/encuestas_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/adaptador_http.dart';
import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/tablero.dart';

/// Las encuestas de las citas atendidas: cuáles quedan, la pantalla que las
/// responde y el aviso del inicio.
void main() {
  ZonaClinica.aplicar('America/Guayaquil');

  late CacheLocal cache;
  late bool hayRed;
  late List<Map<String, dynamic>> pendientes;
  late DioGrabador api;
  late Object? Function(Map<dynamic, dynamic> cuerpo) alResponder;

  Map<String, dynamic> pendiente(
    String citaId, {
    String inicio = '2026-09-22T09:00:00.000Z',
    String medico = 'Ana María Torres',
    bool paraDependiente = false,
  }) => {
    'citaId': citaId,
    'start': inicio,
    'end': inicio.replaceFirst(':00:00.000Z', ':30:00.000Z'),
    'type': 'PRESENCIAL',
    'doctorId': 'doc1',
    'doctorName': medico,
    'doctorSpecialty': 'Medicina Familiar',
    'pacienteNombre': paraDependiente ? 'Tomás Pérez' : 'Ana María Pérez',
    'paraDependiente': paraDependiente,
  };

  setUp(() {
    cache = CacheEnMemoria();
    hayRed = true;
    pendientes = [
      pendiente('c1'),
      pendiente(
        'c2',
        inicio: '2026-09-25T15:00:00.000Z',
        medico: 'Luis Mora',
        paraDependiente: true,
      ),
    ];
    alResponder = (cuerpo) => {'_id': 'e1', ...cuerpo};
    api = DioGrabador({
      'GET /portal/encuestas/pendientes': (_) {
        if (!hayRed) throw errorDeRed();
        return pendientes;
      },
      'POST /portal/encuestas': (pedido) => alResponder(pedido.data as Map),
    });
  });

  EncuestasService servicio() => EncuestasService(api.dio, cache);

  group('El servicio', () {
    test('las pendientes se leen como citas atendidas, la más reciente '
        'primero, y se guardan', () async {
      final datos = await servicio().pendientes('u1');

      expect(datos.citas.map((c) => c.id), ['c2', 'c1']);
      final c2 = datos.citas.first;
      expect(c2.estado, EstadoCita.atendida);
      // Hora «congelada» de la clínica, sin mover.
      expect(c2.inicio, DateTime(2026, 9, 25, 15));
      expect(c2.medico, 'Luis Mora');
      expect(c2.paraDependiente, isTrue);
      expect(await cache.leer(EncuestasService.claveCache('u1')), hasLength(2));
    });

    test('sin red, la copia; al cerrar sesión se va', () async {
      await servicio().pendientes('u1');
      hayRed = false;

      final copia = await servicio().pendientes('u1');
      expect(copia.desdeCache, isTrue);
      expect(copia.citas.first.id, 'c2');

      await cache.vaciarDatosPersonales();
      await expectLater(servicio().pendientes('u1'), throwsA(anything));
    });

    test('responder: el comentario sin espacios, y solo si hay', () async {
      await servicio().responder(
        const RespuestaEncuesta(
          citaId: 'c1',
          puntuacion: 5,
          recomendaria: 9,
          comentario: '  Muy amable.  ',
        ),
      );
      expect(api.ultimo('POST /portal/encuestas').data, {
        'citaId': 'c1',
        'puntuacion': 5,
        'recomendaria': 9,
        'comentario': 'Muy amable.',
      });

      await servicio().responder(
        const RespuestaEncuesta(
          citaId: 'c1',
          puntuacion: 3,
          recomendaria: 0,
          comentario: '   ',
        ),
      );
      expect(api.ultimo('POST /portal/encuestas').data, {
        'citaId': 'c1',
        'puntuacion': 3,
        'recomendaria': 0,
      });
    });

    test('409: ya estaba respondida', () async {
      alResponder = (_) =>
          throw errorHttp(409, 'Ya respondiste la encuesta de esta cita.');

      await expectLater(
        servicio().responder(
          const RespuestaEncuesta(citaId: 'c1', puntuacion: 4, recomendaria: 8),
        ),
        throwsA(isA<EncuestaYaRespondida>()),
      );
    });
  });

  group('Las pendientes del inicio', () {
    test('se cargan, y una respondida deja de estar (también en la '
        'copia)', () async {
      final cubit = EncuestasCubit(servicio());
      await cubit.cargar('u1');
      expect(cubit.state.pendientes, hasLength(2));

      cubit.respondida('c2');
      expect(cubit.state.pendientes.single.id, 'c1');

      hayRed = false;
      final copia = await servicio().pendientes('u1');
      expect(copia.citas.single.id, 'c1');

      cubit.vaciar();
      expect(cubit.state.pendientes, isEmpty);
      await cubit.close();
    });

    test('el texto del aviso: con una, a quién y cuándo; con varias, '
        'cuántas', () async {
      final datos = await servicio().pendientes('u1');

      expect(
        textoDelAviso([datos.citas.last]),
        'Cuéntanos cómo te atendió Ana María Torres el 22 de septiembre. '
        'Toma diez segundos.',
      );
      expect(textoDelAviso(datos.citas), contains('Tienes 2 consultas'));
    });
  });

  group('La encuesta', () {
    EncuestaCubit encuesta(String citaId, {EncuestasCubit? inicio}) =>
        EncuestaCubit(
          servicio(),
          citaId: citaId,
          uid: 'u1',
          pendientes: inicio,
        );

    test('una pendiente abre el formulario; otra cita, «no disponible» con '
        'las demás', () async {
      final c1 = encuesta('c1');
      await c1.cargar();
      expect(c1.state.etapa, EtapaEncuesta.formulario);
      expect(c1.state.cita?.medico, 'Ana María Torres');
      expect(c1.state.otras.single.id, 'c2');

      final vieja = encuesta('c9');
      await vieja.cargar();
      expect(vieja.state.etapa, EtapaEncuesta.noDisponible);
      expect(vieja.state.otras, hasLength(2));

      await c1.close();
      await vieja.close();
    });

    test('sin la lista, se responde igual', () async {
      hayRed = false;
      final cubit = encuesta('c1');
      await cubit.cargar();

      expect(cubit.state.etapa, EtapaEncuesta.formulario);
      expect(cubit.state.sinDatosDeLaCita, isTrue);
      await cubit.close();
    });

    test('sin contestar las dos preguntas no se manda', () async {
      final cubit = encuesta('c1');
      await cubit.cargar();

      await cubit.enviar();
      expect(cubit.state.intentado, isTrue);
      expect(cubit.state.puntuacionValida, isFalse);

      cubit.elegirPuntuacion(4);
      await cubit.enviar();
      expect(cubit.state.recomendacionValida, isFalse);
      expect(api.claves, isNot(contains('POST /portal/encuestas')));
      await cubit.close();
    });

    test('enviada: «gracias», y el aviso del inicio la olvida; repetida, '
        '«ya respondiste»', () async {
      final inicio = EncuestasCubit(servicio());
      await inicio.cargar('u1');

      final cubit = encuesta('c1', inicio: inicio);
      await cubit.cargar();
      cubit
        ..elegirPuntuacion(5)
        ..elegirRecomendacion(10);
      await cubit.enviar(comentario: 'Excelente');

      expect(cubit.state.etapa, EtapaEncuesta.gracias);
      expect(inicio.state.pendientes.map((c) => c.id), ['c2']);

      cubit.responderOtra('c2');
      expect(cubit.state.etapa, EtapaEncuesta.formulario);
      expect(cubit.state.cita?.id, 'c2');
      expect(cubit.state.otras, isEmpty);
      expect(cubit.state.puntuacion, 0);

      alResponder = (_) => throw errorHttp(409);
      cubit
        ..elegirPuntuacion(3)
        ..elegirRecomendacion(6);
      await cubit.enviar();
      expect(cubit.state.etapa, EtapaEncuesta.yaRespondida);
      expect(inicio.state.pendientes, isEmpty);

      await cubit.close();
      await inicio.close();
    });

    test('si el servidor dice que no, su mensaje', () async {
      alResponder = (_) => throw errorHttp(400, 'Solo citas atendidas.');
      final cubit = encuesta('c1');
      await cubit.cargar();
      cubit
        ..elegirPuntuacion(2)
        ..elegirRecomendacion(3);

      await cubit.enviar();

      expect(cubit.state.etapa, EtapaEncuesta.formulario);
      expect(cubit.state.error, 'Solo citas atendidas.');
      await cubit.close();
    });
  });

  group('La pantalla', () {
    setUp(sondeoConRed);

    Future<void> montar(
      WidgetTester tester,
      String citaId, {
      ConfigPublica? config,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      final llavero = AlmacenClavesEnMemoria();
      final auth = AuthBloc(
        servicio: AuthServiceFalso(),
        almacen: AlmacenDeSesion(llavero),
        credenciales: CredencialesService(llavero),
        fijarToken: (_) {},
        restaurarAlCrear: false,
      )..emit(AuthAutenticado(usuarioDePrueba()));
      addTearDown(auth.close);

      await tester.pumpWidget(
        conDatosDeLaClinica(
          config: config,
          BlocProvider.value(
            value: auth,
            child: MaterialApp(
              theme: temaCliniq(),
              home: EncuestaPage(citaId: citaId, servicio: servicio()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tocar(WidgetTester tester, Key clave) async {
      await tester.ensureVisible(find.byKey(clave));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(clave));
      await tester.pumpAndSettle();
    }

    testWidgets('la cita, las dos preguntas y el comentario; enviada, '
        '«gracias» y la siguiente', (tester) async {
      await montar(tester, 'c2');

      expect(
        find.textContaining('Luis Mora · Medicina Familiar'),
        findsOneWidget,
      );
      expect(find.text('Cita de Tomás Pérez'), findsOneWidget);
      expect(find.text('Presencial'), findsOneWidget);
      expect(find.textContaining('recomiendes a Luis Mora'), findsOneWidget);

      // Sin contestar, dice qué falta.
      await tocar(tester, const Key('enviar-encuesta'));
      expect(find.text('Elige de 1 a 5 estrellas.'), findsOneWidget);
      expect(find.text('Elige un número del 0 al 10.'), findsOneWidget);

      await tocar(tester, const Key('estrella-4'));
      expect(find.text('Buena'), findsOneWidget);
      await tocar(tester, const Key('recomendacion-9'));
      await tester.enterText(
        find.byKey(const Key('campo-comentario-encuesta')),
        'Muy puntual.',
      );
      await tocar(tester, const Key('enviar-encuesta'));

      expect(api.ultimo('POST /portal/encuestas').data, {
        'citaId': 'c2',
        'puntuacion': 4,
        'recomendaria': 9,
        'comentario': 'Muy puntual.',
      });
      expect(find.byKey(const Key('encuesta-gracias')), findsOneWidget);

      await tocar(tester, const Key('siguiente-encuesta'));
      expect(
        find.textContaining('recomiendes a Ana María Torres'),
        findsOneWidget,
      );
      expect(find.text('Muy puntual.'), findsNothing);
    });

    testWidgets('una que ya no está: cuántos días dura, de la configuración', (
      tester,
    ) async {
      await montar(
        tester,
        'c9',
        config: configDePrueba(general: {'encuestasDiasVentana': 45}),
      );

      expect(find.byKey(const Key('encuesta-no-disponible')), findsOneWidget);
      expect(find.textContaining('más de 45 días'), findsOneWidget);
      expect(find.byKey(const Key('siguiente-encuesta')), findsOneWidget);
    });
  });

  group('El aviso del inicio', () {
    setUp(() {
      sondeoConRed();
      api.rutas['GET /menus/mi-menu'] = (_) => menuJson();
      api.rutas['GET /agenda/paciente/mis-citas'] = (_) => <Object?>[];
      api.rutas['GET /portal/dependientes'] = (_) => <Object?>[];

      // La encuesta que abre el aviso usa el servicio de la aplicación: su
      // API y su caché, de mentira.
      Servicios.cacheParaPruebas = CacheEnMemoria();
      ApiClient().dio.httpClientAdapter = AdaptadorHttpFalso({
        'GET /portal/encuestas/pendientes': (_) =>
            (estado: 200, cuerpo: pendientes),
      });
    });

    testWidgets('con pendientes, el aviso abre la encuesta de la más '
        'reciente', (tester) async {
      await montarTablero(tester, dio: api.dio, cache: cache);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('aviso-encuestas')), findsOneWidget);
      expect(find.textContaining('Tienes 2 consultas'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('aviso-encuestas')));
      await tester.tap(find.byKey(const Key('aviso-encuestas')));
      await tester.pumpAndSettle();

      expect(find.byType(EncuestaPage), findsOneWidget);
      expect(find.textContaining('recomiendes a Luis Mora'), findsOneWidget);
    });

    testWidgets('sin pendientes, no hay aviso', (tester) async {
      pendientes = [];
      await montarTablero(tester, dio: api.dio, cache: cache);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('aviso-encuestas')), findsNothing);
    });
  });
}
