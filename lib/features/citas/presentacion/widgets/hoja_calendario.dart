import 'package:flutter/material.dart';

import '../../../../core/formato/fechas.dart';
import '../../../../core/tema/tokens.dart';

/// La hoja de calendario de una cita: mes, día y día de la semana.
///
/// Se lee antes que cualquier texto: «28 · SEP» dice cuándo sin tener que
/// leer una frase.
class HojaCalendario extends StatelessWidget {
  final DateTime fecha;
  final Color color;
  final double ancho;

  const HojaCalendario({
    super.key,
    required this.fecha,
    this.color = AppColors.acento,
    this.ancho = 62,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: color,
            child: Text(
              FormatoFecha.mesCortoMayusculas(fecha),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${fecha.day}',
              style: const TextStyle(
                color: AppColors.texto,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              FormatoFecha.diaCorto(fecha),
              style: const TextStyle(
                color: AppColors.textoSecundario,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
