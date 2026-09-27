// lib/core/fechas/instante.dart

/// Los instantes reales de la API: consultas en línea, mensajes y archivos.
///
/// No todas las fechas de la API son iguales. Las citas guardan la hora local
/// de la clínica «congelada» como UTC y se leen con `fecha_local.dart`, que
/// descarta la zona. Pero las consultas en línea, sus mensajes, los archivos
/// y los eventos de la videollamada son **instantes de verdad**: el
/// `2026-09-28T14:00:00.000Z` de un mensaje es el momento exacto en que se
/// escribió, y en Quito eran las 09:00.
///
/// Por eso aquí es al revés que en `fecha_local.dart`: la zona **se respeta**
/// al leer y, para enseñar, se convierte a la hora de la clínica
/// (America/Guayaquil, UTC−5 todo el año). Pasar un instante por
/// `leerFechaLocal` lo dejaría cinco horas corrido, y pasar una cita por aquí
/// también.
library;

import '../config/entorno.dart';

final RegExp _conZona = RegExp(r'(Z|z|[+-]\d{2}(:?\d{2})?)$');

/// Lee un instante de la API como `DateTime` en UTC, o `null` si no es uno.
///
/// Una cadena sin zona se toma como UTC —así escribe la API todos sus
/// instantes— y no como la hora del teléfono, que depende de dónde esté.
DateTime? leerInstante(Object? valor) {
  if (valor is DateTime) return valor.toUtc();
  if (valor is! String) return null;

  final texto = valor.trim();
  if (texto.isEmpty) return null;

  final leido = DateTime.tryParse(
    _conZona.hasMatch(texto) ? texto : '${texto}Z',
  );

  return leido?.toUtc();
}

/// El instante en la hora de la clínica, como fecha sin zona, lista para
/// `FormatoFecha`: el mensaje de las 14:00 UTC se enseña a las 09:00.
DateTime enHoraDeLaClinica(DateTime instante) {
  final enClinica = instante.toUtc().add(Entorno.desfaseClinica);

  return DateTime(
    enClinica.year,
    enClinica.month,
    enClinica.day,
    enClinica.hour,
    enClinica.minute,
    enClinica.second,
  );
}

/// Para la copia guardada en el teléfono: el mismo formato de la API, en UTC
/// y con `Z`, así se vuelve a leer igual.
String? aTextoInstante(DateTime? instante) =>
    instante?.toUtc().toIso8601String();
