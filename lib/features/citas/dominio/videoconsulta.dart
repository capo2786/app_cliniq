import '../../../core/fechas/fecha_local.dart';
import '../../../core/formato/fechas.dart';
import '../data/models/cita.dart';

/// Minutos antes del inicio en que se abre la sala, y después del fin en que
/// se cierra: los mismos valores por defecto del servidor (`minutosAntes`,
/// `minutosDespues` de la configuración de telemedicina). El servidor es el
/// que manda —si la clínica los cambia, contesta 409 con la explicación—;
/// aquí sirven para no ofrecer un botón que solo llevaría a ese error.
const int minutosAntesDeLaSala = 15;
const int minutosDespuesDeLaSala = 60;

/// En qué momento de su sala está una cita.
enum EstadoSala {
  /// No es de telemedicina, o se canceló.
  noAplica,

  /// Todavía no abre.
  porAbrir,

  /// Se puede entrar.
  abierta,

  /// Ya cerró.
  cerrada,
}

/// Cuándo se abre la sala: 15 minutos antes del inicio.
DateTime aperturaDeSala(Cita cita) =>
    cita.inicio.subtract(const Duration(minutes: minutosAntesDeLaSala));

/// Cuándo se cierra: 60 minutos después del fin.
DateTime cierreDeSala(Cita cita) =>
    cita.fin.add(const Duration(minutes: minutosDespuesDeLaSala));

/// El estado de la sala de una cita ahora.
///
/// Las horas de la cita son hora congelada de la clínica y [ahora] también
/// (`RelojClinica.ahora()`): se comparan tal cual, sin zonas.
EstadoSala estadoDeSala(Cita cita, DateTime ahora) {
  if (cita.tipo != TipoCita.telemedicina) return EstadoSala.noAplica;
  if (cita.estado == EstadoCita.cancelada) return EstadoSala.noAplica;

  if (ahora.isBefore(aperturaDeSala(cita))) return EstadoSala.porAbrir;
  if (ahora.isAfter(cierreDeSala(cita))) return EstadoSala.cerrada;

  return EstadoSala.abierta;
}

/// Cuándo abre la sala, en palabras: «La sala se abre a las 09:45, 15
/// minutos antes de tu cita.» Otro día, con la fecha.
String cuandoAbreLaSala(Cita cita, DateTime ahora) {
  final apertura = aperturaDeSala(cita);
  final hora = FormatoFecha.hora(apertura);

  final cuando = mismoDia(apertura, ahora)
      ? 'a las $hora'
      : mismoDia(apertura, sumarDias(ahora, 1))
      ? 'mañana a las $hora'
      : 'el ${FormatoFecha.diaLargo(apertura).toLowerCase()} a las $hora';

  return 'La sala se abre $cuando, $minutosAntesDeLaSala minutos antes de '
      'tu cita.';
}

/// El aviso de siempre antes de entrar: el navegador va a pedir permisos.
const String avisoPermisosDeVideo =
    'Se abrirá en el navegador del teléfono, que te pedirá permiso para usar '
    'la cámara y el micrófono: acéptalo para que el médico te vea y te '
    'escuche.';
