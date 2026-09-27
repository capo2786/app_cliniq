// lib/core/presentacion/widgets/chip_opcion.dart

import 'package:flutter/material.dart';

import '../../tema/tokens.dart';

/// Una opción de una fila de chips, de las que se elige una sola: «Yo» o un
/// dependiente en Mi salud, una categoría en el centro de ayuda.
///
/// La elegida va en terracota, como la acción principal; las demás, sobre la
/// tarjeta translúcida. Mismo aspecto que los filtros de agendar.
class ChipDeOpcion extends StatelessWidget {
  final String texto;
  final bool elegido;
  final VoidCallback onTap;
  final IconData? icono;

  /// Un número a la derecha: cuántos artículos tiene la categoría.
  final int? cantidad;

  const ChipDeOpcion({
    super.key,
    required this.texto,
    required this.elegido,
    required this.onTap,
    this.icono,
    this.cantidad,
  });

  @override
  Widget build(BuildContext context) {
    final color = elegido ? Colors.white : AppColors.textoSuave;

    return ChoiceChip(
      selected: elegido,
      onSelected: (_) => onTap(),
      avatar: icono == null
          ? null
          : Icon(
              icono,
              size: 17,
              color: elegido ? Colors.white : AppColors.primarioClaro,
            ),
      label: Text(cantidad == null ? texto : '$texto  $cantidad'),
      showCheckmark: false,
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w700),
      selectedColor: AppColors.acento,
      backgroundColor: AppColors.tarjetaPlana,
      side: BorderSide(
        color: elegido ? AppColors.acentoClaro : AppColors.bordeCampo,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
