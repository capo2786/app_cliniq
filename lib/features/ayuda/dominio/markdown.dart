// lib/features/ayuda/dominio/markdown.dart

import 'package:equatable/equatable.dart';

/*
 * El Markdown mínimo de los artículos de ayuda, leído igual que en el panel
 * (core/markdown.ts), para pintarlo con widgets nativos:
 *
 * - párrafos separados por una línea en blanco (un salto simple es otra
 *   línea del mismo párrafo);
 * - títulos con `#`, `##` o `###`;
 * - **negrita**;
 * - listas con `-`, `*` o `1.`;
 * - enlaces `[texto](dirección)`: solo `http`, `https`, `mailto` y rutas
 *   internas (`/ayuda`). Cualquier otro (un `javascript:`) queda como su
 *   texto, sin enlace.
 *
 * Nada del texto se interpreta como otra cosa: no hay HTML que sanear.
 */

/// Un trozo de texto de una línea, con su formato.
class TramoMarkdown extends Equatable {
  final String texto;
  final bool negrita;

  /// La dirección, si el trozo es parte de un enlace permitido.
  final String? enlace;

  const TramoMarkdown(this.texto, {this.negrita = false, this.enlace});

  @override
  List<Object?> get props => [texto, negrita, enlace];

  @override
  String toString() =>
      'Tramo(«$texto»${negrita ? ', negrita' : ''}'
      '${enlace == null ? '' : ', $enlace'})';
}

/// Una línea ya partida en trozos.
typedef LineaMarkdown = List<TramoMarkdown>;

sealed class BloqueMarkdown extends Equatable {
  const BloqueMarkdown();
}

/// Un título; [nivel] 1 a 3, según los `#`.
class TituloMarkdown extends BloqueMarkdown {
  final int nivel;
  final LineaMarkdown linea;

  const TituloMarkdown(this.nivel, this.linea);

  @override
  List<Object?> get props => [nivel, linea];
}

/// Un párrafo: sus líneas, que se enseñan una debajo de otra.
class ParrafoMarkdown extends BloqueMarkdown {
  final List<LineaMarkdown> lineas;

  const ParrafoMarkdown(this.lineas);

  @override
  List<Object?> get props => [lineas];
}

/// Una lista con viñetas o numerada.
class ListaMarkdown extends BloqueMarkdown {
  final bool numerada;
  final List<LineaMarkdown> items;

  const ListaMarkdown({required this.numerada, required this.items});

  @override
  List<Object?> get props => [numerada, items];
}

/// Si una dirección se puede enlazar: `http(s)`, `mailto` o una ruta
/// interna que empieza con una sola `/`.
bool enlacePermitido(String url) =>
    RegExp(r'^(https?://|mailto:)', caseSensitive: false).hasMatch(url) ||
    (url.startsWith('/') && !url.startsWith('//'));

final RegExp _enLinea = RegExp(r'\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)\s<>]+)\)');

/// Parte una línea en trozos con negrita y enlaces.
LineaMarkdown tramosDe(String linea, {bool negrita = false, String? enlace}) {
  final tramos = <TramoMarkdown>[];
  var desde = 0;

  void texto(String parte) {
    if (parte.isEmpty) return;
    tramos.add(TramoMarkdown(parte, negrita: negrita, enlace: enlace));
  }

  for (final coincidencia in _enLinea.allMatches(linea)) {
    texto(linea.substring(desde, coincidencia.start));

    final resaltado = coincidencia.group(1);
    if (resaltado != null) {
      tramos.addAll(tramosDe(resaltado, negrita: true, enlace: enlace));
    } else {
      final url = coincidencia.group(3)!;
      final propio = enlace == null && enlacePermitido(url) ? url : enlace;
      tramos.addAll(
        tramosDe(coincidencia.group(2)!, negrita: negrita, enlace: propio),
      );
    }

    desde = coincidencia.end;
  }

  texto(linea.substring(desde));

  return tramos;
}

/// Lee un artículo entero en bloques.
List<BloqueMarkdown> interpretarMarkdown(String? markdown) {
  final lineas = (markdown ?? '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final bloques = <BloqueMarkdown>[];

  var parrafo = <LineaMarkdown>[];
  List<LineaMarkdown>? items;
  var numerada = false;

  void cerrarParrafo() {
    if (parrafo.isNotEmpty) bloques.add(ParrafoMarkdown(parrafo));
    parrafo = [];
  }

  void cerrarLista() {
    final lista = items;
    if (lista != null && lista.isNotEmpty) {
      bloques.add(ListaMarkdown(numerada: numerada, items: lista));
    }
    items = null;
  }

  for (final cruda in lineas) {
    final linea = cruda.trim();

    if (linea.isEmpty) {
      cerrarParrafo();
      cerrarLista();
      continue;
    }

    final titulo = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(linea);
    if (titulo != null) {
      cerrarParrafo();
      cerrarLista();
      bloques.add(
        TituloMarkdown(titulo.group(1)!.length, tramosDe(titulo.group(2)!)),
      );
      continue;
    }

    final vineta = RegExp(r'^[-*]\s+(.+)$').firstMatch(linea);
    final numero = RegExp(r'^\d+[.)]\s+(.+)$').firstMatch(linea);
    final item = vineta ?? numero;

    if (item != null) {
      cerrarParrafo();
      final esNumerada = vineta == null;
      if (items != null && numerada != esNumerada) cerrarLista();
      numerada = esNumerada;
      (items ??= []).add(tramosDe(item.group(1)!));
      continue;
    }

    cerrarLista();
    parrafo.add(tramosDe(linea));
  }

  cerrarParrafo();
  cerrarLista();

  return bloques;
}

/// El texto sin marcas: para buscar o para un resumen de una línea.
String textoPlano(String? markdown) => (markdown ?? '')
    .replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]*\)'),
      (coincidencia) => coincidencia.group(1)!,
    )
    .replaceAll('**', '')
    .replaceAll(RegExp(r'^\s*(#{1,3}|[-*]|\d+[.)])\s+', multiLine: true), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
