import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'archivo_local.dart';
import 'archivo_meta.dart';

/// Un archivo ya bajado: sus bytes y lo que se sabe de él.
class ArchivoDescargado {
  final ArchivoMeta meta;
  final Uint8List bytes;

  const ArchivoDescargado({required this.meta, required this.bytes});
}

/// No se pudo abrir un archivo con otra aplicación del teléfono.
class ErrorAlAbrirArchivo implements Exception {
  final String mensaje;

  const ErrorAlAbrirArchivo(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Abre un archivo ya guardado con la aplicación del sistema que lo lea.
typedef AbrirConElSistema = Future<void> Function(String ruta, String mime);

/// Los archivos guardados en la clínica: `GET /archivos/:id`.
///
/// La descarga lleva la sesión —un archivo clínico no es público—, así que
/// no se puede mandar al navegador con un enlace: se baja con el mismo
/// cliente HTTP de la aplicación. Una imagen se enseña ahí mismo; un PDF se
/// guarda en la carpeta temporal de la aplicación y se abre con el visor del
/// teléfono.
class ArchivosService {
  static const String _carpetaDeDescargas = 'cliniq_adjuntos';

  final Dio _dio;
  final Future<Directory> Function() _carpetaTemporal;
  final AbrirConElSistema _abrir;

  ArchivosService(
    this._dio, {
    Future<Directory> Function()? carpetaTemporal,
    AbrirConElSistema? abrir,
  }) : _carpetaTemporal = carpetaTemporal ?? getTemporaryDirectory,
       _abrir = abrir ?? _abrirConOpenFilex;

  Future<Response<List<int>>> _pedir(String id) => _dio.get<List<int>>(
    '/archivos/$id',
    queryParameters: const {'inline': '1'},
    options: Options(
      responseType: ResponseType.bytes,
      // Un PDF grande con datos móviles tarda más que una lista de citas.
      receiveTimeout: const Duration(minutes: 2),
    ),
  );

  static Uint8List _bytesDe(Response<List<int>> respuesta) {
    final datos = respuesta.data;
    if (datos == null) return Uint8List(0);

    return datos is Uint8List ? datos : Uint8List.fromList(datos);
  }

  /// Los bytes de un archivo.
  Future<Uint8List> descargar(String id) async => _bytesDe(await _pedir(id));

  /// Los bytes de un archivo del que solo se conoce el identificador (el
  /// adjunto de un mensaje de soporte), con su nombre y su tipo.
  ///
  /// Salen de las cabeceras de la misma descarga (`Content-Type` y el
  /// `filename` de `Content-Disposition`); si faltan, el tipo se reconoce
  /// por el contenido. Así no hace falta una segunda petición.
  Future<ArchivoDescargado> descargarConDatos(String id) async {
    final respuesta = await _pedir(id);
    final bytes = _bytesDe(respuesta);

    final delServidor = respuesta.headers
        .value(Headers.contentTypeHeader)
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    final mime = delServidor == null || delServidor.isEmpty
        ? tipoPorContenido(bytes) ?? ''
        : delServidor;

    final nombre = nombreDeLaDescarga(
      respuesta.headers.value('content-disposition'),
    );

    return ArchivoDescargado(
      bytes: bytes,
      meta: ArchivoMeta(
        id: id,
        nombre: nombreConExtension(nombre ?? 'adjunto', mime),
        mime: mime,
        tamano: bytes.length,
      ),
    );
  }

  /// Baja el archivo y lo abre con la aplicación del teléfono que lo lea.
  Future<void> abrirConElSistema(ArchivoMeta archivo) async {
    _soloEnElTelefono();

    await abrirBytesConElSistema(archivo, await descargar(archivo.id));
  }

  /// Guarda unos bytes ya bajados en la carpeta privada y los abre con la
  /// aplicación del teléfono que los lea.
  Future<void> abrirBytesConElSistema(
    ArchivoMeta archivo,
    Uint8List bytes,
  ) async {
    _soloEnElTelefono();

    final carpeta = Directory(
      '${(await _carpetaTemporal()).path}/$_carpetaDeDescargas/${archivo.id}',
    );
    await carpeta.create(recursive: true);

    final ruta = '${carpeta.path}/${nombreSeguro(archivo.nombre)}';
    await File(ruta).writeAsBytes(bytes, flush: true);

    await _abrir(ruta, archivo.mime);
  }

  void _soloEnElTelefono() {
    if (kIsWeb) {
      throw const ErrorAlAbrirArchivo(
        'Los archivos se abren desde la aplicación del teléfono.',
      );
    }
  }

  /// Borra lo descargado: al cerrar sesión no se dejan documentos clínicos
  /// en el teléfono para la siguiente persona.
  Future<void> borrarDescargas() async {
    if (kIsWeb) return;

    try {
      final carpeta = Directory(
        '${(await _carpetaTemporal()).path}/$_carpetaDeDescargas',
      );
      if (await carpeta.exists()) await carpeta.delete(recursive: true);
    } catch (error) {
      debugPrint('Cliniq · no se pudieron borrar las descargas: $error');
    }
  }
}

/// El nombre de archivo de una cabecera `Content-Disposition`, o `null`.
///
/// Prefiere `filename*` (RFC 5987, `UTF-8''informe%20de%20marzo.pdf`), que
/// conserva las tildes, y si no está, el `filename` de siempre.
String? nombreDeLaDescarga(String? disposicion) {
  if (disposicion == null || disposicion.trim().isEmpty) return null;

  final extendido = RegExp(
    r"filename\*\s*=\s*([^']*)'[^']*'([^;]+)",
    caseSensitive: false,
  ).firstMatch(disposicion);

  if (extendido != null) {
    try {
      final nombre = Uri.decodeComponent(extendido.group(2)!.trim());
      if (nombre.trim().isNotEmpty) return nombre.trim();
    } catch (_) {
      // Mal codificado: se prueba con el sencillo.
    }
  }

  final sencillo = RegExp(
    r'filename\s*=\s*(?:"([^"]*)"|([^;]+))',
    caseSensitive: false,
  ).firstMatch(disposicion);
  final nombre = (sencillo?.group(1) ?? sencillo?.group(2))?.trim();

  return nombre == null || nombre.isEmpty ? null : nombre;
}

/// Un nombre que se puede usar como archivo: sin carpetas ni caracteres que
/// el sistema no acepte.
String nombreSeguro(String nombre) {
  final limpio = nombre
      .split(RegExp(r'[\\/]'))
      .last
      .replaceAll(RegExp(r'[\x00-\x1f:*?"<>|]'), '_')
      .trim();

  return limpio.isEmpty || limpio == '.' || limpio == '..' ? 'archivo' : limpio;
}

Future<void> _abrirConOpenFilex(String ruta, String mime) async {
  final resultado = await OpenFilex.open(
    ruta,
    type: mime.isEmpty ? null : mime,
  );

  switch (resultado.type) {
    case ResultType.done:
      return;
    case ResultType.noAppToOpen:
      throw const ErrorAlAbrirArchivo(
        'No tienes una aplicación para abrir este archivo. Instala un lector '
        'de PDF e intenta de nuevo.',
      );
    default:
      throw const ErrorAlAbrirArchivo('No pudimos abrir el archivo.');
  }
}
