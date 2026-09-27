// test/avisos_test.dart

import 'dart:async';

import 'package:app_cliniq/core/catalogos/catalogos_cubit.dart';
import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/formato/fechas.dart';
import 'package:app_cliniq/core/network/api_client.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/almacen_claves.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/storage/credenciales_service.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/auth/data/almacen_de_sesion.dart';
import 'package:app_cliniq/features/auth/providers/auth_bloc.dart';
import 'package:app_cliniq/features/auth/providers/auth_state.dart';
import 'package:app_cliniq/features/avisos/data/avisos_service.dart';
import 'package:app_cliniq/features/avisos/presentacion/avisos_page.dart';
import 'package:app_cliniq/features/avisos/providers/avisos_cubit.dart';
import 'package:app_cliniq/features/avisos/providers/campana_cubit.dart';
import 'package:app_cliniq/features/citas/data/citas_service.dart';
import 'package:app_cliniq/features/citas/providers/citas_bloc.dart';
import 'package:app_cliniq/features/consultas/providers/consultas_bloc.dart';
import 'package:app_cliniq/features/dependientes/providers/dependientes_bloc.dart';
import 'package:app_cliniq/features/inicio/presentacion/dashboard_page.dart';
import 'package:app_cliniq/features/navegacion/data/menu_service.dart';
import 'package:app_cliniq/features/navegacion/dominio/destinos.dart';
import 'package:app_cliniq/features/navegacion/presentacion/enrutador.dart';
import 'package:app_cliniq/features/navegacion/providers/menu_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/adaptador_http.dart';
import 'dobles/clinica.dart';
import 'dobles/consultas.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/esperas.dart';

/// La campana: el contador, la lista de avisos y a dónde lleva cada uno.
void main() {
  ZonaClinica.aplicar('America/Guayaquil');

  late CacheLocal cache;
  late bool hayRed;
  late int noLeidos;
  late List<Map<String, dynamic>> avisos;
  late DioGrabador api;

  Map<String, dynamic> aviso(
    String id, {
    String tipo = 'CITA_REPROGRAMADA',
    String titulo = 'Cita reprogramada',
    String? enlace = '/mis-citas',
    bool leida = false,
    Duration hace = const Duration(minutes: 5),
  }) => {
    '_id': id,
    'usuarioId': 'u1',
    'tipo': tipo,
    'titulo': titulo,
    'mensaje': 'Tu cita ahora es el lunes 28 de septiembre, 10:00.',
    'enlace': ?enlace,
    'leida': leida,
    'creadaEn': DateTime.now().toUtc().subtract(hace).toIso8601String(),
  };

  setUp(() {
    cache = CacheEnMemoria();
    hayRed = true;
    noLeidos = 3;
    avisos = [
      aviso('a1'),
      aviso(
        'a2',
        tipo: 'SOPORTE',
        titulo: 'Soporte respondió tu ticket',
        enlace: '/admin/tickets/t1',
        hace: const Duration(hours: 3),
      ),
      aviso(
        'a3',
        tipo: 'ARCO',
        titulo: 'Recibimos tu solicitud ARCO',
        enlace: '/portal/arco',
        leida: true,
        hace: const Duration(days: 2),
      ),
    ];
    api = DioGrabador({
      'GET /notificaciones': (pedido) {
        if (!hayRed) throw errorDeRed();
        final antesDe = pedido.queryParameters['antesDe'];
        if (antesDe != null) {
          return {
            'items': [aviso('a4', leida: true, hace: const Duration(days: 20))],
            'hayMas': false,
          };
        }
        return {'items': avisos, 'hayMas': true};
      },
      'GET /notificaciones/no-leidas/contador': (_) {
        if (!hayRed) throw errorDeRed();
        return {'total': noLeidos};
      },
      'PATCH /notificaciones/a1/leida': (_) => aviso('a1', leida: true),
      'PATCH /notificaciones/a2/leida': (_) => aviso('a2', leida: true),
      'PATCH /notificaciones/leer-todas': (_) => {'actualizadas': 2},
      'DELETE /notificaciones/a1': (_) {
        if (!hayRed) throw errorDeRed();
        return {'message': 'Notificación eliminada', '_id': 'a1'};
      },
    });
  });

  AvisosService servicio() => AvisosService(api.dio, cache);

  group('El servicio', () {
    test('GET /notificaciones: 20 por página, los más nuevos primero, y '
        'guarda la copia de la persona', () async {
      final pagina = await servicio().listar('u1');

      expect(api.ultimo('GET /notificaciones').queryParameters, {'limite': 20});
      expect(pagina.avisos.map((a) => a.id), ['a1', 'a2', 'a3']);
      expect(pagina.avisos.first.enlace, '/mis-citas');
      expect(pagina.avisos.last.leida, isTrue);
      expect(pagina.hayMas, isTrue);
      expect(await cache.leer(AvisosService.claveCache('u1')), hasLength(3));
    });

    test('sin red, la última copia; sin copia, el error', () async {
      await servicio().listar('u1');
      hayRed = false;

      final copia = await servicio().listar('u1');
      expect(copia.desdeCache, isTrue);
      expect(copia.avisos, hasLength(3));

      await cache.vaciarDatosPersonales();
      await expectLater(servicio().listar('u1'), throwsA(anything));
    });

    test('la página siguiente pide antesDe y no toca la copia', () async {
      final primera = await servicio().listar('u1');
      final siguiente = await servicio().listar(
        'u1',
        antesDe: primera.avisos.last.creadaEn,
      );

      final pedido = api.ultimo('GET /notificaciones');
      expect(
        pedido.queryParameters['antesDe'],
        primera.avisos.last.creadaEn.toIso8601String(),
      );
      expect(siguiente.avisos.single.id, 'a4');
      expect(await cache.leer(AvisosService.claveCache('u1')), hasLength(3));
    });

    test('el contador, marcar, leer todos y borrar', () async {
      expect(await servicio().contarNoLeidas(), 3);

      await servicio().marcarLeido('a1');
      await servicio().leerTodos();
      await servicio().eliminar('a1');

      expect(api.claves, [
        'GET /notificaciones/no-leidas/contador',
        'PATCH /notificaciones/a1/leida',
        'PATCH /notificaciones/leer-todas',
        'DELETE /notificaciones/a1',
      ]);
    });
  });

  group('Cuándo', () {
    test('como en el panel, en la hora de la clínica', () {
      // Las 10:00 de la clínica son las 15:00 UTC.
      final ahora = DateTime(2026, 9, 28, 10);
      DateTime utc(int d, int h, [int m = 0]) => DateTime.utc(2026, 9, d, h, m);

      expect(tiempoRelativo(utc(28, 14, 59), ahora), 'hace 1 min');
      expect(tiempoRelativo(utc(28, 15), ahora), 'hace un momento');
      expect(tiempoRelativo(utc(28, 14, 40), ahora), 'hace 20 min');
      expect(tiempoRelativo(utc(28, 12), ahora), 'hace 3 h');
      // 02:00 UTC del 28 son las 21:00 del 27 en la clínica: ayer.
      expect(tiempoRelativo(utc(28, 2), ahora), 'ayer');
      expect(tiempoRelativo(utc(25, 15), ahora), 'hace 3 días');
      expect(tiempoRelativo(utc(10, 15), ahora), '10 sep');
      expect(
        tiempoRelativo(DateTime.utc(2025, 12, 1, 15), ahora),
        '1 dic 2025',
      );
    });
  });

  group('La campana', () {
    late StreamController<void> latidos;

    setUp(() => latidos = StreamController<void>.broadcast());
    tearDown(() => latidos.close());

    CampanaCubit campana() =>
        CampanaCubit(servicio(), latidos: () => latidos.stream);

    test('apagada no pregunta nada', () async {
      final cubit = campana();

      await cubit.refrescar();
      cubit.reanudar();
      latidos.add(null);
      await pumpEventQueue();

      expect(api.claves, isEmpty);
      await cubit.close();
    });

    test('encendida pregunta ya y en cada latido; en segundo plano, '
        'no', () async {
      final cubit = campana()..activar(true);
      await cubit.stream.firstWhere((s) => s.noLeidos == 3);

      noLeidos = 5;
      latidos.add(null);
      await cubit.stream.firstWhere((s) => s.noLeidos == 5);

      cubit.pausar();
      noLeidos = 8;
      latidos.add(null);
      await pumpEventQueue();
      expect(cubit.state.noLeidos, 5);

      // Al volver a primer plano, pregunta enseguida.
      cubit.reanudar();
      await cubit.stream.firstWhere((s) => s.noLeidos == 8);

      await cubit.close();
    });

    test('sin red se queda el último número; apagarla lo olvida', () async {
      final cubit = campana()..activar(true);
      await cubit.stream.firstWhere((s) => s.noLeidos == 3);

      hayRed = false;
      await cubit.refrescar();
      expect(cubit.state, const CampanaState(activa: true, noLeidos: 3));

      cubit
        ..descontar()
        ..descontar(5);
      expect(cubit.state.noLeidos, 0);

      cubit.activar(false);
      expect(cubit.state, const CampanaState());

      hayRed = true;
      latidos.add(null);
      await pumpEventQueue();
      expect(cubit.state, const CampanaState());

      await cubit.close();
    });
  });

  group('La lista', () {
    test('marcar leído descuenta de la campana; leer todos la pone en '
        'cero', () async {
      final latidos = StreamController<void>.broadcast();
      addTearDown(latidos.close);
      final campana = CampanaCubit(servicio(), latidos: () => latidos.stream)
        ..activar(true);
      await campana.stream.firstWhere((s) => s.noLeidos == 3);

      final cubit = AvisosCubit(servicio(), uid: 'u1', campana: campana);
      await cubit.cargar();

      await cubit.marcarLeido(cubit.state.avisos.first);
      expect(cubit.state.avisos.first.leida, isTrue);
      expect(campana.state.noLeidos, 2);
      expect(api.claves, contains('PATCH /notificaciones/a1/leida'));

      await cubit.leerTodos();
      expect(cubit.state.hayNoLeidos, isFalse);
      expect(campana.state.noLeidos, 0);

      // La copia se ve como la lista.
      final copia = await cache.leer(AvisosService.claveCache('u1')) as List;
      expect(copia.every((a) => a['leida'] == true), isTrue);

      await cubit.close();
      await campana.close();
    });

    test('borrar lo quita; si el servidor no lo borra, vuelve', () async {
      final cubit = AvisosCubit(servicio(), uid: 'u1');
      await cubit.cargar();

      hayRed = false;
      expect(await cubit.eliminar(cubit.state.avisos.first), isFalse);
      expect(cubit.state.avisos.map((a) => a.id), ['a1', 'a2', 'a3']);

      hayRed = true;
      expect(await cubit.eliminar(cubit.state.avisos.first), isTrue);
      expect(cubit.state.avisos.map((a) => a.id), ['a2', 'a3']);

      await cubit.close();
    });

    test('ver más trae los anteriores', () async {
      final cubit = AvisosCubit(servicio(), uid: 'u1');
      await cubit.cargar();

      await cubit.cargarMas();

      expect(cubit.state.avisos.map((a) => a.id), ['a1', 'a2', 'a3', 'a4']);
      expect(cubit.state.hayMas, isFalse);
      await cubit.close();
    });
  });

  group('La pantalla', () {
    late List<DestinoNativo> abiertos;
    late CampanaCubit campana;

    setUp(() {
      sondeoConRed();
      abiertos = [];
    });

    Future<void> montar(WidgetTester tester) async {
      final llavero = AlmacenClavesEnMemoria();
      final auth = AuthBloc(
        servicio: AuthServiceFalso(),
        almacen: AlmacenDeSesion(llavero),
        credenciales: CredencialesService(llavero),
        fijarToken: (_) {},
        restaurarAlCrear: false,
      )..emit(AuthAutenticado(usuarioDePrueba()));
      addTearDown(auth.close);

      campana = CampanaCubit(servicio(), latidos: () => const Stream.empty())
        ..activar(true);
      addTearDown(campana.close);

      await tester.pumpWidget(
        conDatosDeLaClinica(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: auth),
              BlocProvider.value(value: campana),
            ],
            child: MaterialApp(
              theme: temaCliniq(),
              home: AlcanceDeNavegacion(
                abrir: (destino, {titulo}) => abiertos.add(destino),
                campana: null,
                child: AvisosPage(servicio: servicio()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('la lista, con la fecha relativa y los sin leer', (
      tester,
    ) async {
      await montar(tester);

      expect(find.text('Avisos'), findsOneWidget);
      expect(find.text('Cita reprogramada'), findsOneWidget);
      expect(find.text('Hace 5 min'), findsOneWidget);
      expect(find.text('Hace 3 h'), findsOneWidget);
      expect(find.text('Hace 2 días'), findsOneWidget);
      expect(find.text('Marcar todas como leídas'), findsOneWidget);
      expect(campana.state.noLeidos, 3);
    });

    testWidgets('al tocar un aviso queda leído y se abre su pantalla con el '
        'enrutador', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Cita reprogramada'));
      await tester.pumpAndSettle();

      expect(abiertos, [const DestinoNativo(PantallaNativa.citas)]);
      expect(api.claves, contains('PATCH /notificaciones/a1/leida'));
      expect(campana.state.noLeidos, 2);
    });

    testWidgets('si su enlace no es del paciente, se queda en la lista', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(find.text('Soporte respondió tu ticket'));
      await tester.pumpAndSettle();

      expect(abiertos, isEmpty);
      expect(
        find.text('Este aviso no tiene más detalles en la aplicación.'),
        findsOneWidget,
      );
      expect(find.byType(AvisosPage), findsOneWidget);
    });

    testWidgets('«Marcar todas como leídas» y deslizar para borrar', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(find.byKey(const Key('leer-todos')));
      await tester.pumpAndSettle();
      expect(api.claves, contains('PATCH /notificaciones/leer-todas'));
      expect(find.byKey(const Key('leer-todos')), findsNothing);
      expect(campana.state.noLeidos, 0);

      await tester.drag(
        find.byKey(const Key('aviso-a1')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();

      // El borrado sale al servidor al terminar la animación.
      await esperarHasta(
        tester,
        () => api.claves.contains('DELETE /notificaciones/a1'),
      );
      expect(find.text('Cita reprogramada'), findsNothing);
    });

    testWidgets('sin avisos, un vacío amable', (tester) async {
      avisos = [];
      await montar(tester);

      expect(find.byKey(const Key('avisos-vacio')), findsOneWidget);
      expect(find.text('Todo al día'), findsOneWidget);
    });

    testWidgets('sin red ni copia, el error con «Reintentar»', (tester) async {
      hayRed = false;
      await montar(tester);

      expect(find.text('No pudimos cargar esto'), findsOneWidget);

      hayRed = true;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Cita reprogramada'), findsOneWidget);
    });
  });

  group('En el tablero', () {
    late List<Map<String, dynamic>> menu;

    setUp(() {
      sondeoConRed();
      menu = menuJson();
      api.rutas['GET /menus/mi-menu'] = (_) => menu;
      api.rutas['GET /agenda/paciente/mis-citas'] = (_) => <Object?>[];
      api.rutas['GET /portal/dependientes'] = (_) => <Object?>[];

      // La lista que abre la campana usa el servicio de la aplicación: su
      // API y su caché, de mentira.
      Servicios.cacheParaPruebas = CacheEnMemoria();
      ApiClient().dio.httpClientAdapter = AdaptadorHttpFalso({
        'GET /notificaciones': (_) =>
            (estado: 200, cuerpo: {'items': avisos, 'hayMas': false}),
        'GET /notificaciones/no-leidas/contador': (_) =>
            (estado: 200, cuerpo: {'total': noLeidos}),
        'PATCH /notificaciones/a1/leida': (_) =>
            (estado: 200, cuerpo: aviso('a1', leida: true)),
      });
    });

    Future<void> montar(WidgetTester tester) async {
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
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: auth),
              BlocProvider(
                create: (_) => MenuCubit(MenuService(api.dio, cache)),
              ),
              BlocProvider(
                create: (context) => CitasBloc(
                  citas: CitasService(api.dio, CacheEnMemoria()),
                  portal: PortalFalso(),
                  recordatorios: ProgramadorFalso(),
                  config: configDePrueba,
                  catalogos: () => context.read<CatalogosCubit>().state,
                ),
              ),
              BlocProvider(create: (_) => ConsultasBloc(ConsultasFalso())),
              BlocProvider(
                create: (_) => DependientesBloc(DependientesFalso()),
              ),
              BlocProvider(
                create: (_) => CampanaCubit(
                  servicio(),
                  latidos: () => const Stream.empty(),
                ),
              ),
            ],
            child: MaterialApp(
              theme: temaCliniq(),
              home: const DashboardPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sin el enlace en el menú no hay campana ni se pregunta', (
      tester,
    ) async {
      await montar(tester);

      expect(find.byKey(const Key('boton-campana')), findsNothing);
      expect(
        api.claves.where((c) => c.startsWith('GET /notificaciones')),
        isEmpty,
      );
    });

    testWidgets('con el enlace, la campana en la cabecera con los sin leer; '
        'no va en la barra ni en los accesos, y abre los avisos', (
      tester,
    ) async {
      (menu.first['children'] as List).add({
        'key': 'notificaciones',
        'label': 'Avisos',
        'icon': 'campana',
        'route': '/notificaciones',
        'tipo': 'LINK',
        'orden': 1,
      });
      await montar(tester);

      expect(find.byKey(const Key('boton-campana')), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byTooltip('Avisos: 3 sin leer'), findsOneWidget);
      expect(find.byKey(const Key('pestana-notificaciones')), findsNothing);
      expect(find.byKey(const Key('acceso-notificaciones')), findsNothing);

      await tester.tap(find.byKey(const Key('boton-campana')));
      await tester.pumpAndSettle();

      expect(find.byType(AvisosPage), findsOneWidget);
      expect(find.text('Cita reprogramada'), findsOneWidget);

      // Desde un aviso a una pestaña: se cierra la lista y se ve la pestaña.
      await tester.tap(find.text('Cita reprogramada'));
      await tester.pumpAndSettle();

      expect(find.byType(AvisosPage), findsNothing);
      // La segunda pestaña (tras el inicio) es «Mis citas».
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 1);
    });
  });
}
