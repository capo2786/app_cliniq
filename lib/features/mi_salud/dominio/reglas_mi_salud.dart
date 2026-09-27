// lib/features/mi_salud/dominio/reglas_mi_salud.dart

import '../../../core/fechas/fecha_local.dart';
import '../data/models/mi_salud.dart';

/// Semanas y días de embarazo y la fecha probable de parto.
typedef DatosGestacionales = ({int semanas, int dias, DateTime fpp});

/// Las semanas de embarazo desde la fecha de la última menstruación
/// ([fum], `AAAA-MM-DD`) y la fecha probable de parto con la regla de
/// Naegele: la FUM más los [diasGestacion] de la clínica
/// (`clinico.diasGestacion`). Es el mismo cálculo del panel.
///
/// `null` si la fecha falta o no es un día real, está en el futuro, o
/// describe un embarazo de más de cuatro semanas pasada la fecha probable
/// (casi siempre un error de tipeo).
DatosGestacionales? datosGestacionales(
  String? fum,
  int diasGestacion,
  DateTime hoy,
) {
  final inicio = deFechaIso(fum);
  if (inicio == null || diasGestacion <= 0) return null;

  // Días de calendario, sin horas: en un teléfono con horario de verano,
  // veinticuatro horas no siempre son un día.
  final base = DateTime.utc(hoy.year, hoy.month, hoy.day);
  final desde = DateTime.utc(inicio.year, inicio.month, inicio.day);
  final totalDias = base.difference(desde).inDays;

  if (totalDias < 0 || totalDias > diasGestacion + 4 * 7) return null;

  return (
    semanas: totalDias ~/ 7,
    dias: totalDias % 7,
    fpp: sumarDias(inicio, diasGestacion),
  );
}

/// «Laboratorio», «Imagen» u «Orden»: de qué es una orden. Son códigos del
/// sistema (el panel los nombra igual), no una lista de la clínica.
String nombreDelTipoDeOrden(TipoOrden tipo) => switch (tipo) {
  TipoOrden.laboratorio => 'Laboratorio',
  TipoOrden.imagen => 'Imagen',
  TipoOrden.otro => 'Orden',
};

/// «1 examen», «3 exámenes».
String examenes(int cantidad) =>
    cantidad == 1 ? '1 examen' : '$cantidad exámenes';

/// «1 medicamento», «2 medicamentos».
String medicamentos(int cantidad) =>
    cantidad == 1 ? '1 medicamento' : '$cantidad medicamentos';

/// Un número como se escribe en español: «25,7», «70».
String numeroLegible(num valor) {
  if (valor == valor.roundToDouble()) return valor.round().toString();

  final texto = valor.toStringAsFixed(1);
  return texto.replaceAll('.', ',');
}

/// «150/95»; con uno solo de los dos, ese.
String? presionLegible(num? sistolica, num? diastolica) {
  if (sistolica == null && diastolica == null) return null;
  if (sistolica == null || diastolica == null) {
    return numeroLegible((sistolica ?? diastolica)!);
  }

  return '${numeroLegible(sistolica)}/${numeroLegible(diastolica)}';
}
