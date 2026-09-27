// lib/features/agendar/dominio/reglas_agendamiento.dart

import '../../../core/configuracion/config_publica.dart';
import '../../citas/data/models/cita.dart';
import 'horarios.dart';

/// Las reglas de la rejilla de horarios, tal como las configuró la clínica
/// (`agenda.*` de la configuración pública). Son las mismas que aplica el
/// servidor al guardar; aquí sirven para no ofrecer horarios que después se
/// rechazarían.
class ReglasAgendamiento {
  /// Cada cuántos minutos empieza un horario posible (`pasoMinutos`).
  final int pasoMinutos;

  /// Anticipación mínima para tomar un horario de hoy
  /// (`minutosAnticipacionReserva`): una cita que empieza en cinco minutos no
  /// le sirve a nadie.
  final int minutosAnticipacion;

  /// Hasta cuántos días adelante se puede agendar (`diasHorizonteReserva`).
  final int diasHorizonte;

  /// Desde qué minuto del día un horario es de la tarde y de la noche
  /// (`horaInicioTarde`, `horaInicioNoche`).
  final int minutoInicioTarde;
  final int minutoInicioNoche;

  /// Minutos por modalidad si el médico no configuró los suyos
  /// (`duracionPresencial`, `duracionTelemedicina`, `duracionAsincrona`).
  final int duracionPresencial;
  final int duracionTelemedicina;
  final int duracionAsincrona;

  const ReglasAgendamiento({
    required this.pasoMinutos,
    required this.minutosAnticipacion,
    required this.diasHorizonte,
    required this.minutoInicioTarde,
    required this.minutoInicioNoche,
    required this.duracionPresencial,
    required this.duracionTelemedicina,
    required this.duracionAsincrona,
  });

  factory ReglasAgendamiento.de(ReglasAgenda agenda) => ReglasAgendamiento(
    pasoMinutos: agenda.pasoMinutos,
    minutosAnticipacion: agenda.minutosAnticipacionReserva,
    diasHorizonte: agenda.diasHorizonteReserva,
    minutoInicioTarde: aMinutos(agenda.horaInicioTarde),
    minutoInicioNoche: aMinutos(agenda.horaInicioNoche),
    duracionPresencial: agenda.duracionPresencial,
    duracionTelemedicina: agenda.duracionTelemedicina,
    duracionAsincrona: agenda.duracionAsincrona,
  );

  /// La duración de la clínica para una modalidad.
  int duracionPorDefecto(TipoCita tipo) => switch (tipo) {
    TipoCita.presencial => duracionPresencial,
    TipoCita.telemedicina => duracionTelemedicina,
    TipoCita.asincrona => duracionAsincrona,
  };

  @override
  bool operator ==(Object other) =>
      other is ReglasAgendamiento &&
      other.pasoMinutos == pasoMinutos &&
      other.minutosAnticipacion == minutosAnticipacion &&
      other.diasHorizonte == diasHorizonte &&
      other.minutoInicioTarde == minutoInicioTarde &&
      other.minutoInicioNoche == minutoInicioNoche &&
      other.duracionPresencial == duracionPresencial &&
      other.duracionTelemedicina == duracionTelemedicina &&
      other.duracionAsincrona == duracionAsincrona;

  @override
  int get hashCode => Object.hash(
    pasoMinutos,
    minutosAnticipacion,
    diasHorizonte,
    minutoInicioTarde,
    minutoInicioNoche,
    duracionPresencial,
    duracionTelemedicina,
    duracionAsincrona,
  );
}
