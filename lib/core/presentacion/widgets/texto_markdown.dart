// lib/core/presentacion/widgets/texto_markdown.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../tema/tokens.dart';

/*
 * Un Markdown mínimo, pintado con widgets de la aplicación.
 *
 * Los documentos legales (y los artículos de ayuda) llegan del servidor en
 * Markdown, con los datos de la clínica ya sustituidos. Se entiende lo mismo
 * que entiende el panel web (`core/markdown.ts`), ni más ni menos, para que
 * un texto se vea igual en los dos:
 *
 * - párrafos separados por una línea en blanco (un salto simple es un salto
 *   de línea dentro del párrafo);
 * - títulos con `#`, `##` o `###`;
 * - **negrita**;
 * - listas con `-`, `*` o `1.`;
 * - enlaces `[texto](dirección)`, solo `http`, `https`, `mailto` y rutas
 *   internas (`/legal/privacidad`). Cualquier otra cosa (un `javascript:`)
 *   queda como texto.
 *
 * Sin paquetes: no hay HTML que sanear, porque nada del texto se interpreta
 * más que estas marcas.
 */

/// Un trozo de una línea: texto, quizá en negrita, quizá un enlace.
class FragmentoMarkdown {
  final String texto;
  final bool negrita;

  /// La dirección, si es un enlace permitido.
  final String? enlace;

  const FragmentoMarkdown(this.texto, {this.negrita = false, this.enlace});

  @override
  bool operator ==(Object other) =>
      other is FragmentoMarkdown &&
      other.texto == texto &&
      other.negrita == negrita &&
      other.enlace == enlace;

  @override
  int get hashCode => Object.hash(texto, negrita, enlace);

  @override
  String toString() =>
      'FragmentoMarkdown($texto${negrita ? ', negrita' : ''}'
      '${enlace == null ? '' : ', $enlace'})';
}

enum TipoDeBloque { parrafo, titulo, lista }

/// Un bloque del texto: un párrafo (sus líneas), un título o una lista (sus
/// elementos).
class BloqueMarkdown {
  final TipoDeBloque tipo;

  /// Del título: 1, 2 o 3.
  final int nivel;

  /// De la lista: numerada (`1.`) o con viñetas.
  final bool numerada;

  /// Las líneas del párrafo, el título (una) o los elementos de la lista.
  final List<List<FragmentoMarkdown>> lineas;

  const BloqueMarkdown(
    this.tipo,
    this.lineas, {
    this.nivel = 0,
    this.numerada = false,
  });
}

/// ¿Se puede enlazar? Web, correo o una ruta interna (no `//otro.sitio`).
bool enlacePermitido(String direccion) =>
    RegExp(r'^(https?://|mailto:)', caseSensitive: false).hasMatch(direccion) ||
    (direccion.startsWith('/') && !direccion.startsWith('//'));

final RegExp _enLinea = RegExp(r'\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)\s<>]+)\)');

/// Las marcas de una línea: negrita y enlaces.
List<FragmentoMarkdown> fragmentosDe(String linea) {
  final fragmentos = <FragmentoMarkdown>[];
  var desde = 0;

  for (final marca in _enLinea.allMatches(linea)) {
    if (marca.start > desde) {
      fragmentos.add(FragmentoMarkdown(linea.substring(desde, marca.start)));
    }

    final negrita = marca.group(1);
    if (negrita != null) {
      fragmentos.add(FragmentoMarkdown(negrita, negrita: true));
    } else {
      final texto = marca.group(2)!.replaceAll('**', '');
      final direccion = marca.group(3)!;
      fragmentos.add(
        FragmentoMarkdown(
          texto,
          enlace: enlacePermitido(direccion) ? direccion : null,
        ),
      );
    }

    desde = marca.end;
  }

  if (desde < linea.length) {
    fragmentos.add(FragmentoMarkdown(linea.substring(desde)));
  }

  return fragmentos;
}

/// Lee el Markdown en bloques.
List<BloqueMarkdown> interpretarMarkdown(String? markdown) {
  final lineas = (markdown ?? '')
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .split('\n');
  final bloques = <BloqueMarkdown>[];

  var parrafo = <List<FragmentoMarkdown>>[];
  var lista = <List<FragmentoMarkdown>>[];
  var listaNumerada = false;

  void cerrarParrafo() {
    if (parrafo.isNotEmpty) {
      bloques.add(BloqueMarkdown(TipoDeBloque.parrafo, parrafo));
    }
    parrafo = [];
  }

  void cerrarLista() {
    if (lista.isNotEmpty) {
      bloques.add(
        BloqueMarkdown(TipoDeBloque.lista, lista, numerada: listaNumerada),
      );
    }
    lista = [];
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
        BloqueMarkdown(TipoDeBloque.titulo, [
          fragmentosDe(titulo.group(2)!),
        ], nivel: titulo.group(1)!.length),
      );
      continue;
    }

    final vineta = RegExp(r'^[-*]\s+(.+)$').firstMatch(linea);
    final numerada = RegExp(r'^\d+[.)]\s+(.+)$').firstMatch(linea);
    final item = vineta ?? numerada;

    if (item != null) {
      cerrarParrafo();
      final esNumerada = vineta == null;
      if (lista.isNotEmpty && listaNumerada != esNumerada) cerrarLista();
      listaNumerada = esNumerada;
      lista.add(fragmentosDe(item.group(1)!));
      continue;
    }

    cerrarLista();
    parrafo.add(fragmentosDe(linea));
  }

  cerrarParrafo();
  cerrarLista();

  return bloques;
}

/// El texto sin marcas, para buscar o para un resumen de una línea.
String textoPlanoDeMarkdown(String? markdown) => (markdown ?? '')
    .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1) ?? '')
    .replaceAll('**', '')
    .replaceAll(RegExp(r'^\s*(#{1,3}|[-*]|\d+[.)])\s+', multiLine: true), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Pinta un texto en Markdown (ver arriba qué se entiende).
///
/// Los enlaces se tocan: [alTocarEnlace] recibe la dirección tal cual
/// (`/legal/privacidad`, `https://…`, `mailto:…`) y decide cómo abrirla; sin
/// él, se ven como texto.
class TextoMarkdown extends StatefulWidget {
  final String markdown;
  final ValueChanged<String>? alTocarEnlace;

  const TextoMarkdown(this.markdown, {super.key, this.alTocarEnlace});

  @override
  State<TextoMarkdown> createState() => _TextoMarkdownState();
}

class _TextoMarkdownState extends State<TextoMarkdown> {
  final List<TapGestureRecognizer> _reconocedores = [];

  @override
  void dispose() {
    _soltar();
    super.dispose();
  }

  void _soltar() {
    for (final r in _reconocedores) {
      r.dispose();
    }
    _reconocedores.clear();
  }

  static const TextStyle _estiloBase = TextStyle(
    color: AppColors.textoSuave,
    fontSize: 14,
    height: 1.55,
  );

  TextSpan _linea(List<FragmentoMarkdown> fragmentos, TextStyle estilo) {
    return TextSpan(
      style: estilo,
      children: [for (final f in fragmentos) _fragmento(f)],
    );
  }

  InlineSpan _fragmento(FragmentoMarkdown f) {
    final enlace = f.enlace;
    final alTocar = widget.alTocarEnlace;

    final negrita = f.negrita
        ? const TextStyle(fontWeight: FontWeight.w800, color: AppColors.texto)
        : null;

    if (enlace == null || alTocar == null) {
      return TextSpan(text: f.texto, style: negrita);
    }

    final reconocedor = TapGestureRecognizer()..onTap = () => alTocar(enlace);
    _reconocedores.add(reconocedor);

    return TextSpan(
      text: f.texto,
      recognizer: reconocedor,
      style: TextStyle(
        color: AppColors.acentoSuave,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.acentoSuave.withValues(alpha: 0.6),
      ),
    );
  }

  Widget _bloque(BloqueMarkdown bloque) {
    switch (bloque.tipo) {
      case TipoDeBloque.titulo:
        final tamano = switch (bloque.nivel) {
          1 => 19.0,
          2 => 16.5,
          _ => 15.0,
        };
        return Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text.rich(
            _linea(
              bloque.lineas.first,
              TextStyle(
                color: AppColors.texto,
                fontSize: tamano,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        );

      case TipoDeBloque.parrafo:
        final spans = <InlineSpan>[];
        for (var i = 0; i < bloque.lineas.length; i++) {
          if (i > 0) spans.add(const TextSpan(text: '\n'));
          spans.add(_linea(bloque.lineas[i], _estiloBase));
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text.rich(TextSpan(style: _estiloBase, children: spans)),
        );

      case TipoDeBloque.lista:
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, item) in bloque.lineas.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          bloque.numerada ? '${i + 1}.' : '•',
                          style: _estiloBase.copyWith(
                            color: AppColors.primarioClaro,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Expanded(child: Text.rich(_linea(item, _estiloBase))),
                    ],
                  ),
                ),
            ],
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    _soltar();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final bloque in interpretarMarkdown(widget.markdown))
          _bloque(bloque),
      ],
    );
  }
}
