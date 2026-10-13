// test/fotos_perfil_servicio_test.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:app_cliniq/features/fotos_perfil/data/fotos_perfil_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/fotos_perfil.dart';

/// Las fotos de perfil contra la API: con el token del Dio de la
/// aplicación, por versión, con caché en memoria y en disco, y la subida
/// multipart.
void main() {
  late Directory carpeta;
  late DioGrabador api;
  final foto = Uint8List.fromList([0xFF, 0xD8, 0xFF, 9, 9, 9]);

  FotosPerfilService servicio() =>
      FotosPerfilService(api.dio, carpetaBase: () async => carpeta);

  setUp(() {
    carpeta = Directory.systemTemp.createTempSync('fotos_perfil_');
    api = DioGrabador({'GET /auth/u1/foto': (_) => foto});
  });

  tearDown(() {
    if (carpeta.existsSync()) carpeta.deleteSync(recursive: true);
  });

  Iterable<String> archivos() => carpeta.existsSync()
      ? carpeta
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
      : const [];

  group('Pedir una foto', () {
    test('GET /auth/:id/foto?v=, en bytes', () async {
      final bytes = await servicio().obtener('u1', 3);

      expect(bytes, foto);
      final pedido = api.ultimo('GET /auth/u1/foto');
      expect(pedido.queryParameters, {'v': 3});
      expect(pedido.responseType, ResponseType.bytes);
    });

    test('sin versión no se pide nada: no tiene foto', () async {
      expect(await servicio().obtener('u1', null), isNull);
      expect(await servicio().obtener('', 3), isNull);
      expect(api.pedidos, isEmpty);
    });

    test('la segunda vez sale de la memoria', () async {
      final fotos = servicio();
      await fotos.obtener('u1', 3);
      await fotos.obtener('u1', 3);

      expect(api.claves, ['GET /auth/u1/foto']);
      expect(fotos.enMemoria('u1', 3), foto);
      expect(fotos.enMemoria('u1', 4), isNull);
    });

    test('después de reiniciar sale del disco', () async {
      await servicio().obtener('u1', 3);
      expect(archivos(), ['u1_v3.jpg']);

      final otraVez = await servicio().obtener('u1', 3);

      expect(otraVez, foto);
      expect(api.pedidos, hasLength(1));
    });

    test('diez avatares a la vez piden una sola vez', () async {
      final fotos = servicio();
      final todas = await Future.wait([
        for (var i = 0; i < 10; i++) fotos.obtener('u1', 3),
      ]);

      expect(todas.every((b) => b == foto), isTrue);
      expect(api.pedidos, hasLength(1));
    });

    test(
      '404 (sin foto o sin permiso): null, y no se vuelve a preguntar',
      () async {
        api.rutas['GET /auth/u1/foto'] = (_) => throw errorHttp(404);
        final fotos = servicio();

        expect(await fotos.obtener('u1', 3), isNull);
        expect(await fotos.obtener('u1', 3), isNull);
        expect(api.pedidos, hasLength(1));
      },
    );

    test('sin red: null, y la próxima vez se intenta de nuevo', () async {
      api.rutas['GET /auth/u1/foto'] = (_) => throw errorDeRed();
      final fotos = servicio();

      expect(await fotos.obtener('u1', 3), isNull);
      api.rutas['GET /auth/u1/foto'] = (_) => foto;
      expect(await fotos.obtener('u1', 3), foto);
      expect(api.pedidos, hasLength(2));
    });

    test('sin disco (sin complemento) sigue en memoria', () async {
      final fotos = FotosPerfilService(
        api.dio,
        carpetaBase: () => Future.error(Exception('sin disco')),
      );

      expect(await fotos.obtener('u1', 3), foto);
      expect(fotos.enMemoria('u1', 3), foto);
    });

    test('la memoria guarda solo las últimas', () async {
      api.rutas['GET /auth/u2/foto'] = (_) => foto;
      final fotos = FotosPerfilService(
        api.dio,
        carpetaBase: () async => carpeta,
        maximoEnMemoria: 1,
      );

      await fotos.obtener('u1', 1);
      await fotos.obtener('u2', 1);

      expect(fotos.enMemoria('u1', 1), isNull);
      expect(fotos.enMemoria('u2', 1), foto);
    });
  });

  group('Sin versión (el médico de una cita)', () {
    test('GET /auth/:id/foto sin «v», solo en memoria', () async {
      final fotos = servicio();

      expect(await fotos.obtenerVigente('u1'), foto);
      expect(await fotos.obtenerVigente('u1'), foto);

      expect(api.pedidos, hasLength(1));
      expect(api.pedidos.single.queryParameters, isEmpty);
      expect(fotos.vigenteEnMemoria('u1'), foto);
      expect(archivos(), isEmpty);
    });

    test('404: sin foto, y no se vuelve a preguntar', () async {
      api.rutas['GET /auth/u1/foto'] = (_) => throw errorHttp(404);
      final fotos = servicio();

      expect(await fotos.obtenerVigente('u1'), isNull);
      expect(await fotos.obtenerVigente('u1'), isNull);
      expect(api.pedidos, hasLength(1));
    });

    test('pasados cinco minutos se vuelve a pedir', () async {
      var ahora = DateTime(2026, 10, 13, 9);
      final fotos = FotosPerfilService(
        api.dio,
        carpetaBase: () async => carpeta,
        ahora: () => ahora,
      );

      await fotos.obtenerVigente('u1');
      ahora = ahora.add(const Duration(minutes: 4));
      await fotos.obtenerVigente('u1');
      expect(api.pedidos, hasLength(1));

      ahora = ahora.add(const Duration(minutes: 1));
      expect(fotos.vigenteEnMemoria('u1'), isNull);
      await fotos.obtenerVigente('u1');
      expect(api.pedidos, hasLength(2));
    });

    test('sin red: null, y se intenta de nuevo', () async {
      api.rutas['GET /auth/u1/foto'] = (_) => throw errorDeRed();
      final fotos = servicio();

      expect(await fotos.obtenerVigente('u1'), isNull);
      await fotos.obtenerVigente('u1');
      expect(api.pedidos, hasLength(2));
    });
  });

  group('Subir y quitar', () {
    test(
      'la propia: PUT /auth/me/foto multipart con el campo «foto»',
      () async {
        api.rutas['PUT /auth/me/foto'] = (_) => {'uid': 'u1', 'fotoVersion': 4};
        final fotos = servicio();
        await fotos.obtener('u1', 3);

        final version = await fotos.subir(jpegFalso, uidPropio: 'u1');

        expect(version, 4);
        final datos = api.ultimo('PUT /auth/me/foto').data as FormData;
        expect(datos.files.single.key, 'foto');
        expect(datos.files.single.value.contentType.toString(), 'image/jpeg');

        // La nueva queda lista para verse, y la vieja se borra.
        expect(fotos.enMemoria('u1', 4), jpegFalso);
        expect(fotos.enMemoria('u1', 3), isNull);
        expect(archivos(), ['u1_v4.jpg']);
      },
    );

    test('la de un dependiente: PUT /auth/:id/foto', () async {
      api.rutas['PUT /auth/d1/foto'] = (_) => {
        'user': {'uid': 'd1', 'fotoVersion': 1},
      };
      final fotos = servicio();

      expect(await fotos.subir(jpegFalso, uid: 'd1'), 1);
      expect(fotos.enMemoria('d1', 1), jpegFalso);
    });

    test('un error de la API llega con su mensaje', () async {
      api.rutas['PUT /auth/me/foto'] = (_) =>
          throw errorHttp(400, 'La imagen debe medir al menos 128 px.');

      expect(
        () => servicio().subir(jpegFalso, uidPropio: 'u1'),
        throwsA(isA<DioException>()),
      );
    });

    test('quitar la propia y la de un dependiente borra sus copias', () async {
      api.rutas['DELETE /auth/me/foto'] = (_) => {'ok': true};
      api.rutas['DELETE /auth/d1/foto'] = (_) => {'ok': true};
      api.rutas['GET /auth/d1/foto'] = (_) => foto;
      final fotos = servicio();
      await fotos.obtener('u1', 3);
      await fotos.obtener('d1', 2);

      await fotos.quitar(uidPropio: 'u1');
      await fotos.quitar(uid: 'd1');

      expect(api.claves, contains('DELETE /auth/me/foto'));
      expect(api.claves, contains('DELETE /auth/d1/foto'));
      expect(fotos.enMemoria('u1', 3), isNull);
      expect(fotos.enMemoria('d1', 2), isNull);
      expect(archivos(), isEmpty);
    });

    test('al cerrar sesión se borran todas', () async {
      final fotos = servicio();
      await fotos.obtener('u1', 3);

      await fotos.borrarTodo();

      expect(fotos.enMemoria('u1', 3), isNull);
      expect(archivos(), isEmpty);
    });
  });
}
