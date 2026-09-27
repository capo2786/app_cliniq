// test/documentos_legales_test.dart

import 'package:app_cliniq/core/network/api_client.dart';
import 'package:app_cliniq/core/network/api_interceptor.dart';
import 'package:app_cliniq/core/presentacion/widgets/texto_markdown.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/legal/data/legal_service.dart';
import 'package:app_cliniq/features/legal/presentacion/aceptacion_legal_page.dart';
import 'package:app_cliniq/features/legal/presentacion/documento_legal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/adaptador_http.dart';
import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/navegador_falso.dart';

/// Los documentos legales se leen dentro de la aplicación: el texto llega de
/// `GET /legal/documentos/:slug` en Markdown y se pinta con widgets propios,
/// con una copia para leerlo sin red. No se abre el panel web.
void main() {
  late CacheLocal cache;
  late bool hayRed;
  late DioGrabador api;

  Map<String, dynamic> textoJson(String slug, {String? contenido}) => {
    'clave': slug.toUpperCase(),
    'slug': slug,
    'version': '1.0',
    'titulo': slug == 'terminos'
        ? 'Términos y condiciones de uso'
        : 'Política de privacidad',
    'resumen': 'Las reglas para usar Clínica Andina.',
    'tipos': [1, 2, 3, 4],
    'vigenteDesde': '2026-09-26T05:00:00.000Z',
    'contenido':
        contenido ??
        '## 1. Qué es Clínica Andina\n\n'
            'Clínica Andina **no presta** servicios médicos por sí misma.\n'
            'La atención la brindan los profesionales.\n\n'
            '- Tu cuenta es personal.\n'
            '- No compartas tu contraseña.\n\n'
            'Lee también la [política de privacidad](/legal/privacidad).',
  };

  setUp(() {
    cache = CacheEnMemoria();
    hayRed = true;
    api = DioGrabador({
      'GET /legal/documentos/terminos': (_) {
        if (!hayRed) throw errorDeRed();
        return textoJson('terminos');
      },
      'GET /legal/documentos/privacidad': (_) {
        if (!hayRed) throw errorDeRed();
        return textoJson('privacidad', contenido: 'Tus datos son tuyos.');
      },
      'GET /legal/documentos/viejo': (_) =>
          throw errorHttp(404, 'Documento legal no encontrado'),
    });
  });

  LegalService servicio() => LegalService(api.dio, cache);

  group('El texto de un documento', () {
    test('GET /legal/documentos/:slug es pública y trae el Markdown', () async {
      final documento = await servicio().texto('terminos');

      expect(api.claves, ['GET /legal/documentos/terminos']);
      expect(
        api.ultimo('GET /legal/documentos/terminos').extra[rutaPublica],
        isTrue,
      );
      expect(documento.titulo, 'Términos y condiciones de uso');
      expect(documento.version, '1.0');
      expect(documento.contenido, startsWith('## 1. Qué es Clínica Andina'));
      // Un instante real: la medianoche de la clínica.
      expect(documento.vigenteDesde, DateTime.utc(2026, 9, 26, 5));
      expect(documento.desdeCache, isFalse);
    });

    test('sin red, la última copia; sin copia, el error', () async {
      await servicio().texto('terminos');
      hayRed = false;

      final copia = await servicio().texto('terminos');
      expect(copia.desdeCache, isTrue);
      expect(copia.contenido, contains('no presta'));

      await expectLater(servicio().texto('privacidad'), throwsA(anything));
    });

    test('la copia es de la clínica: sobrevive al cierre de sesión', () async {
      await servicio().texto('terminos');
      await cache.vaciarDatosPersonales();
      hayRed = false;

      expect((await servicio().texto('terminos')).desdeCache, isTrue);
    });

    test('un 404 es «no encontrado», aunque haya una copia vieja', () async {
      await cache.guardar(LegalService.claveTexto('viejo'), textoJson('viejo'));

      await expectLater(
        servicio().texto('viejo'),
        throwsA(isA<DocumentoLegalNoEncontrado>()),
      );
    });
  });

  group('El Markdown', () {
    test('párrafos, títulos, listas y saltos de línea', () {
      final bloques = interpretarMarkdown(
        '# Título\n\nUna línea\notra línea\n\n- uno\n* dos\n\n1. primero\n'
        '2) segundo\ntexto suelto',
      );

      expect(bloques.map((b) => b.tipo), [
        TipoDeBloque.titulo,
        TipoDeBloque.parrafo,
        TipoDeBloque.lista,
        TipoDeBloque.lista,
        TipoDeBloque.parrafo,
      ]);
      expect(bloques[0].nivel, 1);
      expect(bloques[1].lineas, hasLength(2));
      expect(bloques[2].numerada, isFalse);
      expect(bloques[2].lineas, hasLength(2));
      expect(bloques[3].numerada, isTrue);
      expect(bloques[3].lineas.last.single.texto, 'segundo');
    });

    test('negrita y enlaces; un enlace no permitido queda como texto', () {
      expect(fragmentosDe('Hola **mundo** y [aquí](/legal/x).'), const [
        FragmentoMarkdown('Hola '),
        FragmentoMarkdown('mundo', negrita: true),
        FragmentoMarkdown(' y '),
        FragmentoMarkdown('aquí', enlace: '/legal/x'),
        FragmentoMarkdown('.'),
      ]);
      expect(fragmentosDe('[malo](javascript:alert(1))').first.enlace, isNull);
      expect(fragmentosDe('[otro](//evil.com)').single.enlace, isNull);
      expect(
        fragmentosDe('[correo](mailto:a@b.ec)').single.enlace,
        'mailto:a@b.ec',
      );
    });

    test('el texto plano, sin marcas', () {
      expect(
        textoPlanoDeMarkdown('## Hola\n\n- **uno** y [dos](https://x.ec)'),
        'Hola uno y dos',
      );
    });
  });

  group('La pantalla', () {
    setUp(() {
      sondeoConRed();

      // Un documento que se abre desde un enlace del texto usa el servicio
      // de la aplicación: su API y su caché, de mentira.
      Servicios.cacheParaPruebas = CacheEnMemoria();
      ApiClient().dio.httpClientAdapter = AdaptadorHttpFalso({
        'GET /legal/documentos/terminos': (_) =>
            (estado: 200, cuerpo: textoJson('terminos')),
        'GET /legal/documentos/privacidad': (_) => (
          estado: 200,
          cuerpo: textoJson('privacidad', contenido: 'Tus datos son tuyos.'),
        ),
      });
    });

    Future<void> montar(WidgetTester tester, Widget pagina) async {
      await tester.pumpWidget(
        conDatosDeLaClinica(MaterialApp(theme: temaCliniq(), home: pagina)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('pinta el documento nativo, y un enlace interno abre el otro '
        'documento dentro de la aplicación', (tester) async {
      final navegador = NavegadorFalso()..instalar();
      await montar(
        tester,
        DocumentoLegalPage(slug: 'terminos', servicio: servicio()),
      );

      expect(find.text('Términos y condiciones de uso'), findsWidgets);
      expect(find.text('1. Qué es Clínica Andina'), findsOneWidget);
      expect(
        find.textContaining('Versión 1.0 · vigente desde el sábado 26'),
        findsOneWidget,
      );
      expect(find.textContaining('Tu cuenta es personal.'), findsOneWidget);

      await tester.tapOnText(
        find.textRange.ofSubstring('política de privacidad'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tus datos son tuyos.'), findsOneWidget);
      expect(navegador.abiertas, isEmpty);
    });

    testWidgets('sin red ni copia: el error con «Reintentar»', (tester) async {
      hayRed = false;
      await montar(
        tester,
        DocumentoLegalPage(slug: 'terminos', servicio: servicio()),
      );

      expect(find.text('No pudimos cargar esto'), findsOneWidget);

      hayRed = true;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('1. Qué es Clínica Andina'), findsOneWidget);
    });

    testWidgets('un documento que ya no está vigente lo dice', (tester) async {
      await montar(
        tester,
        DocumentoLegalPage(slug: 'viejo', servicio: servicio()),
      );

      expect(find.text('Documento no encontrado'), findsOneWidget);
    });

    testWidgets('en la aceptación, «Leer» abre el texto aquí mismo', (
      tester,
    ) async {
      final navegador = NavegadorFalso()..instalar();
      final legal = DioGrabador({
        'GET /legal/documentos': (_) => [
          {
            'clave': 'TERMINOS',
            'slug': 'terminos',
            'version': '1.0',
            'titulo': 'Términos y condiciones de uso',
          },
        ],
        'GET /legal/mis-aceptaciones': (_) => {
          'aceptaciones': <Object?>[],
          'pendientes': [
            {'clave': 'TERMINOS', 'version': '1.0'},
          ],
        },
      });

      await montar(
        tester,
        AceptacionLegalPage(servicio: LegalService(legal.dio, cache)),
      );

      await tester.tap(find.byKey(const Key('leer-TERMINOS')));
      await tester.pumpAndSettle();

      expect(find.byType(DocumentoLegalPage), findsOneWidget);
      expect(find.text('1. Qué es Clínica Andina'), findsOneWidget);
      expect(navegador.abiertas, isEmpty);
    });
  });
}
