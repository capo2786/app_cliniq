// lib/features/ayuda/data/models/ayuda_de_accion.dart

import 'package:equatable/equatable.dart';

/// El texto de ayuda de una acción o de una pantalla, por su clave
/// (`app.miSalud.receta`), como lo sirve `GET /ayuda/contextual`: el título,
/// el texto en Markdown sencillo (con las variables `{{…}}` de la clínica ya
/// sustituidas por el servidor) y, si la hay, la guía completa en el centro
/// de ayuda.
///
/// Son artículos del centro de ayuda con clave, que el administrador edita
/// en el panel: la aplicación no trae ninguno escrito.
class AyudaDeAccion extends Equatable {
  final String titulo;

  /// Markdown: párrafos, **negrita**, listas y enlaces.
  final String texto;

  /// El artículo del centro de ayuda con la explicación completa («Ver la
  /// guía completa»), si el servidor lo manda.
  final String? articuloId;

  const AyudaDeAccion({
    required this.titulo,
    required this.texto,
    this.articuloId,
  });

  /// Lee el texto de una clave, o `null` si no tiene título ni texto: sin
  /// texto, el botón de ayuda no se enseña.
  static AyudaDeAccion? desdeJson(Object? json) {
    if (json is! Map) return null;

    final titulo = json['titulo']?.toString().trim() ?? '';
    final texto = json['texto']?.toString().trim() ?? '';
    if (titulo.isEmpty || texto.isEmpty) return null;

    final articulo = json['articuloId']?.toString().trim() ?? '';

    return AyudaDeAccion(
      titulo: titulo,
      texto: texto,
      articuloId: articulo.isEmpty ? null : articulo,
    );
  }

  @override
  List<Object?> get props => [titulo, texto, articuloId];
}

/// Lee el mapa clave → texto de `GET /ayuda/contextual`, saltando lo que no
/// se pueda leer. Lanza [FormatException] si la respuesta no es un mapa: así
/// no se pisa la copia buena con una respuesta rota.
Map<String, AyudaDeAccion> interpretarMapaDeAyuda(Object? datos) {
  if (datos is! Map) {
    throw const FormatException('La ayuda contextual no es un mapa');
  }

  return {
    for (final MapEntry(:key, :value) in datos.entries)
      if (key.toString().trim().isNotEmpty)
        key.toString().trim(): ?AyudaDeAccion.desdeJson(value),
  };
}
