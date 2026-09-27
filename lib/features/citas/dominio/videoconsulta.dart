import '../../../core/fechas/fecha_local.dart';
import '../../../core/formato/fechas.dart';
import '../data/models/cita.dart';

/// Hasta cuántos minutos antes del inicio puede abrir la clínica la sala, y
/// hasta cuántos después del fin puede cerrarla: los topes que el servidor
/// acepta en la configuración de telemedicina (`minutosAntes` de 0 a 120,
/// `minutosDespues` de 0 a 240; por defecto 15 y 60).
///
/// La aplicación no sabe qué valores eligió la clínica, así que ofrece entrar
/// en la ventana más amplia posible y deja la regla exacta al servidor: fuera
/// de la suya contesta 409 con la explicación («La sala se abre 15 minutos
/// antes de la cita»), que se enseña tal cual. Fuera de esta ventana, en
/// cambio, la sala seguro está cerrada y no se ofrece un botón que solo
/// llevaría a ese error.
const int maximoMinutosAntesDeLaSala = 120;
const int maximoMinutosDespuesDeLaSala = 240;

/// En qué momento de su ventana está una cita.
enum EstadoSala {
  /// No es de telemedicina, o se canceló.
  noAplica,

  /// Todavía es temprano: ninguna configuración la tendría abierta.
  porAbrir,

  /// Se ofrece entrar; el servidor dice si la sala ya abrió o ya cerró.
  abierta,

  /// Ya pasó: ninguna configuración la tendría abierta.
  cerrada,
}

/// Desde cuándo se ofrece entrar: 120 minutos antes del inicio, lo más
/// temprano que la clínica puede abrir la sala.
DateTime aperturaDeSala(Cita cita) =>
    cita.inicio.subtract(const Duration(minutes: maximoMinutosAntesDeLaSala));

/// Hasta cuándo: 240 minutos después del fin, lo más tarde que la clínica
/// puede cerrarla.
DateTime cierreDeSala(Cita cita) =>
    cita.fin.add(const Duration(minutes: maximoMinutosDespuesDeLaSala));

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

/// Desde cuándo se podrá intentar entrar, en palabras: «Podrás intentar
/// entrar desde las 08:00; si todavía es temprano, te diremos a qué hora
/// abre la sala.» Otro día, con la fecha.
String cuandoAbreLaSala(Cita cita, DateTime ahora) {
  final apertura = aperturaDeSala(cita);
  final hora = FormatoFecha.hora(apertura);

  final desde = mismoDia(apertura, ahora)
      ? 'desde las $hora'
      : mismoDia(apertura, sumarDias(ahora, 1))
      ? 'desde mañana a las $hora'
      : 'desde el ${FormatoFecha.diaLargo(apertura).toLowerCase()} a las '
            '$hora';

  return 'Podrás intentar entrar $desde; si todavía es temprano, te diremos '
      'a qué hora abre la sala.';
}

/// El aviso de siempre antes de entrar: el navegador va a pedir permisos.
const String avisoPermisosDeVideo =
    'Se abrirá en el navegador del teléfono, que te pedirá permiso para usar '
    'la cámara y el micrófono: acéptalo para que el médico te vea y te '
    'escuche.';
