// test/ayuda_contextual_test.dart

import 'dart:async';

import 'package:app_cliniq/core/network/api_client.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/storage/copia_guardada.dart';
import 'package:app_cliniq/features/ayuda/data/ayuda_contextual_service.dart';
import 'package:app_cliniq/features/ayuda/data/models/ayuda_de_accion.dart';
import 'package:app_cliniq/features/ayuda/presentacion/articulo_ayuda_page.dart';
import 'package:app_cliniq/features/ayuda/presentacion/centro_ayuda_page.dart';
import 'package:app_cliniq/features/ayuda/presentacion/widgets/boton_ayuda.dart';
import 'package:app_cliniq/features/ayuda/providers/ayuda_contextual_cubit.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/adaptador_http.dart';
import 'dobles/ayuda.dart';
import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/pantalla.dart';

/// Los botones de ayuda («?»): los textos de `GET /ayuda/contextual`, su
/// copia por persona, el cubit que los carga una vez por sesión y el botón
/// con su hoja (con texto y sin texto).
void main() {
  late DioGrabador api;
  late CacheLocal cache;
  late bool hayRed;
  late Object? Function() respuesta;

  setUp(() {
    cache = CacheEnMemoria();
    hayRed = true;
    respuesta = ayudaContextualJson;
    api = DioGrabador({
      'GET /ayuda/contextual': (_) {
        if (!hayRed) throw errorDeRed();
        return respuesta();
      },
    });
  });

  AyudaContextualService servicio() => AyudaContextualService(api.dio, cache);

  group('La lectura', () {
    test('clave → título, texto y la guía completa si la hay', () {
      final mapa = interpretarMapaDeAyuda(ayudaContextualJson());

      expect(mapa.keys, ['app.miSalud', 'app.miSalud.receta', 'app.agendar']);
      expect(mapa['app.miSalud']!.titulo, 'Mi salud');
      expect(mapa['app.miSalud']!.texto, contains('**dos partes**'));
      expect(mapa['app.miSalud']!.articuloId, 'g1');
      expect(mapa['app.miSalud.receta']!.articuloId, isNull);
    });

    test('sin título o sin texto no hay ayuda; lo ilegible se salta', () {
      final mapa = interpretarMapaDeAyuda({
        'app.perfil': {'titulo': 'Tu perfil', 'texto': '   '},
        'app.arco': {'titulo': '', 'texto': 'Tus derechos.'},
        'app.soporte': 'basura',
        '': {'titulo': 'Sin clave', 'texto': 'Nada.'},
        'app.avisos': {
          'titulo': 'Avisos',
          'texto': 'Lo nuevo.',
          'articuloId': '  ',
        },
      });

      expect(mapa.keys, ['app.avisos']);
      expect(mapa['app.avisos']!.articuloId, isNull);
    });

    test('una respuesta que no es un mapa no se entiende', () {
      expect(() => interpretarMapaDeAyuda([]), throwsFormatException);
      expect(() => interpretarMapaDeAyuda(null), throwsFormatException);
    });
  });

  group('El servicio', () {
    test('lo pide con la sesión y guarda la copia de esa persona', () async {
      final mapa = await servicio().pedir('u1');

      expect(api.claves, ['GET /ayuda/contextual']);
      expect(mapa, hasLength(3));
      expect(await servicio().guardada('u1'), mapa);
      // La copia es de quien entró: otra cuenta no la ve.
      expect(await servicio().guardada('u2'), isNull);

      // Y se borra al cerrar sesión: depende de los roles de cada uno.
      await cache.vaciarDatosPersonales();
      expect(await servicio().guardada('u1'), isNull);
    });

    test('una respuesta rota no pisa la copia buena', () async {
      await servicio().pedir('u1');
      respuesta = () => '<html>';

      await expectLater(servicio().pedir('u1'), throwsFormatException);
      expect(await servicio().guardada('u1'), hasLength(3));
    });
  });

  group('El cubit', () {
    test(
      'primero la copia y después la del servidor, una vez por sesión',
      () async {
        // La copia de una sesión anterior, con un texto que ya no existe.
        await cache.guardarCopia('ayuda-contextual:u1', {
          'app.perfil': {'titulo': 'Tu perfil', 'texto': 'Tus datos.'},
        });
        final cubit = AyudaContextualCubit(servicio());
        addTearDown(cubit.close);
        final estados = <AyudaContextualState>[];
        final escucha = cubit.stream.listen(estados.add);
        addTearDown(escucha.cancel);

        await cubit.cargar('u1');
        // El último estado llega a quien escucha en la vuelta siguiente.
        await Future<void>.delayed(Duration.zero);

        expect(estados.map((e) => e.mapa.keys.toList()), [
          <String>[],
          ['app.perfil'],
          ['app.miSalud', 'app.miSalud.receta', 'app.agendar'],
        ]);
        expect(cubit.state.alDia, isTrue);
        expect(cubit.state.de('app.perfil'), isNull);

        // Ya cargó en esta sesión: no se vuelve a pedir.
        await cubit.cargar('u1');
        expect(api.claves, ['GET /ayuda/contextual']);
      },
    );

    test('sin red se queda la copia y se reintenta la próxima vez', () async {
      await servicio().pedir('u1');
      api.pedidos.clear();
      hayRed = false;
      final cubit = AyudaContextualCubit(servicio());
      addTearDown(cubit.close);

      await cubit.cargar('u1');
      expect(cubit.state.de('app.miSalud')!.titulo, 'Mi salud');
      expect(cubit.state.alDia, isFalse);

      hayRed = true;
      await cubit.cargar('u1');
      expect(api.claves, ['GET /ayuda/contextual', 'GET /ayuda/contextual']);
      expect(cubit.state.alDia, isTrue);
    });

    test('sin red y sin copia, no hay textos: nada inventado', () async {
      hayRed = false;
      final cubit = AyudaContextualCubit(servicio());
      addTearDown(cubit.close);

      await cubit.cargar('u1');

      expect(cubit.state.mapa, isEmpty);
    });

    test('al cerrar sesión se vacía, y la cuenta siguiente carga los '
        'suyos', () async {
      final cubit = AyudaContextualCubit(servicio());
      addTearDown(cubit.close);
      await cubit.cargar('u1');

      cubit.vaciar();
      expect(cubit.state, const AyudaContextualState());

      respuesta = () => {
        'app.perfil': {'titulo': 'Tu perfil', 'texto': 'Tus datos.'},
      };
      await cubit.cargar('u2');
      expect(cubit.state.uid, 'u2');
      expect(cubit.state.mapa.keys, ['app.perfil']);
    });

    test('una respuesta de la cuenta anterior que llega tarde se '
        'descarta', () async {
      final lenta = Completer<Object?>();
      final cubit = AyudaContextualCubit(
        AyudaContextualService(_DioDiferido(lenta.future), cache),
      );
      addTearDown(cubit.close);

      final carga = cubit.cargar('u1');
      // Que pase la copia y salga el pedido.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      cubit.vaciar();
      lenta.complete(ayudaContextualJson());
      await carga;

      expect(cubit.state.mapa, isEmpty);
    });
  });

  group('El botón', () {
    final textos = interpretarMapaDeAyuda(ayudaContextualJson());

    Widget pantalla({String clave = 'app.miSalud', bool enLinea = false}) =>
        Scaffold(
          appBar: AppBar(
            title: const Text('Mi salud'),
            actions: [BotonAyuda(clave: clave)],
          ),
          body: Row(
            children: [
              const Text('Ver PDF'),
              BotonAyuda(clave: 'app.miSalud.receta', enLinea: enLinea),
            ],
          ),
        );

    testWidgets('con texto: el «?» abre la hoja con el título y el texto', (
      tester,
    ) async {
      await montarPantalla(tester, pantalla(), ayuda: textos);

      final boton = find.byKey(const Key('ayuda-app.miSalud'));
      expect(boton, findsOneWidget);
      expect(find.byTooltip('Ayuda: Mi salud'), findsOneWidget);

      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(find.byType(HojaDeAyuda), findsOneWidget);
      expect(find.text('Mi salud'), findsWidgets);
      // El Markdown, nativo: el párrafo y la lista con su negrita.
      expect(
        find.text(
          'Aquí ves tus diagnósticos, recetas, órdenes y certificados.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('dos partes'), findsOneWidget);
      expect(find.text('Ver la guía completa'), findsOneWidget);
    });

    testWidgets('sin guía completa, la hoja no la ofrece', (tester) async {
      await montarPantalla(tester, pantalla(enLinea: true), ayuda: textos);

      await tester.tap(find.byKey(const Key('ayuda-app.miSalud.receta')));
      await tester.pumpAndSettle();

      expect(find.text('Tu receta'), findsOneWidget);
      expect(find.byKey(const Key('ver-guia-completa')), findsNothing);
    });

    testWidgets('sin texto para la clave, no se enseña nada', (tester) async {
      await montarPantalla(
        tester,
        pantalla(clave: 'app.perfil'),
        ayuda: textos,
      );

      final sinTexto = find.byWidgetPredicate(
        (w) => w is BotonAyuda && w.clave == 'app.perfil',
      );
      // Está en el árbol, pero no pinta nada: ni botón ni hueco.
      expect(sinTexto, findsOneWidget);
      expect(
        find.descendant(of: sinTexto, matching: find.byType(IconButton)),
        findsNothing,
      );
      expect(tester.getSize(sinTexto), Size.zero);
      expect(find.byKey(const Key('ayuda-app.perfil')), findsNothing);
      // El de la otra clave, que sí tiene texto, sigue.
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);
    });

    testWidgets('sin textos cargados (o fuera de la sesión), ningún «?»', (
      tester,
    ) async {
      await montarPantalla(tester, pantalla(), ayuda: const {});
      expect(find.byIcon(Icons.help_outline_rounded), findsNothing);

      // Sin el cubit en el árbol, tampoco: la pantalla se pinta igual.
      await montarPantalla(tester, pantalla());
      expect(find.byIcon(Icons.help_outline_rounded), findsNothing);
      expect(find.text('Ver PDF'), findsOneWidget);
    });

    testWidgets('aparece cuando llegan los textos', (tester) async {
      await montarPantalla(tester, pantalla(), ayuda: const {});
      final cubit = tester
          .element(find.byType(Scaffold))
          .read<AyudaContextualCubit>();

      cubit.emit(AyudaContextualState(uid: 'u1', mapa: textos));
      await tester.pump();

      expect(find.byKey(const Key('ayuda-app.miSalud')), findsOneWidget);
    });

    testWidgets('«Ver la guía completa» abre el artículo en el centro de '
        'ayuda', (tester) async {
      Servicios.cacheParaPruebas = CacheEnMemoria();
      sondeoConRed();
      ApiClient().dio.httpClientAdapter = AdaptadorHttpFalso({
        'GET /ayuda': (_) => (
          estado: 200,
          cuerpo: [...articulosJson(), ...guiaDelPacienteJson()],
        ),
      });

      await montarPantalla(tester, pantalla(), ayuda: textos);
      await tester.tap(find.byKey(const Key('ayuda-app.miSalud')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ver-guia-completa')));
      await tester.pumpAndSettle();

      expect(find.byType(HojaDeAyuda), findsNothing);
      expect(find.byType(ArticuloAyudaPage), findsOneWidget);
      expect(find.text('Empieza aquí'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(CentroAyudaPage), findsOneWidget);
    });
  });
}

/// Un Dio cuya única respuesta llega cuando la prueba quiere.
class _DioDiferido implements Dio {
  final Future<Object?> datos;

  _DioDiferido(this.datos);

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async => Response<T>(
    requestOptions: RequestOptions(path: path),
    statusCode: 200,
    data: await datos as T,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
