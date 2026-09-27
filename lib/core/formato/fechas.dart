// lib/core/formato/fechas.dart

import '../fechas/fecha_local.dart';
import '../fechas/instante.dart';

/// Cómo se enseñan las fechas en Cliniq, en español.
///
/// Todo pasa por aquí y no por formatos sueltos en cada pantalla. Los nombres
/// de días y meses van en una tabla propia y no en `DateFormat('…', 'es')`:
/// las abreviaturas del locale cambian entre versiones de los datos de idioma
/// («sep» pasó a «sept.», con punto), y en una tira de días o en una hoja de
/// calendario eso descuadra el diseño. Una sola tabla, aquí, se escribe una
/// vez y se lee igual en todas las pantallas.
///
/// Las horas van en veinticuatro horas, como en el panel web: «09:30» ocupa
/// siempre lo mismo y no deja dudas entre la mañana y la noche.
class FormatoFecha {
  const FormatoFecha._();

  static const List<String> _dias = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static const List<String> _diasCortos = [
    'lun',
    'mar',
    'mié',
    'jue',
    'vie',
    'sáb',
    'dom',
  ];

  static const List<String> _meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static const List<String> _mesesCortos = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  static String _dos(int n) => n.toString().padLeft(2, '0');

  /// «lunes»
  static String nombreDia(DateTime f) => _dias[f.weekday - 1];

  /// «Lun»
  static String diaCorto(DateTime f) => capitalizar(_diasCortos[f.weekday - 1]);

  /// «SEP», para la hoja de calendario de las tarjetas.
  static String mesCortoMayusculas(DateTime f) =>
      _mesesCortos[f.month - 1].toUpperCase();

  /// «Lunes 28 de septiembre»
  static String diaLargo(DateTime f) =>
      capitalizar('${nombreDia(f)} ${f.day} de ${_meses[f.month - 1]}');

  /// «Lunes 28 de septiembre de 2026»
  static String diaLargoConAnio(DateTime f) => '${diaLargo(f)} de ${f.year}';

  /// «Lun 28 sep»
  static String diaMedio(DateTime f) =>
      '${diaCorto(f)} ${f.day} ${_mesesCortos[f.month - 1]}';

  /// «28 de septiembre»
  static String diaYMes(DateTime f) => '${f.day} de ${_meses[f.month - 1]}';

  /// «28 sep»
  static String diaYMesCorto(DateTime f) =>
      '${f.day} ${_mesesCortos[f.month - 1]}';

  /// «28 sep 2026»
  static String fechaMedia(DateTime f) =>
      '${f.day} ${_mesesCortos[f.month - 1]} ${f.year}';

  /// «09:30»
  static String hora(DateTime f) => '${_dos(f.hour)}:${_dos(f.minute)}';

  /// «09:30 – 10:00»
  static String rangoHoras(DateTime inicio, DateTime fin) =>
      '${hora(inicio)} – ${hora(fin)}';

  /// «28/09/2026»
  static String corta(DateTime f) =>
      '${_dos(f.day)}/${_dos(f.month)}/${f.year}';

  /// «28/09/2026 · 09:30», para sellos de registro.
  static String cortaConHora(DateTime f) => '${corta(f)} · ${hora(f)}';

  /// La primera letra en mayúscula: el locale devuelve días y meses en
  /// minúscula, y en un título eso se lee mal.
  static String capitalizar(String texto) {
    if (texto.isEmpty) return texto;

    return texto[0].toUpperCase() + texto.substring(1);
  }
}

/// Cuánto hace que pasó un instante real (un aviso, una solicitud), como lo
/// dice el panel: «hace un momento», «hace 5 min», «hace 2 h», «ayer»,
/// «hace 3 días», y de ahí en adelante la fecha («28 sep», o «28 sep 2025»
/// si es de otro año).
///
/// [ahora] es la hora de la clínica (`RelojClinica.ahora()`): el instante se
/// pasa a esa hora y los días se cuentan en la zona de la clínica, no en la
/// del teléfono. Un reloj del servidor un poco adelantado no produce «dentro
/// de 2 min»: es «hace un momento».
String tiempoRelativo(DateTime instante, DateTime ahora) {
  final local = enHoraDeLaClinica(instante);
  final diferencia = ahora.difference(local);

  if (diferencia < const Duration(seconds: 45)) return 'hace un momento';

  if (diferencia < const Duration(hours: 1)) {
    final min = (diferencia.inSeconds / 60).round();
    return 'hace ${min < 1 ? 1 : min} min';
  }

  final dias =
      (inicioDelDia(ahora).difference(inicioDelDia(local)).inHours / 24)
          .round();

  if (dias <= 0) return 'hace ${diferencia.inHours} h';
  if (dias == 1) return 'ayer';
  if (dias < 7) return 'hace $dias días';

  return local.year == ahora.year
      ? FormatoFecha.diaYMesCorto(local)
      : FormatoFecha.fechaMedia(local);
}

/// «1 hora», «12 horas».
String horas(int cantidad) => cantidad == 1 ? '1 hora' : '$cantidad horas';

/// «1 minuto», «10 minutos».
String minutos(int cantidad) =>
    cantidad == 1 ? '1 minuto' : '$cantidad minutos';
