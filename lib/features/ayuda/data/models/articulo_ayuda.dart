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

  const ArticuloAyuda({
    required this.id,
    required this.titulo,
    required this.categoria,
    required this.contenido,
    this.orden = 0,
  });

  /// La categoría con que se agrupa; sin una, «General» (como el panel).
  String get grupo => categoria.trim().isEmpty ? 'General' : categoria.trim();

  /// Lee un artículo, o `null` si no tiene identificador ni título, o si
  /// viene sin publicar (el servidor no los manda a un paciente, pero el
  /// panel los filtra igual).
  static ArticuloAyuda? desdeJson(Object? json) {
    if (json is! Map || json['publicado'] == false) return null;

    final id = json['_id']?.toString().trim() ?? '';
    final titulo = json['titulo']?.toString().trim() ?? '';
    if (id.isEmpty || titulo.isEmpty) return null;

    final orden = json['orden'];

    return ArticuloAyuda(
      id: id,
      titulo: titulo,
      categoria: json['categoria']?.toString().trim() ?? '',
      contenido: json['contenido']?.toString() ?? '',
      orden: orden is num ? orden.toInt() : 0,
    );
  }

  @override
  List<Object?> get props => [id, titulo, categoria, contenido, orden];
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
      debugPrint('Cliniq · artículo de ayuda ilegible o sin publicar');
    }
  }

  return articulos;
}
