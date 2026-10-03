// lib/features/ayuda/data/models/articulo_ayuda.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Un artículo del centro de ayuda, como lo sirve `GET /ayuda`: el título y
/// el contenido ya traen reemplazadas las variables `{{…}}` de la clínica
/// (lo hace el servidor al leerlos), y el contenido es Markdown sencillo.
class ArticuloAyuda extends Equatable {
  final String id;
  final String titulo;
  final String categoria;

  /// Markdown: párrafos, títulos `#`, **negrita**, listas y enlaces.
  final String contenido;

  final int orden;

  /// La clave del artículo, si tiene: la del texto de un botón de ayuda o,
  /// en el artículo principal de una guía de usuario, `guia.<rol>`
  /// (`guia.paciente`).
  final String? clave;

  const ArticuloAyuda({
    required this.id,
    required this.titulo,
    required this.categoria,
    required this.contenido,
    this.orden = 0,
    this.clave,
  });

  /// La categoría con que se agrupa; sin una, «General» (como el panel).
  String get grupo => categoria.trim().isEmpty ? 'General' : categoria.trim();

  /// Es el artículo principal («Empieza aquí») de una guía de usuario.
  bool get esInicioDeGuia => clave?.startsWith('guia.') ?? false;

  /// Lee un artículo, o `null` si no tiene identificador ni título, si
  /// viene sin publicar o si es solo el texto de un botón de ayuda
  /// (`contextual`). El servidor no manda ninguno de los dos a un paciente,
  /// pero se filtran igual, como en el panel.
  static ArticuloAyuda? desdeJson(Object? json) {
    if (json is! Map ||
        json['publicado'] == false ||
        json['contextual'] == true) {
      return null;
    }

    final id = json['_id']?.toString().trim() ?? '';
    final titulo = json['titulo']?.toString().trim() ?? '';
    if (id.isEmpty || titulo.isEmpty) return null;

    final orden = json['orden'];
    final clave = json['clave']?.toString().trim() ?? '';

    return ArticuloAyuda(
      id: id,
      titulo: titulo,
      categoria: json['categoria']?.toString().trim() ?? '',
      contenido: json['contenido']?.toString() ?? '',
      orden: orden is num ? orden.toInt() : 0,
      clave: clave.isEmpty ? null : clave,
    );
  }

  @override
  List<Object?> get props => [id, titulo, categoria, contenido, orden, clave];
}

/// Lee la lista de artículos, saltando lo que no se pueda leer.
List<ArticuloAyuda> interpretarArticulos(Object? datos) {
  if (datos is! List) return const [];

  final articulos = <ArticuloAyuda>[];
  for (final item in datos) {
    final articulo = ArticuloAyuda.desdeJson(item);
    if (articulo != null) {
      articulos.add(articulo);
    } else {
      debugPrint(
        'Cliniq · artículo de ayuda ilegible, sin publicar o solo '
        'contextual',
      );
    }
  }

  return articulos;
}
