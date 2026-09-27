// test/ayuda_page_test.dart

import 'package:app_cliniq/core/network/api_client.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/ayuda/data/ayuda_service.dart';
import 'package:app_cliniq/features/ayuda/data/models/articulo_ayuda.dart';
import 'package:app_cliniq/features/ayuda/presentacion/articulo_ayuda_page.dart';
import 'package:app_cliniq/features/ayuda/presentacion/centro_ayuda_page.dart';
import 'package:app_cliniq/features/ayuda/presentacion/enlaces_de_ayuda.dart';
import 'package:app_cliniq/features/ayuda/presentacion/widgets/buscador_de_ayuda.dart';
import 'package:app_cliniq/features/soporte/presentacion/nuevo_ticket_page.dart';
import 'package:app_cliniq/features/soporte/presentacion/soporte_page.dart';
import 'package:app_cliniq/features/soporte/presentacion/ticket_page.dart';
import 'package:app_cliniq/features/mi_salud/presentacion/mi_salud_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/adaptador_http.dart';
import 'dobles/ayuda.dart';
import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/navegador_falso.dart';
import 'dobles/pantalla.dart';

/// El centro de ayuda en pantalla: categorías, búsqueda, el artículo con
/// su Markdown nativo, sus enlaces (sin salir de la aplicación) y el acceso
/// a soporte.
void main() {
  late DioGrabador api;
  late CacheLocal cache;
  late bool hayRed;

  setUp(() {
    sondeoConRed();
    cache = CacheEnMemoria();
    hayRed = true;
    api = DioGrabador({
      'GET /ayuda': (pedido) {
        if (!hayRed) throw errorDeRed();
        final q = pedido.queryParameters['q'] as String?;
        if (q == null) return articulosJson();
        return q == 'contraseña'
            ? articulosJson().where((a) => a['_id'] == 'a3').toList()
            : <Object?>[];
      },
    });

    // Soporte, al que se llega desde la ayuda, habla con la API de mentira.
    Servicios.cacheParaPruebas = CacheEnMemoria();
    ApiClient().dio.httpClientAdapter = AdaptadorHttpFalso({
      'GET /soporte/tickets': (_) => (estado: 200, cuerpo: <Object?>[]),
    });
  });

  AyudaService servicio() => AyudaService(api.dio, cache);

  Future<void> tocar(WidgetTester tester, Finder buscado) async {
    // Las listas largas construyen solo lo que está cerca de la vista.
    if (buscado.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        buscado,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(buscado);
    await tester.pumpAndSettle();
    await tester.tap(buscado);
    await tester.pumpAndSettle();
  }

  /// Toca el enlace del Markdown que dice [texto].
  Future<void> tocarEnlace(WidgetTester tester, String texto) async {
    TapGestureRecognizer? reconocedor;

    for (final rico in tester.widgetList<RichText>(find.byType(RichText))) {
      rico.text.visitChildren((span) {
        if (span is TextSpan && span.text == texto) {
          reconocedor = span.recognizer as TapGestureRecognizer?;
        }
        return reconocedor == null;
      });
      if (reconocedor != null) break;
    }

    expect(reconocedor, isNotNull, reason: 'no hay enlace «$texto»');
    reconocedor!.onTap!();
    await tester.pumpAndSettle();
  }

  group('El centro de ayuda', () {
    testWidgets('los artículos por categoría, con sus chips y un resumen', (
      tester,
    ) async {
      await montarPantalla(tester, CentroAyudaPage(servicio: servicio()));
      await tester.pumpAndSettle();

      expect(find.text('¿En qué te ayudamos?'), findsOneWidget);
      expect(find.text('Todas  5'), findsOneWidget);
      expect(find.text('Citas  2'), findsOneWidget);
      expect(find.text('¿Cómo agendo una cita?'), findsOneWidget);
      // El resumen, sin las marcas del Markdown.
      expect(
        find.textContaining('Abre Agendar cita. Elige el médico.'),
        findsOneWidget,
      );

      await tocar(tester, find.byKey(const Key('categoria-Cuenta y acceso')));
      expect(find.text('Olvidé mi contraseña'), findsOneWidget);
      expect(find.text('¿Cómo agendo una cita?'), findsNothing);
    });

    testWidgets('buscar con la tecla del teclado lo pide al servidor', (
      tester,
    ) async {
      await montarPantalla(tester, CentroAyudaPage(servicio: servicio()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('campo-buscar-ayuda')),
        '  contraseña ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(api.ultimo('GET /ayuda').queryParameters, {'q': 'contraseña'});
      expect(find.text('Olvidé mi contraseña'), findsOneWidget);
      expect(find.text('¿Cómo agendo una cita?'), findsNothing);
    });

    testWidgets('sin resultados, lo dice y sugiere otras palabras', (
      tester,
    ) async {
      await montarPantalla(tester, CentroAyudaPage(servicio: servicio()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('campo-buscar-ayuda')),
        'teletransporte',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('No encontramos artículos'), findsOneWidget);
    });

    testWidgets('sin red y sin copia: el error con «Reintentar»', (
      tester,
    ) async {
      hayRed = false;
      await montarPantalla(tester, CentroAyudaPage(servicio: servicio()));
      await tester.pumpAndSettle();

      expect(find.text('No pudimos cargar esto'), findsOneWidget);
      hayRed = true;
      await tocar(tester, find.text('Reintentar'));
      expect(find.text('¿Cómo agendo una cita?'), findsOneWidget);
    });

    testWidgets('sin red con copia: busca en la copia y lo dice', (
      tester,
    ) async {
      await tester.runAsync(() => servicio().buscar('u1'));
      hayRed = false;

      await montarPantalla(tester, CentroAyudaPage(servicio: servicio()));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Mostramos los artículos guardados'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('campo-buscar-ayuda')),
        'contrasena',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Olvidé mi contraseña'), findsOneWidget);
      expect(find.text('¿Cómo agendo una cita?'), findsNothing);
    });

    testWidgets('«¿No encontraste lo que buscabas?» lleva a soporte', (
      tester,
    ) async {
      await montarPantalla(tester, CentroAyudaPage(servicio: servicio()));
      await tester.pumpAndSettle();

      await tocar(tester, find.text('Ir a soporte'));

      expect(find.byType(SoportePage), findsOneWidget);
    });
  });

  group('El artículo', () {
    final articulo = interpretarArticulos(articulosJson())[1];

    Future<void> abrir(
      WidgetTester tester, {
      AbrirRutaInterna? abrirRuta,
    }) async {
      await montarPantalla(
        tester,
        ArticuloAyudaPage(articulo: articulo, abrirRuta: abrirRuta),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('el Markdown se pinta nativo: lista numerada y negrita', (
      tester,
    ) async {
      await abrir(tester);

      expect(find.text('¿Cómo agendo una cita?'), findsOneWidget);
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.textContaining('Agendar cita'), findsOneWidget);
      expect(find.textContaining('**'), findsNothing);
    });

    testWidgets('«¿No resolviste tu duda?» abre soporte con el ticket nuevo', (
      tester,
    ) async {
      await abrir(tester);

      await tocar(tester, find.text('Escribir a soporte'));

      expect(find.byType(NuevoTicketPage), findsOneWidget);
    });

    testWidgets('un enlace interno abre su pantalla nativa', (tester) async {
      await abrir(tester);

      await tocarEnlace(tester, 'escríbenos');

      expect(find.byType(SoportePage), findsOneWidget);
    });

    testWidgets('un enlace a la web se abre dentro de la aplicación', (
      tester,
    ) async {
      final navegador = NavegadorFalso()..instalar();
      await abrir(tester);

      await tocarEnlace(tester, 'Clínica Andina');

      expect(navegador.abiertas, ['https://andina.ec']);
      expect(navegador.ultimaFuera, isFalse);
    });

    testWidgets('una ruta de otro módulo va al enrutador; si no la sabe '
        'abrir, se dice y no se sale', (tester) async {
      final pedidas = <String>[];
      final conMarkdown = ArticuloAyuda(
        id: 'x',
        titulo: 'Agendar',
        categoria: 'Citas',
        contenido: '[Agendar](/portal/agendar) o [ver](/admin/tickets/1)',
      );

      await montarPantalla(
        tester,
        ArticuloAyudaPage(
          articulo: conMarkdown,
          abrirRuta: (context, ruta) {
            pedidas.add(ruta);
            return ruta == '/portal/agendar';
          },
        ),
      );
      await tester.pumpAndSettle();

      await tocarEnlace(tester, 'Agendar');
      expect(pedidas, ['/portal/agendar']);
      expect(
        find.text('Esa sección no está disponible en la aplicación.'),
        findsNothing,
      );

      await tocarEnlace(tester, 'ver');
      expect(pedidas.last, '/admin/tickets/1');
      expect(
        find.text('Esa sección no está disponible en la aplicación.'),
        findsOneWidget,
      );
    });
  });

  group('Las rutas propias', () {
    test('ayuda, soporte, un ticket y Mi salud tienen pantalla nativa', () {
      expect(pantallaDeLaRuta('/ayuda'), isA<CentroAyudaPage>());
      expect(pantallaDeLaRuta('/soporte'), isA<SoportePage>());
      expect(
        pantallaDeLaRuta('/soporte/tickets/t9'),
        isA<TicketPage>().having((p) => p.id, 'id', 't9'),
      );
      expect(pantallaDeLaRuta('/mi-salud/'), isA<MiSaludPage>());
      expect(pantallaDeLaRuta('/soporte?x=1'), isA<SoportePage>());
      expect(pantallaDeLaRuta('/portal/agendar'), isNull);
    });
  });

  group('El buscador', () {
    testWidgets('busca tras la pausa y no repite la misma búsqueda', (
      tester,
    ) async {
      final buscadas = <String>[];

      await tester.pumpWidget(
        conDatosDeLaClinica(
          MaterialApp(
            home: Scaffold(
              body: BuscadorDeAyuda(
                alBuscar: buscadas.add,
                pausa: Duration.zero,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'cita ');
      await tester.pump();
      expect(buscadas, ['cita']);

      await tester.enterText(find.byType(TextField), 'cita');
      await tester.pump();
      expect(buscadas, ['cita']);

      await tester.tap(find.byTooltip('Borrar la búsqueda'));
      await tester.pump();
      expect(buscadas, ['cita', '']);
    });
  });
}
