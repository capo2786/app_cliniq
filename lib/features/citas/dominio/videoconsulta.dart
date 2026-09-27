import '../../../core/configuracion/config_publica.dart';
import '../../../core/fechas/fecha_local.dart';
import '../../../core/formato/fechas.dart';
import '../data/models/cita.dart';

/// La ventana de la sala de una videoconsulta: cuántos minutos antes del
/// inicio abre y cuántos después del fin cierra. Son los de la configuración
/// de la clínica (`telemedicina.minutosAntes` y `minutosDespues`), los mismos
/// con que el servidor decide si deja entrar. Fuera de la ventana el
/// servidor contesta 409 con su explicación, que se enseña tal cual.
class VentanaDeSala {
  final int minutosAntes;
  final int minutosDespues;

  const VentanaDeSala({
    required this.minutosAntes,
    required this.minutosDespues,
  });

  factory VentanaDeSala.de(ReglasTelemedicina reglas) => VentanaDeSala(
    minutosAntes: reglas.minutosAntes,
    minutosDespues: reglas.minutosDespues,
  );
}

/// En qué momento de su ventana está una cita.
enum EstadoSala {
  /// No es de telemedicina, o se canceló.
  noAplica,

  /// Todavía es temprano: la sala no abre hasta los minutos de antes.
  porAbrir,

  /// Se ofrece entrar.
  abierta,

  /// Ya pasó el cierre.
  cerrada,
}

/// Desde cuándo se ofrece entrar: los minutos de antes del inicio.
DateTime aperturaDeSala(Cita cita, VentanaDeSala ventana) =>
    cita.inicio.subtract(Duration(minutes: ventana.minutosAntes));

/// Hasta cuándo: los minutos de después del fin.
DateTime cierreDeSala(Cita cita, VentanaDeSala ventana) =>
    cita.fin.add(Duration(minutes: ventana.minutosDespues));

/// El estado de la sala de una cita ahora.
///
/// Las horas de la cita son hora congelada de la clínica y [ahora] también
/// (`RelojClinica.ahora()`): se comparan tal cual, sin zonas.
EstadoSala estadoDeSala(Cita cita, DateTime ahora, VentanaDeSala ventana) {
  if (cita.tipo != TipoCita.telemedicina) return EstadoSala.noAplica;
  if (cita.estado == EstadoCita.cancelada) return EstadoSala.noAplica;

  if (ahora.isBefore(aperturaDeSala(cita, ventana))) {
    return EstadoSala.porAbrir;
  }
  if (ahora.isAfter(cierreDeSala(cita, ventana))) return EstadoSala.cerrada;

  return EstadoSala.abierta;
}

/// Desde cuándo se podrá entrar, en palabras: «La sala abre a las 08:45,
/// 15 minutos antes de la cita.» Otro día, con la fecha.
String cuandoAbreLaSala(Cita cita, DateTime ahora, VentanaDeSala ventana) {
  final apertura = aperturaDeSala(cita, ventana);
  final hora = FormatoFecha.hora(apertura);

  final cuando = mismoDia(apertura, ahora)
      ? 'a las $hora'
      : mismoDia(apertura, sumarDias(ahora, 1))
      ? 'mañana a las $hora'
      : 'el ${FormatoFecha.diaLargo(apertura).toLowerCase()} a las $hora';

  final antes = ventana.minutosAntes;
  final margen = antes == 0
      ? 'a la hora de la cita'
      : antes == 1
      ? '1 minuto antes de la cita'
      : '$antes minutos antes de la cita';

  return 'La sala abre $cuando, $margen.';
}

/// El aviso de siempre antes de entrar: el navegador va a pedir permisos.
const String avisoPermisosDeVideo =
    'Se abrirá en el navegador del teléfono, que te pedirá permiso para usar '
    'la cámara y el micrófono: acéptalo para que el médico te vea y te '
    'escuche.';
