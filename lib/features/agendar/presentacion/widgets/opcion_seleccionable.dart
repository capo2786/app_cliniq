import 'package:flutter/material.dart';

import '../../../../core/tema/tokens.dart';

/// Una opción de una lista que se elige tocándola: quién, qué modalidad.
///
/// La elegida se marca con el borde terracota y un círculo lleno; las demás
/// quedan translúcidas. Es la misma pieza en todos los pasos para que elegir
/// se aprenda una vez.
class OpcionSeleccionable extends StatelessWidget {
  final String titulo;
  final String? descripcion;
  final IconData icono;

  /// Sin él, el de la marca (primarioClaro).
  final Color? color;
  final bool elegida;
  final VoidCallback? onTap;
  final Widget? extra;

  const OpcionSeleccionable({
    super.key,
    required this.titulo,
    required this.icono,
    required this.elegida,
    required this.onTap,
    this.descripcion,
    this.color,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? AppColors.primarioClaro;
    return Semantics(
      button: true,
      selected: elegida,
      label: titulo,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: elegida
                  ? AppColors.acento.withValues(alpha: 0.12)
                  : AppColors.tarjetaPlana,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: elegida ? AppColors.acentoClaro : AppColors.bordeCampo,
                width: elegida ? 1.8 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icono, color: color, size: 23),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (descripcion != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          descripcion!,
                          style: const TextStyle(
                            color: AppColors.textoSecundario,
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (extra != null) ...[const SizedBox(height: 8), extra!],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  elegida
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: elegida ? AppColors.acentoClaro : AppColors.textoTenue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
