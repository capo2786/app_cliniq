// test/ayuda_test.dart

import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/ayuda/data/ayuda_service.dart';
import 'package:app_cliniq/features/ayuda/data/models/articulo_ayuda.dart';
import 'package:app_cliniq/features/ayuda/dominio/busqueda_ayuda.dart';
import 'package:app_cliniq/features/ayuda/dominio/markdown.dart';
import 'package:app_cliniq/features/ayuda/providers/ayuda_cubit.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/ayuda.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';

/// El centro de ayuda: el Markdown de los artículos, la búsqueda, las
/// categorías y la copia sin red.
void main() {
  group('El Markdown', () {
    test('párrafos, títulos y listas, como en el panel', () {
      final bloques = interpretarMarkdown(
        '# Agendar\n'
        'Primera línea\nsegunda línea\n\n'
        '1. Uno\n2) Dos\n- Viñeta\n\n'
        'Final',
      );

      expect(bloques, [
        const TituloMarkdown(1, [TramoMarkdown('Agendar')]),
        const ParrafoMarkdown([
          [TramoMarkdown('Primera línea')],
          [TramoMarkdown('segunda línea')],
        ]),
        const ListaMarkdown(
          numerada: true,
          items: [
            [TramoMarkdown('Uno')],
            [TramoMarkdown('Dos')],
          ],
        ),
        const ListaMarkdown(
          numerada: false,
          items: [
            [TramoMarkdown('Viñeta')],
          ],
        ),
        const ParrafoMarkdown([
          [TramoMarkdown('Final')],
        ]),
      ]);
    });

    test('negrita y enlaces, también uno dentro del otro', () {
      expect(tramosDe('Abre **Agendar cita** y listo'), const [
        TramoMarkdown('Abre '),
        TramoMarkdown('Agendar cita', negrita: true),
        TramoMarkdown(' y listo'),
      ]);

      expect(tramosDe('Ve a **[soporte](/soporte)**.'), const [
        TramoMarkdown('Ve a '),
        TramoMarkdown('soporte', negrita: true, enlace: '/soporte'),
        TramoMarkdown('.'),
      ]);

      expect(tramosDe('[Escríbenos](mailto:ayuda@andina.ec)'), const [
        TramoMarkdown('Escríbenos', enlace: 'mailto:ayuda@andina.ec'),
      ]);
    });

    test('solo se enlaza http, https, mailto y rutas internas', () {
      expect(enlacePermitido('https://andina.ec'), isTrue);
      expect(enlacePermitido('/portal/agendar'), isTrue);
      expect(enlacePermitido('//otro.sitio'), isFalse);
      expect(enlacePermitido('javascript:alert(1)'), isFalse);

      // Un enlace no permitido queda como su texto, sin corchetes.
      expect(tramosDe('[clic](javascript:alert(1))'), const [
        TramoMarkdown('clic'),
        TramoMarkdown(')'),
      ]);
    });

    test('un texto con <etiquetas> es solo texto', () {
      expect(tramosDe('<b>hola</b>'), const [TramoMarkdown('<b>hola</b>')]);
    });

    test('el texto plano, para buscar y para el resumen', () {
      expect(
        textoPlano('# Título\n- **Uno** con [enlace](/x)\n2. Dos'),
        'Título Uno con enlace Dos',
      );
    });
  });

  group('La búsqueda y las categorías', () {
    final articulos = interpretarArticulos(articulosJson());

    test('sin tildes ni mayúsculas, y todas las palabras', () {
      expect(normalizarBusqueda('  Contraseña  OLVIDÉ '), 'contrasena olvide');
      expect(filtrarArticulos(articulos, 'contrasena').map((a) => a.id), [
        'a3',
      ]);
      expect(filtrarArticulos(articulos, 'cita cancelar').map((a) => a.id), [
        'a2',
      ]);
      expect(filtrarArticulos(articulos, ''), hasLength(articulos.length));
    });

    test('agrupa por categoría en orden alfabético, y dentro por orden', () {
      final grupos = agruparArticulos(articulos);

      expect(grupos.map((g) => g.categoria), [
        'Citas',
        'Cuenta y acceso',
        'General',
        'Ópticas',
      ]);
      expect(grupos.first.articulos.map((a) => a.id), ['a1', 'a2']);
    });

    test('lo que no se puede leer o no está publicado no aparece', () {
      final leidos = interpretarArticulos([
        ...articulosJson(),
        {'_id': 'x', 'titulo': 'Oculto', 'publicado': false},
        {'titulo': 'Sin id'},
        'basura',
      ]);

      expect(leidos, hasLength(articulosJson().length));
    });
  });

  group('El servicio', () {
    late CacheLocal cache;
    late bool hayRed;
    late DioGrabador api;

    setUp(() {
      cache = CacheEnMemoria();
      hayRed = true;
      api = DioGrabador({
        'GET /ayuda': (pedido) {
          if (!hayRed) throw errorDeRed();
          final q = pedido.queryParameters['q'] as String?;
          return q == null ? articulosJson() : [articulosJson().first];
        },
      });
    });

    AyudaService servicio() => AyudaService(api.dio, cache);

    test(
      'busca en el servidor con ?q= y solo guarda la lista completa',
      () async {
        final todos = await servicio().buscar('u1');
        final buscados = await servicio().buscar('u1', q: '  agendar ');

        expect(todos.articulos, hasLength(5));
        expect(buscados.articulos, hasLength(1));
        expect(api.pedidos.first.queryParameters, isEmpty);
        expect(api.pedidos.last.queryParameters, {'q': 'agendar'});

        final copia = await servicio().guardados('u1');
        expect(copia!.articulos, hasLength(5));
      },
    );

    test('sin red busca sobre la copia, con la misma regla', () async {
      await servicio().buscar('u1');
      hayRed = false;

      final resultado = await servicio().buscar('u1', q: 'contraseña');

      expect(resultado.desdeCache, isTrue);
      expect(resultado.articulos.map((a) => a.id), ['a3']);
    });

    test('sin red y sin copia, el error', () async {
      hayRed = false;

      await expectLater(servicio().buscar('u1'), throwsA(isA<DioException>()));
    });
  });

  group('El cubit', () {
    late DioGrabador api;

    setUp(() {
      api = DioGrabador({
        'GET /ayuda': (pedido) {
          final q = pedido.queryParameters['q'] as String?;
          if (q == 'falla') throw errorHttp(500);
          return q == null
              ? articulosJson()
              : articulosJson()
                    .where((a) => a['categoria'] == 'Citas')
                    .toList();
        },
      });
    });

    AyudaCubit crear() => AyudaCubit(
      servicio: AyudaService(api.dio, CacheEnMemoria()),
      uid: 'u1',
    );

    test('carga todo y agrupa por categoría', () async {
      final cubit = crear();
      addTearDown(cubit.close);

      await cubit.buscar();

      expect(cubit.state.carga, CargaAyuda.lista);
      expect(cubit.state.grupos, hasLength(4));
      expect(cubit.state.visibles, hasLength(4));
    });

    test('elegir una categoría deja solo esa; si la búsqueda nueva no la '
        'trae, se vuelve a «Todas»', () async {
      final cubit = crear();
      addTearDown(cubit.close);
      await cubit.buscar();

      cubit.elegirCategoria('Citas');
      expect(cubit.state.visibles.single.categoria, 'Citas');

      await cubit.buscar('cita');
      expect(cubit.state.categoria, 'Citas');

      cubit.elegirCategoria('Cuenta y acceso');
      await cubit.buscar('cita');
      expect(cubit.state.categoria, isEmpty);
    });

    test('un error se dice, sin artículos; reintentar vuelve a buscar lo '
        'mismo', () async {
      final cubit = crear();
      addTearDown(cubit.close);

      await cubit.buscar('falla');
      expect(cubit.state.carga, CargaAyuda.error);
      expect(cubit.state.articulos, isEmpty);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.busqueda, 'falla');

      await cubit.reintentar();
      expect(api.ultimo('GET /ayuda').queryParameters, {'q': 'falla'});
    });

    test(
      'la respuesta de una búsqueda vieja que llega tarde se descarta',
      () async {
        final cubit = crear();
        addTearDown(cubit.close);

        final vieja = cubit.buscar();
        final nueva = cubit.buscar('cita');
        await Future.wait([vieja, nueva]);

        expect(cubit.state.busqueda, 'cita');
        expect(cubit.state.grupos.single.categoria, 'Citas');
      },
    );
  });
}
