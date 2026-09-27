// test/archivos_test.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:app_cliniq/core/archivos/archivo_local.dart';
import 'package:app_cliniq/core/archivos/archivo_meta.dart';
import 'package:app_cliniq/core/archivos/archivos_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dio_grabador.dart';

/// Bytes que empiezan como un PDF, un PNG o un JPG de verdad.
Uint8List pdf([int largo = 64]) => Uint8List.fromList([
  0x25,
  0x50,
  0x44,
  0x46,
  0x2d,
  ...List.filled(largo, 1),
]);

Uint8List png([int largo = 64]) => Uint8List.fromList([
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  ...List.filled(largo, 2),
]);

Uint8List jpg([int largo = 64]) =>
    Uint8List.fromList([0xff, 0xd8, 0xff, ...List.filled(largo, 3)]);

/// Los adjuntos se validan antes de subirlos, con las reglas del servidor.
void main() {
  group('El tipo sale del contenido', () {
    test('PDF, PNG y JPG por su firma', () {
      expect(tipoPorContenido(pdf()), 'application/pdf');
      expect(tipoPorContenido(png()), 'image/png');
      expect(tipoPorContenido(jpg()), 'image/jpeg');
    });

    test('lo demás no tiene tipo, diga lo que diga el nombre', () {
      expect(tipoPorContenido(Uint8List.fromList([1, 2, 3, 4])), isNull);
      expect(tipoPorContenido(Uint8List(0)), isNull);

      final heic = ArchivoLocal(
        nombre: 'foto.jpg',
        bytes: Uint8List.fromList([0, 0, 0, 24, 0x66, 0x74, 0x79, 0x70]),
      );
      expect(heic.mime, isNull);
      expect(problemaDelArchivo(heic), contains('no es un PDF, JPG ni PNG'));
    });
  });

  group('Antes de subir', () {
    test('un PDF de menos de 20 MB se puede subir', () {
      expect(
        problemaDelArchivo(ArchivoLocal(nombre: 'examen.pdf', bytes: pdf())),
        isNull,
      );
    });

    test('más de 20 MB no se sube, y se dice cuánto pesa', () {
      final grande = ArchivoLocal(
        nombre: 'tomografia.pdf',
        bytes: pdf(tamanoMaximoArchivo),
      );

      expect(grande.tamano, greaterThan(tamanoMaximoArchivo));
      expect(problemaDelArchivo(grande), contains('20 MB'));
    });

    test('exactamente 20 MB todavía vale', () {
      final justo = ArchivoLocal(
        nombre: 'justo.pdf',
        bytes: pdf(tamanoMaximoArchivo - 5),
      );

      expect(justo.tamano, tamanoMaximoArchivo);
      expect(problemaDelArchivo(justo), isNull);
    });

    test('un archivo vacío tampoco', () {
      expect(
        problemaDelArchivo(ArchivoLocal(nombre: 'x.pdf', bytes: Uint8List(0))),
        contains('vacío'),
      );
    });

    test('la extensión se corrige para que coincida con el contenido', () {
      expect(nombreConExtension('foto.png', 'image/jpeg'), 'foto.jpg');
      expect(nombreConExtension('foto.JPEG', 'image/jpeg'), 'foto.JPEG');
      expect(nombreConExtension('scan', 'application/pdf'), 'scan.pdf');
      expect(nombreConExtension('foto.heic', 'image/jpeg'), 'foto.jpg');
      expect(
        nombreConExtension('informe.de.marzo', 'application/pdf'),
        'informe.de.marzo.pdf',
      );
      expect(nombreConExtension('  ', 'image/png'), 'archivo.png');

      final foto = ArchivoLocal(nombre: 'image_picker_1.png', bytes: jpg());
      expect(foto.nombreParaSubir, 'image_picker_1.jpg');
    });
  });

  group('Cómo se nombra', () {
    test('el tamaño se dice como se dice', () {
      expect(tamanoLegible(900), '900 B');
      expect(tamanoLegible(320 * 1024), '320 KB');
      expect(tamanoLegible((1.4 * 1024 * 1024).round()), '1,4 MB');
      expect(tamanoLegible(15 * 1024 * 1024), '15 MB');
    });

    test('un nombre de la API no puede escaparse de su carpeta', () {
      expect(nombreSeguro('../../etc/passwd'), 'passwd');
      expect(nombreSeguro(r'C:\x\receta.pdf'), 'receta.pdf');
      expect(nombreSeguro('a:b*c?.pdf'), 'a_b_c_.pdf');
      expect(nombreSeguro('..'), 'archivo');
      expect(nombreSeguro(''), 'archivo');
    });

    test('ArchivoMeta con la forma de la API', () {
      final meta = ArchivoMeta.desdeJson({
        '_id': 'a1',
        'nombre': 'receta.pdf',
        'mime': 'application/pdf',
        'tamano': 2048,
        'creadoEn': '2026-09-28T14:00:00.000Z',
      })!;

      expect(meta.esPdf, isTrue);
      expect(meta.esImagen, isFalse);
      expect(meta.creadoEn, DateTime.utc(2026, 9, 28, 14));
      expect(ArchivoMeta.desdeJson(meta.aJson()), meta);
      expect(ArchivoMeta.desdeJson({'nombre': 'sin id'}), isNull);
      expect(interpretarArchivos([meta.aJson(), 'basura', {}]), [meta]);
    });
  });

  group('Descargar y abrir', () {
    late DioGrabador api;
    late Directory temporal;

    setUp(() async {
      api = DioGrabador({'GET /archivos/a1': (_) => pdf(10).toList()});
      temporal = await Directory.systemTemp.createTemp('cliniq_prueba');
    });

    tearDown(() async {
      if (await temporal.exists()) await temporal.delete(recursive: true);
    });

    test('baja los bytes con GET /archivos/:id?inline=1', () async {
      final servicio = ArchivosService(api.dio);

      final bytes = await servicio.descargar('a1');

      expect(bytes, pdf(10));
      final pedido = api.ultimo('GET /archivos/a1');
      expect(pedido.queryParameters, {'inline': '1'});
      expect(pedido.responseType, ResponseType.bytes);
    });

    test('un PDF se guarda en la carpeta privada y se abre con el sistema; '
        'al salir se borra', () async {
      final abiertos = <(String, String)>[];
      final servicio = ArchivosService(
        api.dio,
        carpetaTemporal: () async => temporal,
        abrir: (ruta, mime) async => abiertos.add((ruta, mime)),
      );

      await servicio.abrirConElSistema(
        const ArchivoMeta(
          id: 'a1',
          nombre: '../receta.pdf',
          mime: 'application/pdf',
          tamano: 15,
        ),
      );

      expect(abiertos, hasLength(1));
      final (ruta, mime) = abiertos.single;
      expect(mime, 'application/pdf');
      expect(ruta, startsWith(temporal.path));
      expect(ruta, endsWith('/a1/receta.pdf'));
      expect(await File(ruta).readAsBytes(), pdf(10));

      await servicio.borrarDescargas();
      expect(await File(ruta).exists(), isFalse);
    });

    test('si no hay con qué abrirlo, se dice', () async {
      final servicio = ArchivosService(
        api.dio,
        carpetaTemporal: () async => temporal,
        abrir: (_, _) async =>
            throw const ErrorAlAbrirArchivo('No tienes una aplicación'),
      );

      expect(
        () => servicio.abrirConElSistema(
          const ArchivoMeta(
            id: 'a1',
            nombre: 'x.pdf',
            mime: 'application/pdf',
            tamano: 1,
          ),
        ),
        throwsA(isA<ErrorAlAbrirArchivo>()),
      );
    });
  });
}
