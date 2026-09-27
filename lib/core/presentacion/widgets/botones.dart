import 'package:flutter/material.dart';

import '../../tema/tokens.dart';

/// La acción principal de una pantalla.
///
/// Lleva el degradado terracota de la marca y su propia sombra de color:
/// es lo único de la pantalla que pide que se toque, y tiene que verse así.
class BotonPrincipal extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;

  /// Mientras la acción está en curso: rueda y texto de espera.
  final bool cargando;
  final String? textoCargando;

  final double alto;

  const BotonPrincipal({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.cargando = false,
    this.textoCargando,
    this.alto = 56,
  });

  @override
  Widget build(BuildContext context) {
    final activo = onPressed != null && !cargando;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: activo ? AppGradientes.accion : AppGradientes.accionApagada,
        boxShadow: activo
            ? [
                BoxShadow(
                  color: AppColors.acento.withValues(alpha: 0.34),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: SizedBox(
        width: double.infinity,
        height: alto,
        child: FilledButton(
          onPressed: activo ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white.withValues(alpha: 0.8),
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: cargando
                ? Row(
                    key: const ValueKey('cargando'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          textoCargando ?? texto,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('listo'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icono != null) ...[
                        Icon(icono, size: 21),
                        const SizedBox(width: 9),
                      ],
                      Flexible(
                        child: Text(
                          texto,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Una acción secundaria: borde fino, sin relleno.
class BotonSecundario extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;

  /// Sin él, el de la marca (primarioClaro).
  final Color? color;

  const BotonSecundario({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.primarioClaro;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icono == null ? const SizedBox.shrink() : Icon(icono, size: 19),
        label: Text(
          texto,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          disabledForegroundColor: AppColors.textoTenue,
          side: BorderSide(color: color.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
