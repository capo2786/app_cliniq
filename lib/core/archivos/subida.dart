// lib/core/archivos/subida.dart

import 'package:dio/dio.dart';

import 'archivo_local.dart';
import 'archivo_meta.dart';

/// Sube un archivo como lo esperan todas las rutas de adjuntos de la API
/// (`POST …/adjuntos`, multipart con el campo `archivo`) y devuelve sus
/// metadatos.
///
/// El nombre se corrige a la extensión de su contenido y el tipo va el que
/// se reconoce por sus bytes: el servidor rechaza un archivo cuyo nombre no
/// coincide con lo que contiene. Lanza [FormatException] si la respuesta no
/// trae el identificador del archivo.
Future<ArchivoMeta> subirArchivo(
  Dio dio,
  String ruta,
  ArchivoLocal archivo, {
  void Function(int enviados, int total)? progreso,
}) async {
  final mime = archivo.mime;

  final formulario = FormData.fromMap({
    'archivo': MultipartFile.fromBytes(
      archivo.bytes,
      filename: archivo.nombreParaSubir,
      contentType: mime == null ? null : DioMediaType.parse(mime),
    ),
  });

  final respuesta = await dio.post<dynamic>(
    ruta,
    data: formulario,
    onSendProgress: progreso,
    options: Options(
      // Veinte megas con datos móviles no suben en quince segundos.
      sendTimeout: const Duration(minutes: 3),
      receiveTimeout: const Duration(minutes: 1),
    ),
  );

  final meta = ArchivoMeta.desdeJson(respuesta.data);
  if (meta == null) throw const FormatException('Adjunto sin identificador');

  return meta;
}
