// lib/features/ayuda/presentacion/widgets/markdown_nativo.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/tema/tokens.dart';
import '../../dominio/markdown.dart';

/// El contenido de un artículo de ayuda, pintado con widgets: títulos,
/// párrafos, listas, negrita y enlaces que se tocan.
///
/// No hay vista web ni HTML: el Markdown se lee en bloques (ver
/// `interpretarMarkdown`) y cada uno es un `Text` de la aplicación, con su
/// tipografía y sus colores.
class MarkdownNativo extends StatefulWidget {
  final String markdown;

  /// Qué hacer al tocar un enlace (ya filtrado: http, https, mailto o una
  /// ruta interna).
  final void Function(String url) alTocarEnlace;

  const MarkdownNativo({
    super.key,
    required this.markdown,
    required this.alTocarEnlace,
  });

  @override
  State<MarkdownNativo> createState() => _MarkdownNativoState();
}

class _MarkdownNativoState extends State<MarkdownNativo> {
  late List<BloqueMarkdown> _bloques = interpretarMarkdown(widget.markdown);

  /// Los que escuchan los toques de los enlaces: se crean en cada pintada y
  /// se sueltan en la siguiente (y al salir).
  final List<TapGestureRecognizer> _reconocedores = [];

  @override
  void didUpdateWidget(MarkdownNativo anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.markdown != widget.markdown) {
      _bloques = interpretarMarkdown(widget.markdown);
    }
  }

  @override
  void dispose() {
    _soltarReconocedores();
    super.dispose();
  }

  void _soltarReconocedores() {
    for (final reconocedor in _reconocedores) {
      reconocedor.dispose();
    }
    _reconocedores.clear();
  }

  static const TextStyle _texto = TextStyle(
    color: AppColors.textoSuave,
    fontSize: 14.5,
    height: 1.5,
  );

  List<InlineSpan> _tramos(LineaMarkdown linea) => [
    for (final tramo in linea) _tramo(tramo),
  ];

  InlineSpan _tramo(TramoMarkdown tramo) {
    final enlace = tramo.enlace;
    final negrita = tramo.negrita
        ? const TextStyle(fontWeight: FontWeight.w800, color: AppColors.texto)
        : null;

    if (enlace == null) return TextSpan(text: tramo.texto, style: negrita);

    final reconocedor = TapGestureRecognizer()
      ..onTap = () => widget.alTocarEnlace(enlace);
    _reconocedores.add(reconocedor);

    return TextSpan(
      text: tramo.texto,
      recognizer: reconocedor,
      style: (negrita ?? const TextStyle()).copyWith(
        color: AppColors.acentoClaro,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
        decorationColor: AppColors.acentoClaro,
      ),
    );
  }

  Widget _bloque(BloqueMarkdown bloque) => switch (bloque) {
    TituloMarkdown(:final nivel, :final linea) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text.rich(
        TextSpan(children: _tramos(linea)),
        style: TextStyle(
          color: AppColors.texto,
          fontSize: switch (nivel) {
            1 => 18,
            2 => 16.5,
            _ => 15,
          },
          fontWeight: FontWeight.w900,
          height: 1.3,
        ),
      ),
    ),
    ParrafoMarkdown(:final lineas) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text.rich(
        TextSpan(
          children: [
            for (final (i, linea) in lineas.indexed) ...[
              if (i > 0) const TextSpan(text: '\n'),
              ..._tramos(linea),
            ],
          ],
        ),
        style: _texto,
      ),
    ),
    ListaMarkdown(:final numerada, :final items) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, item) in items.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      numerada ? '${i + 1}.' : '•',
                      style: _texto.copyWith(
                        color: AppColors.acentoClaro,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: _tramos(item)),
                      style: _texto,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  };

  @override
  Widget build(BuildContext context) {
    _soltarReconocedores();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final bloque in _bloques) _bloque(bloque)],
    );
  }
}
