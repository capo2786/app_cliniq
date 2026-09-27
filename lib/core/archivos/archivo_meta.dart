import 'package:equatable/equatable.dart';

import '../fechas/instante.dart';

/// Un archivo guardado en la clínica, tal como lo describe la API
/// (`ArchivoMeta`): lo que se enseña en una lista, sin los bytes.
///
/// Los bytes se piden aparte con `GET /archivos/:id`, y solo cuando la
/// persona toca el archivo.
class ArchivoMeta extends Equatable {
  final String id;
  final String nombre;
  final String mime;

  /// Bytes.
  final int tamano;

  /// Cuándo se subió: un instante real, no hora congelada.
  final DateTime? creadoEn;

  const ArchivoMeta({
    required this.id,
    required this.nombre,
    required this.mime,
    required this.tamano,
    this.creadoEn,
  });

  bool get esImagen => mime.toLowerCase().startsWith('image/');

  bool get esPdf => mime.toLowerCase() == 'application/pdf';

  static ArchivoMeta? desdeJson(Object? json) {
    if (json is! Map) return null;

    final id = json['_id']?.toString().trim() ?? '';
    if (id.isEmpty) return null;

    final tamano = json['tamano'];

    return ArchivoMeta(
      id: id,
      nombre: json['nombre']?.toString().trim().isNotEmpty == true
          ? json['nombre'].toString().trim()
          : 'archivo',
      mime: json['mime']?.toString().trim() ?? '',
      tamano: tamano is num ? tamano.toInt() : 0,
      creadoEn: leerInstante(json['creadoEn']),
    );
  }

  Map<String, dynamic> aJson() => {
    '_id': id,
    'nombre': nombre,
    'mime': mime,
    'tamano': tamano,
    'creadoEn': aTextoInstante(creadoEn),
  };

  @override
  List<Object?> get props => [id, nombre, mime, tamano, creadoEn];
}

/// Lee una lista de archivos, saltando lo que no tenga forma de archivo.
List<ArchivoMeta> interpretarArchivos(Object? datos) {
  if (datos is! List) return const [];

  return [for (final item in datos) ?ArchivoMeta.desdeJson(item)];
}

/// «1,4 MB», «320 KB»: el tamaño como se dice.
String tamanoLegible(int bytes) {
  if (bytes < 1024) return '$bytes B';

  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.round()} KB';

  final mb = kb / 1024;
  final texto = mb >= 10 ? mb.round().toString() : mb.toStringAsFixed(1);

  return '${texto.replaceAll('.', ',')} MB';
}
