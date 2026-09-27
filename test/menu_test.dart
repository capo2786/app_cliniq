// test/menu_test.dart

import 'package:app_cliniq/core/catalogos/catalogos_cubit.dart';
import 'package:app_cliniq/core/storage/almacen_claves.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/storage/credenciales_service.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/auth/data/almacen_de_sesion.dart';
import 'package:app_cliniq/features/auth/data/models/usuario.dart';
import 'package:app_cliniq/features/auth/providers/auth_bloc.dart';
import 'package:app_cliniq/features/auth/providers/auth_state.dart';
import 'package:app_cliniq/features/citas/data/citas_service.dart';
import 'package:app_cliniq/features/citas/providers/citas_bloc.dart';
import 'package:app_cliniq/features/consultas/presentacion/consultas_page.dart';
import 'package:app_cliniq/features/consultas/providers/consultas_bloc.dart';
import 'package:app_cliniq/features/dependientes/presentacion/dependientes_page.dart';
import 'package:app_cliniq/features/dependientes/providers/dependientes_bloc.dart';
import 'package:app_cliniq/features/inicio/presentacion/dashboard_page.dart';
import 'package:app_cliniq/features/navegacion/data/menu_service.dart';
import 'package:app_cliniq/features/navegacion/dominio/destinos.dart';
import 'package:app_cliniq/features/navegacion/providers/menu_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/consultas.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/navegador_falso.dart';

/// La navegación sale del menú del servidor: la barra, los accesos rápidos,
/// y qué abre cada enlace.
void main() {
  late CacheLocal cache;
  late bool hayRed;
  late List<Map<String, dynamic>> menu;
  late DioGrabador api;

  setUp(() {
    cache = CacheEnMemoria();
    hayRed = true;
    menu = menuJson();
    api = DioGrabador({
      'GET /menus/mi-menu': (_) {
        if (!hayRed) throw errorDeRed();
        return menu;
      },
    });
  });

  MenuService servicio() => MenuService(api.dio, cache);

  group('El servicio', () {
    test('pide el menú de la aplicación y lo aplana por orden', () async {
      final cargado = await servicio().cargar('u1');

      final pedido = api.ultimo('GET /menus/mi-menu');
      expect(pedido.queryParameters, {'plataforma': 'APP'});
      expect(cargado.desdeCache, isFalse);
      expect(cargado.enlaces.map((e) => e.key), [
        'inicio',
        'mis-citas',
        'agendar-cita',
        'mis-dependientes',
        'mi-salud',
        'consultas-en-linea',
        'centro-ayuda',
      ]);
      expect(cargado.enlaces[1].label, 'Mis citas');
      expect(cargado.enlaces[1].icon, 'calendario');
      expect(cargado.enlaces[1].color, '#5ab8ea');
    });

    test('guarda la copia de esa persona y, sin red, la usa', () async {
      await servicio().cargar('u1');
      hayRed = false;

      final cargado = await servicio().cargar('u1');

      expect(cargado.desdeCache, isTrue);
      expect(cargado.enlaces, hasLength(7));
    });

    test('la copia es de la persona: se va al cerrar sesión', () async {
      await servicio().cargar('u1');
      await cache.vaciarDatosPersonales();
      hayRed = false;

      await expectLater(
        servicio().cargar('u1'),
        throwsA(isA<MenuNoDisponible>()),
      );
    });

    test('sin red y sin copia: no hay menú (ninguno de respaldo)', () async {
      hayRed = false;

      await expectLater(
        servicio().cargar('u1'),
        throwsA(isA<MenuNoDisponible>()),
      );
    });

    test('los grupos no son enlaces; un enlace sin ruta se descarta', () {
      final enlaces = enlacesDelMenu([
        {
          'tipo': 'GRUPO',
          'label': 'Grupo',
          'children': [
            {'tipo': 'LINK', 'label': 'Sin ruta', 'route': ''},
            {'tipo': 'EXTERNO', 'label': 'Web', 'route': 'https://x.ec'},
          ],
        },
      ]);

      expect(enlaces.single.label, 'Web');
      expect(enlaces.single.externo, isTrue);
    });
  });

  group('A dónde lleva cada enlace', () {
    EnlaceMenu enlace(String ruta, {String tipo = 'LINK'}) =>
        EnlaceMenu(key: 'k', label: 'X', route: ruta, tipo: tipo);

    test('una ruta conocida abre su pantalla', () {
      expect(
        destinoDe(enlace('/inicio')),
        const DestinoNativo(PantallaNativa.inicio),
      );
      expect(
        destinoDe(enlace('/mis-citas')),
        const DestinoNativo(PantallaNativa.citas),
      );
      expect(
        destinoDe(enlace('/portal/agendar')),
        const DestinoNativo(PantallaNativa.agendar),
      );
      expect(
        destinoDe(enlace('/portal/dependientes/')),
        const DestinoNativo(PantallaNativa.dependientes),
      );
      expect(
        destinoDe(enlace('/portal/consultas')),
        const DestinoNativo(PantallaNativa.consultas),
      );
    });

    test('una desconocida se abre en el panel web, en el navegador', () {
      expect(
        destinoDe(enlace('/mi-salud')),
        const DestinoWeb('https://cliniq.gcaicedo-proyectos.com/mi-salud'),
      );
    });

    test('un enlace externo se abre tal cual', () {
      expect(
        destinoDe(enlace('https://blog.andina.ec', tipo: 'EXTERNO')),
        const DestinoWeb('https://blog.andina.ec'),
      );
    });

    test('la barra: los 4 primeros; los demás, accesos rápidos; el perfil '
        'no se repite', () {
      final enlaces = [enlace('/perfil'), ...enlacesDelMenu(menuJson())];

      final navegacion = NavegacionDeLaApp.desde(enlaces);

      expect(navegacion.barra.map((e) => e.route), [
        '/inicio',
        '/mis-citas',
        '/portal/agendar',
        '/portal/dependientes',
      ]);
      expect(navegacion.accesos.map((e) => e.route), [
        '/mi-salud',
        '/portal/consultas',
        '/ayuda',
      ]);
    });
  });

  group('El cubit', () {
    test('carga, y sin red conserva lo que ya tenía', () async {
      final cubit = MenuCubit(servicio());
      await cubit.cargar('u1');
      expect(cubit.state.enlaces, hasLength(7));

      hayRed = false;
      await cache.vaciarDatosPersonales();
      await cubit.cargar('u1');

      expect(cubit.state.enlaces, hasLength(7));
      expect(cubit.state.error, isNull);

      await cubit.close();
    });

    test('sin red y sin copia: el error para ofrecer «Reintentar»', () async {
      hayRed = false;
      final cubit = MenuCubit(servicio());

      await cubit.cargar('u1');

      expect(cubit.state.enlaces, isNull);
      expect(cubit.state.error, mensajeSinMenu);

      await cubit.close();
    });

    test('al cerrar sesión se olvida', () async {
      final cubit = MenuCubit(servicio());
      await cubit.cargar('u1');

      cubit.vaciar();

      expect(cubit.state, const MenuState());
      await cubit.close();
    });
  });

  group('El tablero', () {
    late MenuCubit menuCubit;

    Future<void> montar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      final llavero = AlmacenClavesEnMemoria();
      // La sesión ya abierta, como la deja el acceso.
      final auth = AuthBloc(
        servicio: AuthServiceFalso(),
        almacen: AlmacenDeSesion(llavero),
        credenciales: CredencialesService(llavero),
        fijarToken: (_) {},
        restaurarAlCrear: false,
      )..emit(AuthAutenticado(_usuario()));
      addTearDown(auth.close);

      menuCubit = MenuCubit(servicio());
      addTearDown(menuCubit.close);

      final dioVacio = DioGrabador({
        'GET /agenda/paciente/mis-citas': (_) => <Object?>[],
        'GET /portal/dependientes': (_) => <Object?>[],
      }).dio;

      await tester.pumpWidget(
        conDatosDeLaClinica(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: auth),
              BlocProvider.value(value: menuCubit),
              BlocProvider(
                create: (context) => CitasBloc(
                  citas: CitasService(dioVacio, CacheEnMemoria()),
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
            ],
            child: MaterialApp(
              theme: temaCliniq(),
              home: const DashboardPage(),
            ),
          ),
        ),
      );
    }

    setUp(sondeoConRed);

    testWidgets('la barra y los accesos rápidos son los del menú, con sus '
        'nombres; «Perfil» siempre está', (tester) async {
      await montar(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pestana-inicio')), findsOneWidget);
      expect(find.byKey(const Key('pestana-mis-citas')), findsOneWidget);
      expect(find.byKey(const Key('pestana-agendar-cita')), findsOneWidget);
      expect(find.byKey(const Key('pestana-mis-dependientes')), findsOneWidget);
      expect(find.byKey(const Key('pestana-perfil')), findsOneWidget);
      expect(find.byKey(const Key('pestana-mi-salud')), findsNothing);

      expect(find.text('Mis dependientes'), findsWidgets);
      expect(find.byKey(const Key('acceso-mi-salud')), findsOneWidget);
      expect(find.byKey(const Key('acceso-centro-ayuda')), findsOneWidget);
    });

    testWidgets('una ruta conocida abre la pantalla de la aplicación', (
      tester,
    ) async {
      await montar(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('pestana-mis-dependientes')));
      await tester.pumpAndSettle();
      expect(find.byType(DependientesPage), findsOneWidget);
    });

    testWidgets('una ruta que la aplicación no tiene se abre en el '
        'navegador', (tester) async {
      final navegador = NavegadorFalso()..instalar();
      await montar(tester);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('acceso-mi-salud')));
      await tester.tap(find.byKey(const Key('acceso-mi-salud')));
      await tester.pumpAndSettle();

      expect(navegador.abiertas, [
        'https://cliniq.gcaicedo-proyectos.com/mi-salud',
      ]);
      expect(navegador.ultimaFuera, isTrue);
    });

    testWidgets('un acceso conocido que no está en la barra se abre encima', (
      tester,
    ) async {
      await montar(tester);
      await tester.pumpAndSettle();

      final consultas = find.byKey(const Key('acceso-consultas'));
      await tester.ensureVisible(consultas);
      await tester.tap(consultas);
      await tester.pumpAndSettle();

      expect(find.byType(ConsultasPage), findsOneWidget);
    });

    testWidgets('sin menú ni copia: el aviso con «Reintentar»', (tester) async {
      hayRed = false;
      await montar(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sin-menu')), findsOneWidget);
      expect(find.text(mensajeSinMenu), findsOneWidget);

      hayRed = true;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pestana-perfil')), findsOneWidget);
    });
  });
}

Usuario _usuario() => Usuario({
  'uid': 'u1',
  'nombre': 'Ana María Pérez',
  'email': 'ana@correo.com',
  'role': 3,
  'permisos': [
    Permisos.misCitas,
    Permisos.agendar,
    Permisos.dependientes,
    Permisos.consultas,
  ],
  'legalPendientes': <String>[],
});
