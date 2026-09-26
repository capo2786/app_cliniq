import '../data/models/cita.dart';

/// Horas de anticipación que exige la clínica para cancelar o reprogramar.
///
/// Es la misma regla del servidor (`HORAS_MINIMAS_CAMBIO`, 12 por defecto) y
/// del panel web. La aplicación la aplica antes para no ofrecer un botón que
/// solo llevaría a un error: el servidor la vuelve a comprobar igual.
const int horasMinimasCambio = 12;

/// La explicación que se da cuando ya no se puede cambiar una cita.
const String explicacionCambioTardio =
    'Faltan menos de $horasMinimasCambio horas para esta cita, así que ya no '
    'se puede cancelar ni reprogramar desde la aplicación. Si no puedes '
    'asistir, llama a la clínica.';

/// ¿Todavía se puede pedir el cambio? Faltan al menos 12 horas.
bool aTiempoDeCambiar(Cita cita, DateTime ahora) =>
    cita.inicio.difference(ahora) >= const Duration(hours: horasMinimasCambio);

/// Si se ofrecen «Reprogramar» y «Cancelar» para esta cita.
///
/// Solo en citas pendientes —una atendida o cancelada ya no se mueve— y con
/// las 12 horas de anticipación.
bool puedeCambiar(Cita cita, DateTime ahora) =>
    cita.pendiente && aTiempoDeCambiar(cita, ahora);

/// Por qué no se ofrecen los cambios, o `null` si se ofrecen.
String? motivoSinCambios(Cita cita, DateTime ahora) {
  if (!cita.pendiente) return null;
  if (!aTiempoDeCambiar(cita, ahora)) return explicacionCambioTardio;

  return null;
}

/// Las citas que todavía van a ocurrir: pendientes y sin terminar, de la
/// más cercana a la más lejana.
List<Cita> proximasCitas(List<Cita> citas, DateTime ahora) {
  return citas.where((c) => c.pendiente && c.fin.isAfter(ahora)).toList()
    ..sort((a, b) => a.inicio.compareTo(b.inicio));
}

/// Todo lo demás, de la más reciente a la más antigua.
List<Cita> historialDeCitas(List<Cita> citas, DateTime ahora) {
  return citas.where((c) => !(c.pendiente && c.fin.isAfter(ahora))).toList()
    ..sort((a, b) => b.inicio.compareTo(a.inicio));
}

/// La próxima cita, o `null` si no hay ninguna pendiente.
Cita? proximaCita(List<Cita> citas, DateTime ahora) {
  final proximas = proximasCitas(citas, ahora);
  return proximas.isEmpty ? null : proximas.first;
}

/// Cuánto falta, en palabras: «Faltan 2 días», «Faltan 3 h 20 min».
String cuentaRegresiva(Cita cita, DateTime ahora) {
  if (!ahora.isBefore(cita.inicio)) {
    return ahora.isBefore(cita.fin) ? 'En curso' : 'Terminó';
  }

  final falta = cita.inicio.difference(ahora);
  final dias = falta.inDays;
  final horas = falta.inHours % 24;
  final minutos = falta.inMinutes % 60;

  if (dias >= 2) return 'Faltan $dias días';
  if (dias == 1) return horas == 0 ? 'Falta 1 día' : 'Falta 1 día y $horas h';
  if (falta.inHours >= 1) {
    return minutos == 0
        ? 'Faltan ${falta.inHours} h'
        : 'Faltan ${falta.inHours} h $minutos min';
  }

  final enMinutos = falta.inMinutes < 1 ? 1 : falta.inMinutes;
  return 'Empieza en $enMinutos min';
}

/// Cómo prepararse, según la modalidad.
List<String> consejosPara(TipoCita tipo) {
  return switch (tipo) {
    TipoCita.presencial => const [
      'Llega 10 minutos antes.',
      'Trae tu cédula y tus exámenes recientes.',
    ],
    TipoCita.telemedicina => const [
      'Conéctate 5 minutos antes.',
      'Busca un lugar privado, con buena luz y buena señal.',
    ],
    TipoCita.asincrona => const [
      'Ten tus exámenes a mano, en foto o PDF.',
      'El médico los revisará y te responderá.',
    ],
  };
}
