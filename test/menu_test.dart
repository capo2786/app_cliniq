// test/menu_test.dart

import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/auth/data/models/usuario.dart';
import 'package:app_cliniq/features/consultas/presentacion/consultas_page.dart';
import 'package:app_cliniq/features/dependientes/presentacion/dependientes_page.dart';
import 'package:app_cliniq/features/navegacion/data/menu_service.dart';
import 'package:app_cliniq/features/navegacion/dominio/destinos.dart';
import 'package:app_cliniq/features/mi_salud/presentacion/mi_salud_page.dart';
import 'package:app_cliniq/features/navegacion/providers/menu_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/navegador_falso.dart';
import 'dobles/tablero.dart';

/// La navegación sale del menú del servidor: la barra, los accesos rápidos,
/// qué abre cada enlace y el enrutador de las rutas del sistema.
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

    test('Mi salud, Centro de ayuda y Soporte ya son pantallas de la '
        'aplicación (mientras llegan, «Muy pronto»)', () {
      expect(
        destinoDe(enlace('/mi-salud')),
        const DestinoNativo(PantallaNativa.miSalud),
      );
      expect(
        destinoDe(enlace('/ayuda')),
        const DestinoNativo(PantallaNativa.ayuda),
      );
      expect(
        destinoDe(enlace('/soporte')),
        const DestinoNativo(PantallaNativa.soporte),
      );
    });

    test('una ruta que la aplicación no sabe abrir no tiene destino: ni '
        'pantalla ni navegador', () {
      expect(destinoDe(enlace('/admin/usuarios')), isNull);
      expect(destinoDe(enlace('/agenda')), isNull);
      expect(destinoDe(enlace('/')), isNull);
    });

    test('un enlace externo va al navegador integrado, tal cual', () {
      expect(
        destinoDe(enlace('https://blog.andina.ec', tipo: 'EXTERNO')),
        const DestinoWeb('https://blog.andina.ec'),
      );
      expect(
        destinoDe(enlace('tel:022550000', tipo: 'EXTERNO')),
        DestinoContacto(Uri.parse('tel:022550000')),
      );
      // Un externo que no es una dirección no se abre.
      expect(destinoDe(enlace('blog', tipo: 'EXTERNO')), isNull);
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
      expect(navegacion.campana, isNull);
    });

    test('lo que no se sabe abrir no se reparte, y /notificaciones es la '
        'campana: ni pestaña ni acceso', () {
      final navegacion = NavegacionDeLaApp.desde([
        enlace('/inicio'),
        const EnlaceMenu(
          key: 'notificaciones',
          label: 'Avisos',
          route: '/notificaciones',
        ),
        enlace('/admin/menu'),
        enlace('/mis-citas'),
      ]);

      expect(navegacion.barra.map((e) => e.route), ['/inicio', '/mis-citas']);
      expect(navegacion.accesos, isEmpty);
      expect(navegacion.campana?.label, 'Avisos');
    });
  });

  group('El enrutador', () {
    test('entiende rutas con parámetros', () {
      expect(
        destinoDeRuta('/portal/consultas/c1'),
        const DestinoNativo(PantallaNativa.consulta, {'id': 'c1'}),
      );
      expect(
        destinoDeRuta('/portal/videoconsulta/cita9'),
        const DestinoNativo(PantallaNativa.videoconsulta, {'citaId': 'cita9'}),
      );
      expect(
        destinoDeRuta('/portal/encuesta/cita9'),
        const DestinoNativo(PantallaNativa.encuesta, {'citaId': 'cita9'}),
      );
      expect(
        destinoDeRuta('/legal/terminos'),
        const DestinoNativo(PantallaNativa.legal, {'slug': 'terminos'}),
      );
      expect(
        destinoDeRuta('/soporte/tickets/t1'),
        const DestinoNativo(PantallaNativa.ticket, {'id': 't1'}),
      );
    });

    test('las dos rutas de los derechos ARCO y la de los avisos', () {
      const privacidad = DestinoNativo(PantallaNativa.privacidad);
      expect(destinoDeRuta('/portal/arco'), privacidad);
      expect(destinoDeRuta('/privacidad/solicitudes'), privacidad);
      expect(
        destinoDeRuta('/notificaciones'),
        const DestinoNativo(PantallaNativa.avisos),
      );
    });

    test('ignora la consulta, el fragmento y la barra final, y decodifica '
        'los parámetros', () {
      expect(
        destinoDeRuta('/portal/consultas/c1/?desde=aviso#mensajes'),
        const DestinoNativo(PantallaNativa.consulta, {'id': 'c1'}),
      );
      expect(
        destinoDeRuta('/soporte/tickets/t%201'),
        const DestinoNativo(PantallaNativa.ticket, {'id': 't 1'}),
      );
      expect(
        destinoDeRuta('/portal/consultas?x=1'),
        const DestinoNativo(PantallaNativa.consultas),
      );
    });

    test('lo que no es una ruta del paciente no se abre', () {
      expect(destinoDeRuta('/admin/tickets/t1'), isNull);
      expect(destinoDeRuta('/consultas/c1'), isNull);
      expect(destinoDeRuta('/portal/consultas/c1/extra'), isNull);
      expect(destinoDeRuta('https://cliniq.ec/mis-citas'), isNull);
      expect(destinoDeRuta('//otro.ec/mis-citas'), isNull);
      expect(destinoDeRuta('/soporte/tickets/%E0%A4%A'), isNull);
      expect(destinoDeRuta(''), isNull);
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
    Future<void> montar(WidgetTester tester) =>
        montarTablero(tester, dio: api.dio, cache: cache, usuario: _usuario());

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

    testWidgets('Mi salud, desde los accesos, abre su pantalla sin salir de '
        'la aplicación', (tester) async {
      final navegador = NavegadorFalso()..instalar();
      await montar(tester);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('acceso-mi-salud')));
      await tester.tap(find.byKey(const Key('acceso-mi-salud')));
      await tester.pumpAndSettle();

      expect(find.byType(MiSaludPage), findsOneWidget);
      expect(navegador.abiertas, isEmpty);
    });

    testWidgets('un enlace externo se abre en el navegador integrado; una '
        'ruta que no se sabe abrir no se enseña', (tester) async {
      menu = [
        ...menuJson(),
        {
          'key': 'extras',
          'label': 'Extras',
          'tipo': 'GRUPO',
          'orden': 3,
          'children': [
            {
              'key': 'blog',
              'label': 'Blog de salud',
              'route': 'https://blog.andina.ec',
              'tipo': 'EXTERNO',
              'orden': 0,
            },
            {
              'key': 'bitacora',
              'label': 'Bitácora',
              'route': '/admin/bitacora',
              'tipo': 'LINK',
              'orden': 1,
            },
          ],
        },
      ];
      final navegador = NavegadorFalso()..instalar();
      await montar(tester);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('acceso-bitacora')), findsNothing);
      expect(find.text('Bitácora'), findsNothing);

      await tester.ensureVisible(find.byKey(const Key('acceso-blog')));
      await tester.tap(find.byKey(const Key('acceso-blog')));
      await tester.pumpAndSettle();

      expect(navegador.abiertas, ['https://blog.andina.ec']);
      expect(navegador.ultimaFuera, isFalse);
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
