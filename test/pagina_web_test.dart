// test/pagina_web_test.dart

import 'package:app_cliniq/core/presentacion/enlaces.dart';
import 'package:app_cliniq/core/presentacion/pagina_web_page.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/core/web/navegacion_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/navegador_falso.dart';
import 'dobles/vista_web.dart';

/// Las páginas de fuera se abren dentro de la aplicación: un WebView bajo la
/// cabecera de Cliniq, no Custom Tabs, Safari ni el navegador del teléfono.
/// Solo un `tel:` o un `mailto:` salen, al marcador o al correo.
void main() {
  Uri u(String texto) => Uri.parse(texto);

  group('Qué se hace con cada navegación', () {
    test('http y https se cargan: navegar dentro de la página se puede', () {
      expect(
        decidirNavegacionWeb(u('https://andina.ec/x')),
        DecisionWeb.permitir,
      );
      expect(decidirNavegacionWeb(u('http://andina.ec')), DecisionWeb.permitir);
      expect(
        decidirNavegacionWeb(u('https://otro.com'), marcoPrincipal: false),
        DecisionWeb.permitir,
      );
    });

    test('un tel: o un mailto: tocados van al marcador o al correo; si la '
        'página los abre sola, no', () {
      expect(
        decidirNavegacionWeb(u('tel:022550000'), tocado: true),
        DecisionWeb.abrirContacto,
      );
      expect(
        decidirNavegacionWeb(u('mailto:contacto@andina.ec')),
        DecisionWeb.abrirContacto,
      );
      expect(
        decidirNavegacionWeb(u('tel:022550000'), tocado: false),
        DecisionWeb.bloquear,
      );
    });

    test('nada más sale de la aplicación: otras aplicaciones, tiendas, '
        'archivos o guiones se bloquean', () {
      for (final destino in [
        'intent://abrir#Intent;scheme=app;end',
        'market://details?id=x',
        'whatsapp://send?text=hola',
        'sms:0991234567',
        'file:///etc/passwd',
        'javascript:alert(1)',
        'data:text/html,hola',
      ]) {
        expect(
          decidirNavegacionWeb(u(destino)),
          DecisionWeb.bloquear,
          reason: destino,
        );
      }
    });

    test('los marcos pueden cargar about:, data: y blob:; la página '
        'principal, solo about:blank', () {
      expect(
        decidirNavegacionWeb(u('about:srcdoc'), marcoPrincipal: false),
        DecisionWeb.permitir,
      );
      expect(
        decidirNavegacionWeb(
          u('blob:https://andina.ec/1'),
          marcoPrincipal: false,
        ),
        DecisionWeb.permitir,
      );
      expect(
        decidirNavegacionWeb(u('intent://x'), marcoPrincipal: false),
        DecisionWeb.bloquear,
      );
      expect(decidirNavegacionWeb(u('about:blank')), DecisionWeb.permitir);
      expect(decidirNavegacionWeb(u('about:srcdoc')), DecisionWeb.bloquear);
    });

    test('una ventana nueva se carga en la misma pantalla, si se puede', () {
      expect(decidirVentanaNueva(u('https://andina.ec')), DecisionWeb.permitir);
      expect(decidirVentanaNueva(u('market://x')), DecisionWeb.bloquear);
      expect(decidirVentanaNueva(null), DecisionWeb.bloquear);
    });

    test('un error cuenta como «no cargó» solo si es de la página principal, '
        'de una dirección web y no cancelado', () {
      expect(esFalloDeCargaWeb(u('https://andina.ec')), isTrue);
      expect(
        esFalloDeCargaWeb(u('https://andina.ec'), marcoPrincipal: true),
        isTrue,
      );
      expect(
        esFalloDeCargaWeb(u('https://ads.x.com'), marcoPrincipal: false),
        isFalse,
      );
      expect(
        esFalloDeCargaWeb(u('https://andina.ec'), cancelado: true),
        isFalse,
      );
      expect(esFalloDeCargaWeb(u('intent://x')), isFalse);
      expect(esFalloDeCargaWeb(null), isFalse);
    });
  });

  group('Qué dirección se abre y con qué título', () {
    test('solo direcciones web con servidor', () {
      expect(
        direccionWebValida(' https://andina.ec/blog '),
        u('https://andina.ec/blog'),
      );
      expect(direccionWebValida('/soporte'), isNull);
      expect(direccionWebValida('tel:171'), isNull);
      expect(direccionWebValida('https://'), isNull);
      expect(direccionWebValida('ftp://andina.ec'), isNull);
    });

    test('el título: el del enlace, si no el de la página, si no el '
        'servidor', () {
      final direccion = u('https://www.andina.ec/blog');

      expect(
        tituloDePaginaWeb(
          direccion: direccion,
          pedido: 'Blog de salud',
          deLaPagina: 'Otra cosa',
        ),
        'Blog de salud',
      );
      expect(
        tituloDePaginaWeb(direccion: direccion, deLaPagina: 'Blog · Andina'),
        'Blog · Andina',
      );
      expect(
        tituloDePaginaWeb(
          direccion: direccion,
          deLaPagina: 'https://www.andina.ec/blog',
        ),
        'andina.ec',
      );
      expect(tituloDePaginaWeb(direccion: direccion), 'andina.ec');
    });
  });

  group('La pantalla', () {
    late VistaWebFalsa vista;
    late NavegadorFalso navegador;

    setUp(() {
      vista = VistaWebFalsa(tituloDeLaPagina: 'Blog · Clínica Andina')
        ..instalar();
      navegador = NavegadorFalso()..instalar();
    });

    /// Abre [url] con `abrirPaginaWeb`, como el menú o un artículo.
    Future<void> abrir(
      WidgetTester tester,
      String url, {
      String? titulo,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: temaCliniq(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => abrirPaginaWeb(context, url, titulo: titulo),
                child: const Text('Inicio'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Inicio'));
      await tester.pumpAndSettle();
    }

    String titulo(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('titulo-pagina-web'))).data!;

    testWidgets('con la cabecera de Cliniq: el nombre del enlace y el '
        'servidor; «Cerrar» vuelve', (tester) async {
      await abrir(
        tester,
        'https://www.andina.ec/blog',
        titulo: 'Blog de salud',
      );

      expect(find.byType(PaginaWebPage), findsOneWidget);
      expect(vista.cargadas, [u('https://www.andina.ec/blog')]);
      expect(titulo(tester), 'Blog de salud');
      expect(find.text('andina.ec'), findsOneWidget);
      expect(find.byTooltip('Cerrar'), findsOneWidget);
      expect(navegador.abiertas, isEmpty);

      await tester.tap(find.byKey(const Key('cerrar-pagina-web')));
      await tester.pumpAndSettle();
      expect(find.byType(PaginaWebPage), findsNothing);
    });

    testWidgets('sin nombre de enlace, el título de la página', (tester) async {
      await abrir(tester, 'https://andina.ec');

      expect(titulo(tester), 'Blog · Clínica Andina');
    });

    testWidgets('un tel: tocado en la página va al marcador del teléfono', (
      tester,
    ) async {
      await abrir(tester, 'https://andina.ec');

      vista.oyente!.alPedirContacto(u('tel:022550000'));
      await tester.pumpAndSettle();

      expect(navegador.abiertas, ['tel:022550000']);
      expect(navegador.ultimaFuera, isTrue);
      expect(find.byType(PaginaWebPage), findsOneWidget);
    });

    testWidgets('atrás vuelve a la página anterior; en la primera, cierra', (
      tester,
    ) async {
      await abrir(tester, 'https://andina.ec');

      vista.oyente!.alCambiarHistorial(true);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(vista.control.vueltasAtras, 1);
      expect(find.byType(PaginaWebPage), findsOneWidget);

      vista.oyente!.alCambiarHistorial(false);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(vista.control.vueltasAtras, 1);
      expect(find.byType(PaginaWebPage), findsNothing);
    });

    testWidgets('si no carga, lo dice con «Reintentar», que vuelve a '
        'cargarla', (tester) async {
      await abrir(tester, 'https://andina.ec/noticias');

      vista.oyente!.alFallar(u('https://andina.ec/noticias'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('error-pagina-web')), findsOneWidget);
      expect(
        find.text(
          'No pudimos abrir andina.ec. Revisa tu conexión e intenta de nuevo.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('error-pagina-web')), findsNothing);
      expect(vista.cargadas, [
        u('https://andina.ec/noticias'),
        u('https://andina.ec/noticias'),
      ]);
    });

    testWidgets('«Recargar» le pide a la página que se recargue', (
      tester,
    ) async {
      await abrir(tester, 'https://andina.ec');

      await tester.tap(find.byKey(const Key('recargar-pagina-web')));
      await tester.pump();

      expect(vista.control.recargas, 1);
    });

    testWidgets('abrirPaginaWeb con un tel: va al marcador, sin pantalla '
        'web', (tester) async {
      await abrir(tester, 'tel:171');

      expect(navegador.abiertas, ['tel:171']);
      expect(navegador.ultimaFuera, isTrue);
      expect(find.byType(PaginaWebPage), findsNothing);
    });

    testWidgets('una dirección que no es web no abre nada y lo dice', (
      tester,
    ) async {
      await abrir(tester, 'intent://abrir');

      expect(find.byType(PaginaWebPage), findsNothing);
      expect(
        find.text('No pudimos abrir el enlace: intent://abrir'),
        findsOneWidget,
      );
      expect(navegador.abiertas, isEmpty);
    });
  });
}
