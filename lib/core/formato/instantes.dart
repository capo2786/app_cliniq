// lib/core/formato/instantes.dart

import '../fechas/instante.dart';
import 'fechas.dart';

/*
 * Cómo se enseñan los instantes reales de la API (mensajes, consultas en
 * línea, tickets de soporte): siempre en la hora de la clínica.
 */

/// «Lunes 28 de septiembre, 14:00»: un instante de la API en la hora de la
/// clínica.
String momentoLegible(DateTime instante) {
  final local = enHoraDeLaClinica(instante);
  return '${FormatoFecha.diaLargo(local)}, ${FormatoFecha.hora(local)}';
}

/// «28/09/2026 · 14:00», para los sellos de los mensajes.
String selloLegible(DateTime instante) =>
    FormatoFecha.cortaConHora(enHoraDeLaClinica(instante));
