// lib/features/ayuda/dominio/busqueda_ayuda.dart

import 'package:equatable/equatable.dart';

import '../data/models/articulo_ayuda.dart';
import 'markdown.dart';

/// Las letras con tilde (o diéresis, o eñe) y su letra sin ella: lo mismo
/// que hace el servidor al normalizar (`NFD` y fuera los diacríticos).
const Map<String, String> _sinTilde = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', //
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', //
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', //
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', //
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', //
  'ñ': 'n', 'ç': 'c',
};

/// Minúsculas, sin tildes y con un solo espacio: «Contraseña» → «contrasena».
String normalizarBusqueda(String texto) {
  final minusculas = texto.toLowerCase();
  final buffer = StringBuffer();

  for (final letra in minusculas.split('')) {
    buffer.write(_sinTilde[letra] ?? letra);
  }

  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Los artículos que tienen todas las palabras buscadas, en el título, la
/// categoría o el texto. Es la búsqueda del servidor, para cuando se busca
/// sin conexión sobre la copia guardada.
List<ArticuloAyuda> filtrarArticulos(
  List<ArticuloAyuda> articulos,
  String busqueda,
) {
  final palabras = normalizarBusqueda(busqueda)
      .split(' ')
      .where((p) => p.isNotEmpty)
      .toList();
  if (palabras.isEmpty) return List.of(articulos);

  return [
    for (final a in articulos)
      if (_contieneTodas(
        normalizarBusqueda(
          '${a.titulo} ${a.categoria} ${textoPlano(a.contenido)}',
        ),
        palabras,
      ))
        a,
  ];
}

bool _contieneTodas(String texto, List<String> palabras) =>
    palabras.every(texto.contains);

/// Los artículos de una categoría.
class GrupoDeArticulos extends Equatable {
  final String categoria;
  final List<ArticuloAyuda> articulos;

  const GrupoDeArticulos(this.categoria, this.articulos);

  /// Es una guía de usuario («Guía del paciente»): la categoría tiene el
  /// artículo principal de una guía (clave `guia.<rol>`). El servidor manda
  /// solo las guías de los roles de quien entró.
  bool get esGuia => articulos.any((a) => a.esInicioDeGuia);

  @override
  List<Object?> get props => [categoria, articulos];
}

/// Agrupa por categoría. Primero las guías de usuario («Tu guía»), con su
/// artículo principal arriba; después las demás categorías en orden
/// alfabético (sin distinguir tildes). Cada grupo, por el orden del
/// administrador y el título, como en el panel.
List<GrupoDeArticulos> agruparArticulos(List<ArticuloAyuda> articulos) {
  final grupos = <String, List<ArticuloAyuda>>{};

  for (final articulo in articulos) {
    (grupos[articulo.grupo] ??= []).add(articulo);
  }

  int porTexto(String a, String b) =>
      normalizarBusqueda(a).compareTo(normalizarBusqueda(b));

  bool esGuia(String categoria) =>
      grupos[categoria]!.any((a) => a.esInicioDeGuia);

  final categorias = grupos.keys.toList()
    ..sort((a, b) {
      final guiaA = esGuia(a);
      if (guiaA != esGuia(b)) return guiaA ? -1 : 1;
      return porTexto(a, b);
    });

  return [
    for (final categoria in categorias)
      GrupoDeArticulos(
        categoria,
        grupos[categoria]!..sort((a, b) {
          if (a.esInicioDeGuia != b.esInicioDeGuia) {
            return a.esInicioDeGuia ? -1 : 1;
          }
          return a.orden != b.orden
              ? a.orden.compareTo(b.orden)
              : porTexto(a.titulo, b.titulo);
        }),
      ),
  ];
}
