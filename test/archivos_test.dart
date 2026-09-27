// test/archivos_test.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:app_cliniq/core/archivos/archivo_local.dart';
import 'package:app_cliniq/core/archivos/archivo_meta.dart';
import 'package:app_cliniq/core/archivos/archivos_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
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

/// «RIFF», tamaño, «WEBP».
Uint8List webp() => Uint8List.fromList([
  ...'RIFF'.codeUnits,
  0x24,
  0,
  0,
  0,
  ...'WEBPVP8 '.codeUnits,
  ...List.filled(32, 4),
]);

/// Una caja «ftyp» con la marca «heic».
Uint8List heic() => Uint8List.fromList([
  0,
  0,
  0,
  24,
  ...'ftypheic'.codeUnits,
  ...List.filled(32, 5),
]);

/// Los adjuntos se validan antes de subirlos, con las reglas del servidor:
/// los tipos y el tamaño que configuró la clínica.
void main() {
  // La de prueba: PDF, JPG y PNG de hasta 20 MB.
  final reglas = configDePrueba().archivos;
  final tope = reglas.tamanoMaximoBytes;

  group('El tipo sale del contenido', () {
    test('PDF, PNG, JPG, WEBP y HEIC por su firma', () {
      expect(tipoPorContenido(pdf()), 'application/pdf');
      expect(tipoPorContenido(png()), 'image/png');
      expect(tipoPorContenido(jpg()), 'image/jpeg');
      expect(tipoPorContenido(webp()), 'image/webp');
      expect(tipoPorContenido(heic()), 'image/heic');
    });

    test('lo demás no tiene tipo, diga lo que diga el nombre', () {
      expect(tipoPorContenido(Uint8List.fromList([1, 2, 3, 4])), isNull);
      expect(tipoPorContenido(Uint8List(0)), isNull);

      // Una caja «ftyp» sin marca conocida no es HEIC.
      final raro = ArchivoLocal(
        nombre: 'foto.jpg',
        bytes: Uint8List.fromList([0, 0, 0, 24, ...'ftypxxxx'.codeUnits]),
      );
      expect(raro.mime, isNull);
      expect(
        problemaDelArchivo(raro, reglas),
        contains('no es un PDF, JPG ni PNG'),
      );
    });
  });

  group('Antes de subir', () {
    test('un PDF de menos de 20 MB se puede subir', () {
      expect(
        problemaDelArchivo(
          ArchivoLocal(nombre: 'examen.pdf', bytes: pdf()),
          reglas,
        ),
        isNull,
      );
    });

    test('más de 20 MB no se sube, y se dice cuánto pesa', () {
      final grande = ArchivoLocal(nombre: 'tomografia.pdf', bytes: pdf(tope));

      expect(grande.tamano, greaterThan(tope));
      expect(
        problemaDelArchivo(grande, reglas),
        contains('el máximo es 20 MB'),
      );
    });

    test('exactamente 20 MB todavía vale', () {
      final justo = ArchivoLocal(nombre: 'justo.pdf', bytes: pdf(tope - 5));

      expect(justo.tamano, tope);
      expect(problemaDelArchivo(justo, reglas), isNull);
    });

    test('el tope es el de la configuración: con 5 MB, 6 MB ya no', () {
      final cinco = configDePrueba(archivos: {'tamanoMaximoMb': 5}).archivos;
      final seis = ArchivoLocal(nombre: 'rx.pdf', bytes: pdf(6 * 1024 * 1024));

      expect(problemaDelArchivo(seis, reglas), isNull);
      expect(problemaDelArchivo(seis, cinco), contains('el máximo es 5 MB'));
    });

    test('los tipos son los de la configuración', () {
      final foto = ArchivoLocal(nombre: 'foto.webp', bytes: webp());
      final conWebp = configDePrueba(
        archivos: {
          'tipos': ['application/pdf', 'image/webp', 'image/heic'],
        },
      ).archivos;

      expect(
        problemaDelArchivo(foto, reglas),
        contains('no es un PDF, JPG ni PNG'),
        reason: 'la clínica de prueba no acepta WEBP',
      );
      expect(problemaDelArchivo(foto, conWebp), isNull);
      expect(
        problemaDelArchivo(
          ArchivoLocal(nombre: 'a.jpg', bytes: jpg()),
          conWebp,
        ),
        contains('no es un PDF, WEBP ni HEIC'),
      );
      expect(
        problemaDelArchivo(
          ArchivoLocal(nombre: 'b.heic', bytes: heic()),
          conWebp,
        ),
        isNull,
      );
    });

    test('lo que se puede adjuntar, en palabras', () {
      expect(loQueSePuedeAdjuntar(reglas), 'PDF, JPG o PNG de hasta 20 MB');
      expect(formatosLegibles(['application/pdf']), 'PDF');
      expect(
        formatosLegibles(['image/png', 'image/heic'], conjuncion: 'ni'),
        'PNG ni HEIC',
      );
    });

    test('un archivo vacío tampoco', () {
      expect(
        problemaDelArchivo(
          ArchivoLocal(nombre: 'x.pdf', bytes: Uint8List(0)),
          reglas,
        ),
        contains('vacío'),
      );
    });

    test('la extensión se corrige para que coincida con el contenido', () {
      expect(nombreConExtension('foto.png', 'image/jpeg'), 'foto.jpg');
      expect(nombreConExtension('foto.JPEG', 'image/jpeg'), 'foto.JPEG');
      expect(nombreConExtension('scan', 'application/pdf'), 'scan.pdf');
      expect(nombreConExtension('foto.heic', 'image/jpeg'), 'foto.jpg');
      expect(nombreConExtension('foto.heif', 'image/heic'), 'foto.heif');
      expect(nombreConExtension('imagen', 'image/webp'), 'imagen.webp');
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

    Dio conCabeceras(Map<String, List<String>> cabeceras, List<int> bytes) {
      return Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (pedido, manejador) => manejador.resolve(
              Response<List<int>>(
                requestOptions: pedido,
                statusCode: 200,
                data: bytes,
                headers: Headers.fromMap(cabeceras),
              ),
            ),
          ),
        );
    }

    test('con solo el identificador, el nombre y el tipo salen de las '
        'cabeceras de la misma descarga', () async {
      final servicio = ArchivosService(
        conCabeceras({
          'content-type': ['image/png'],
          'content-disposition': [
            "inline; filename=\"captura.png\"; "
                "filename*=UTF-8''captura%20de%20mam%C3%A1.png",
          ],
        }, png(8)),
      );

      final descargado = await servicio.descargarConDatos('a9');

      expect(descargado.bytes, png(8));
      expect(descargado.meta.id, 'a9');
      expect(descargado.meta.nombre, 'captura de mamá.png');
      expect(descargado.meta.mime, 'image/png');
      expect(descargado.meta.esImagen, isTrue);
      expect(descargado.meta.tamano, png(8).length);
    });

    test('sin cabeceras, el tipo se reconoce por el contenido', () async {
      final servicio = ArchivosService(conCabeceras({}, pdf(4)));

      final descargado = await servicio.descargarConDatos('a2');

      expect(descargado.meta.mime, 'application/pdf');
      expect(descargado.meta.nombre, 'adjunto.pdf');
      expect(descargado.meta.esPdf, isTrue);
    });

    test('el nombre de Content-Disposition, con y sin codificar', () {
      expect(nombreDeLaDescarga(null), isNull);
      expect(nombreDeLaDescarga('inline'), isNull);
      expect(nombreDeLaDescarga('attachment; filename="a b.pdf"'), 'a b.pdf');
      expect(
        nombreDeLaDescarga('attachment; filename=receta.pdf'),
        'receta.pdf',
      );
      expect(
        nombreDeLaDescarga("inline; filename*=utf-8''examen%C3%B3.pdf"),
        'examenó.pdf',
      );
    });

    test('unos bytes ya bajados se abren sin volver a pedirlos', () async {
      final abiertos = <(String, String)>[];
      final servicio = ArchivosService(
        api.dio,
        carpetaTemporal: () async => temporal,
        abrir: (ruta, mime) async => abiertos.add((ruta, mime)),
      );

      await servicio.abrirBytesConElSistema(
        const ArchivoMeta(
          id: 'a7',
          nombre: 'orden.pdf',
          mime: 'application/pdf',
          tamano: 9,
        ),
        pdf(4),
      );

      expect(api.pedidos, isEmpty);
      final (ruta, _) = abiertos.single;
      expect(ruta, endsWith('/a7/orden.pdf'));
      expect(await File(ruta).readAsBytes(), pdf(4));
    });
  });
}
