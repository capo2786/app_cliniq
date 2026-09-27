// lib/core/fechas/fecha_local.dart

/// Las fechas de la API, leídas y escritas como hora local de la clínica.
///
/// La API guarda la hora local de la clínica «congelada» como si fuera UTC:
/// las 09:00 de Quito se guardan `2026-09-28T09:00:00.000Z`. Si se leyera esa
/// cadena como un instante de verdad, `DateTime.parse` la movería cinco horas
/// y la cita de las nueve aparecería a las cuatro de la madrugada. Por eso
/// aquí **se descarta la zona y nunca se convierte**: la cadena dice las
/// 09:00 y la aplicación enseña las 09:00.
///
/// Al escribir pasa lo mismo al revés: se manda `2026-09-28T09:00:00`, sin
/// `Z` ni desfase, que es exactamente lo que la API exige.
///
/// Todo el código de la aplicación pasa por este archivo. Un
/// `DateTime.parse` suelto sobre una fecha de la API es un error, aunque
/// parezca funcionar en un teléfono configurado en UTC.
library;

import 'zona_clinica.dart';

final RegExp _fechaConHora = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2})'
  r'(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?(?:\.\d{1,9})?)?'
  r'(?:Z|z|[+-]\d{2}(?::?\d{2})?)?$',
);

/// Lee una fecha de la API como hora local, o `null` si no es una fecha real.
///
/// Acepta la forma estricta (`2026-09-28T09:00:00`), la que devuelve Mongo
/// (`…09:00:00.000Z`), una con desfase (`…09:00:00-05:00`) y una fecha sola
/// (`2026-09-28`, que queda a medianoche). En todas se ignora la zona.
///
/// Las fechas imposibles —el 30 de febrero— devuelven `null` en vez de
/// desbordarse al mes siguiente, como haría `DateTime` por su cuenta.
DateTime? leerFechaLocal(Object? valor) {
  if (valor is DateTime) {
    return DateTime(
      valor.year,
      valor.month,
      valor.day,
      valor.hour,
      valor.minute,
      valor.second,
    );
  }

  if (valor is! String) return null;

  final coincidencia = _fechaConHora.firstMatch(valor.trim());
  if (coincidencia == null) return null;

  int parte(int grupo) => int.parse(coincidencia.group(grupo) ?? '0');

  final anio = parte(1);
  final mes = parte(2);
  final dia = parte(3);
  final hora = parte(4);
  final minuto = parte(5);
  final segundo = parte(6);

  if (hora > 23 || minuto > 59 || segundo > 59) return null;

  final fecha = DateTime(anio, mes, dia, hora, minuto, segundo);

  // DateTime desborda en silencio (30/02 → 02/03): si no coincide, no existía.
  if (fecha.year != anio || fecha.month != mes || fecha.day != dia) {
    return null;
  }

  return fecha;
}

/// Igual que [leerFechaLocal], pero para cuando la fecha tiene que estar.
///
/// Lanza [FormatException] con la cadena recibida: una cita sin fecha legible
/// no se puede pintar en ninguna parte, y es mejor saberlo al leerla.
DateTime aFechaLocal(Object? valor) {
  final fecha = leerFechaLocal(valor);

  if (fecha == null) {
    throw FormatException('Fecha de la API no válida', valor?.toString());
  }

  return fecha;
}

String _dos(int n) => n.toString().padLeft(2, '0');

/// La fecha y hora que espera la API: `2026-09-28T09:00:00`, sin zona.
String aTextoLocal(DateTime fecha) =>
    '${fechaIso(fecha)}T${_dos(fecha.hour)}:${_dos(fecha.minute)}:${_dos(fecha.second)}';

/// El día del calendario: `2026-09-28`. Para la API y como clave.
String fechaIso(DateTime fecha) =>
    '${fecha.year.toString().padLeft(4, '0')}-${_dos(fecha.month)}-${_dos(fecha.day)}';

/// Lee `AAAA-MM-DD` como medianoche local, o `null` si no es un día real.
DateTime? deFechaIso(String? valor) {
  if (valor == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(valor)) {
    return null;
  }

  return leerFechaLocal(valor);
}

/// La medianoche del mismo día.
DateTime inicioDelDia(DateTime fecha) =>
    DateTime(fecha.year, fecha.month, fecha.day);

/// Si dos fechas caen el mismo día del calendario.
bool mismoDia(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// El mismo día, `dias` después, a medianoche.
///
/// Se suma sobre el calendario y no con `Duration(days: n)`: en un teléfono
/// con horario de verano, veinticuatro horas no siempre son un día.
DateTime sumarDias(DateTime fecha, int dias) =>
    DateTime(fecha.year, fecha.month, fecha.day + dias);

/// La hora de la clínica, con el mismo criterio que las fechas de la API.
///
/// Las reglas que dependen del reloj —las horas mínimas para cambiar una
/// cita, qué horarios ya pasaron, cuánto falta— se comparan contra la hora de
/// la clínica, no contra la del teléfono: alguien de viaje con el teléfono en
/// otra zona vería citas «en el pasado» que todavía no ocurrieron. La zona es
/// la de la configuración pública (`clinica.zonaHoraria`, ver
/// [ZonaClinica]).
///
/// Se inyecta para que las pruebas fijen el «ahora».
class RelojClinica {
  final DateTime Function() _fuente;

  RelojClinica([DateTime Function()? fuente])
    : _fuente = fuente ?? DateTime.now;

  /// Un reloj detenido en una hora local de la clínica. Para las pruebas.
  factory RelojClinica.fijo(DateTime horaLocal) =>
      RelojClinica._fijo(horaLocal);

  RelojClinica._fijo(DateTime horaLocal)
    : _fuente = (() => _instanteDe(horaLocal));

  /// El instante UTC que en la clínica se lee como [horaLocal].
  static DateTime _instanteDe(DateTime horaLocal) {
    final comoUtc = DateTime.utc(
      horaLocal.year,
      horaLocal.month,
      horaLocal.day,
      horaLocal.hour,
      horaLocal.minute,
      horaLocal.second,
    );

    // Dos pasadas: el desfase de una zona con horario de verano depende del
    // instante, y la primera aproximación puede caer al otro lado del cambio.
    final aproximado = comoUtc.subtract(ZonaClinica.desfaseEn(comoUtc));
    return comoUtc.subtract(ZonaClinica.desfaseEn(aproximado));
  }

  /// La hora de la clínica ahora mismo, como fecha local sin zona.
  DateTime ahora() {
    final instante = _fuente().toUtc();
    final enClinica = instante.add(ZonaClinica.desfaseEn(instante));

    return DateTime(
      enClinica.year,
      enClinica.month,
      enClinica.day,
      enClinica.hour,
      enClinica.minute,
      enClinica.second,
    );
  }

  /// La medianoche de hoy en la clínica.
  DateTime hoy() => inicioDelDia(ahora());

  /// El instante real de ahora, en UTC.
  ///
  /// Es lo que se compara con los instantes de la API (el vencimiento de una
  /// consulta en línea, por ejemplo), que no son hora congelada. Ver
  /// `instante.dart`.
  DateTime instante() => _fuente().toUtc();
}
