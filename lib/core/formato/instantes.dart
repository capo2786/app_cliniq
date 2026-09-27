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

/// Hace cuánto pasó un instante, en palabras: «hace un momento», «hace 5
/// min», «hace 3 h», «ayer», «hace 4 días» y, más atrás, «28 sep 2026».
/// Los días se cuentan en el calendario de la clínica.
String haceCuanto(DateTime instante, DateTime ahora) {
  final pasado = ahora.toUtc().difference(instante.toUtc());

  if (pasado.inMinutes < 1) return 'hace un momento';
  if (pasado.inHours < 1) return 'hace ${pasado.inMinutes} min';

  final dia = enHoraDeLaClinica(instante);
  final hoy = enHoraDeLaClinica(ahora);
  final dias = DateTime.utc(
    hoy.year,
    hoy.month,
    hoy.day,
  ).difference(DateTime.utc(dia.year, dia.month, dia.day)).inDays;

  if (dias <= 0) return 'hace ${pasado.inHours} h';
  if (dias == 1) return 'ayer';
  if (dias < 7) return 'hace $dias días';

  return FormatoFecha.fechaMedia(dia);
}
