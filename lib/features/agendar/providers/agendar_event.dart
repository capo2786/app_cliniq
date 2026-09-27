import 'package:equatable/equatable.dart';

import '../../citas/data/models/cita.dart';
import '../data/models/turnos.dart';
import '../dominio/huecos.dart';
import 'agendar_state.dart';

sealed class AgendarEvent extends Equatable {
  const AgendarEvent();

  @override
  List<Object?> get props => [];
}

/// Abrir el agendamiento. Con `reprogramar`, se mueve esa cita con el mismo
/// médico y la misma modalidad; con `para`, se preelige a un dependiente.
class AgendarIniciado extends AgendarEvent {
  final Cita? reprogramar;
  final String? para;

  const AgendarIniciado({this.reprogramar, this.para});

  @override
  List<Object?> get props => [reprogramar, para];
}

class AgendarParaElegido extends AgendarEvent {
  final String para;

  const AgendarParaElegido(this.para);

  @override
  List<Object?> get props => [para];
}

/// Cambió la ciudad o la modalidad: se vuelven a pedir los próximos turnos
/// con esos filtros.
class AgendarFiltrosCambiados extends AgendarEvent {
  final String? ciudad;

  /// `null` deja la modalidad como estaba; usa [quitarModalidad] para
  /// volver a «cualquiera».
  final TipoCita? modalidad;
  final bool quitarModalidad;

  const AgendarFiltrosCambiados({
    this.ciudad,
    this.modalidad,
    this.quitarModalidad = false,
  });

  @override
  List<Object?> get props => [ciudad, modalidad, quitarModalidad];
}

/// Se eligió una especialidad (la cadena vacía es «todas»): se pasa a sus
/// médicos.
class AgendarEspecialidadElegida extends AgendarEvent {
  final String especialidad;

  const AgendarEspecialidadElegida(this.especialidad);

  @override
  List<Object?> get props => [especialidad];
}

/// Lo escrito en el buscador de médicos.
class AgendarBusquedaCambiada extends AgendarEvent {
  final String texto;

  const AgendarBusquedaCambiada(this.texto);

  @override
  List<Object?> get props => [texto];
}

class AgendarMedicoElegido extends AgendarEvent {
  final String uid;

  const AgendarMedicoElegido(this.uid);

  @override
  List<Object?> get props => [uid];
}

/// «El primer turno disponible»: deja elegidos ese médico, esa modalidad y
/// ese turno, y pasa al paso siguiente. [turno] trae el `doctorId`.
class AgendarPrimerTurnoElegido extends AgendarEvent {
  final ProximoTurno turno;

  const AgendarPrimerTurnoElegido(this.turno);

  @override
  List<Object?> get props => [turno];
}

class AgendarModalidadElegida extends AgendarEvent {
  final TipoCita tipo;

  const AgendarModalidadElegida(this.tipo);

  @override
  List<Object?> get props => [tipo];
}

class AgendarFechaElegida extends AgendarEvent {
  final DateTime fecha;

  const AgendarFechaElegida(this.fecha);

  @override
  List<Object?> get props => [fecha];
}

class AgendarHuecoElegido extends AgendarEvent {
  final Hueco hueco;

  const AgendarHuecoElegido(this.hueco);

  @override
  List<Object?> get props => [hueco];
}

class AgendarMotivoCambiado extends AgendarEvent {
  final String motivo;

  const AgendarMotivoCambiado(this.motivo);

  @override
  List<Object?> get props => [motivo];
}

/// Ir a un paso concreto (atrás, o adelante si ya se puede).
class AgendarPasoCambiado extends AgendarEvent {
  final PasoAgendar paso;

  const AgendarPasoCambiado(this.paso);

  @override
  List<Object?> get props => [paso];
}

/// «Continuar»: el paso siguiente, si el actual está completo.
class AgendarContinuado extends AgendarEvent {
  const AgendarContinuado();
}

/// «Atrás»: el paso anterior.
class AgendarRetrocedido extends AgendarEvent {
  const AgendarRetrocedido();
}

class AgendarConfirmado extends AgendarEvent {
  const AgendarConfirmado();
}

/// Volver a pedir los turnos del médico después de un error.
class AgendarTurnosReintentados extends AgendarEvent {
  const AgendarTurnosReintentados();
}

/// Volver a pedir los próximos turnos después de un error.
class AgendarProximosReintentados extends AgendarEvent {
  const AgendarProximosReintentados();
}

/// Se agregó un dependiente desde el paso «para quién»: se recarga la
/// lista y, si se indica, se elige.
class AgendarDependientesRecargados extends AgendarEvent {
  final String? elegir;

  const AgendarDependientesRecargados({this.elegir});

  @override
  List<Object?> get props => [elegir];
}

/// Después del éxito: empezar otra cita desde cero.
class AgendarOtraCita extends AgendarEvent {
  const AgendarOtraCita();
}
