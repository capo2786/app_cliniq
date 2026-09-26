import 'package:flutter/material.dart';

/// Aparición del contenido al abrir una pantalla.
///
/// Sube un poco y se revela. Es medio segundo, pero es lo que separa una
/// pantalla que «aparece» de golpe de una que se siente construida.
class EntradaAnimada extends StatefulWidget {
  final Widget child;

  /// Cuánto esperar antes de empezar, para escalonar varias piezas.
  final Duration retraso;

  const EntradaAnimada({
    super.key,
    required this.child,
    this.retraso = Duration.zero,
  });

  @override
  State<EntradaAnimada> createState() => _EntradaAnimadaState();
}

class _EntradaAnimadaState extends State<EntradaAnimada> {
  double _avance = 0;

  @override
  void initState() {
    super.initState();

    // Un cuadro después, para que la animación arranque con la pantalla ya
    // dibujada y no se coma el primer tramo.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.retraso > Duration.zero) {
        await Future<void>.delayed(widget.retraso);
      }

      if (mounted) setState(() => _avance = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: Offset(0, (1 - _avance) * 0.06),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _avance,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
