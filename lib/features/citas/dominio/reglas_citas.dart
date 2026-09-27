import '../../../core/catalogos/catalogo_service.dart';
import '../../../core/catalogos/catalogos_cubit.dart';
import '../data/models/cita.dart';

/*
 * Las horas de anticipación para cancelar o reprogramar son las de la
 * configuración de la clínica (`agenda.horasMinimasCambio`), las mismas que
 * aplica el servidor. La aplicación las aplica antes para no ofrecer un botón
 * que solo llevaría a un error: el servidor las vuelve a comprobar igual.
 */

/// La explicación que se da cuando ya no se puede cambiar una cita. El
/// teléfono y el correo de la clínica se enseñan al lado (ver
/// `ContactoClinica`).
String explicacionCambioTardio(int horasMinimasCambio) =>
    'Faltan menos de ${horas(horasMinimasCambio)} para esta cita, así que ya '
    'no se puede cancelar ni reprogramar desde la aplicación. Si no puedes '
    'asistir, comunícate con la clínica.';

/// «1 hora», «12 horas».
String horas(int cantidad) => cantidad == 1 ? '1 hora' : '$cantidad horas';

/// ¿Todavía se puede pedir el cambio? Faltan al menos las horas mínimas.
bool aTiempoDeCambiar(Cita cita, DateTime ahora, int horasMinimasCambio) =>
    cita.inicio.difference(ahora) >= Duration(hours: horasMinimasCambio);

/// Si se ofrecen «Reprogramar» y «Cancelar» para esta cita.
///
/// Solo en citas pendientes —una atendida o cancelada ya no se mueve— y con
/// las horas mínimas de anticipación.
bool puedeCambiar(Cita cita, DateTime ahora, int horasMinimasCambio) =>
    cita.pendiente && aTiempoDeCambiar(cita, ahora, horasMinimasCambio);

/// Por qué no se ofrecen los cambios, o `null` si se ofrecen.
String? motivoSinCambios(Cita cita, DateTime ahora, int horasMinimasCambio) {
  if (!cita.pendiente) return null;
  if (!aTiempoDeCambiar(cita, ahora, horasMinimasCambio)) {
    return explicacionCambioTardio(horasMinimasCambio);
  }

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

/// Cómo prepararse, según la modalidad: los consejos del catálogo
/// `PREPARACION_CITA` cuyo código empieza por el de la modalidad
/// (`PRESENCIAL_1`, `PRESENCIAL_2`…), en el orden del panel. Sin consejos
/// configurados, ninguno.
List<String> consejosPara(CatalogosState catalogos, TipoCita tipo) {
  final prefijo = '${tipo.codigo}_';

  return [
    for (final item in catalogos.items(Catalogos.preparacionCita))
      if (item.codigo.toUpperCase().startsWith(prefijo)) item.nombre,
  ];
}
