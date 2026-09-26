import 'package:equatable/equatable.dart';

import '../../citas/data/models/cita.dart';
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

class AgendarFiltrosCambiados extends AgendarEvent {
  final String? especialidad;
  final String? ciudad;

  /// `null` deja la modalidad como estaba; usa [quitarModalidad] para
  /// volver a «cualquiera».
  final TipoCita? modalidad;
  final bool quitarModalidad;

  const AgendarFiltrosCambiados({
    this.especialidad,
    this.ciudad,
    this.modalidad,
    this.quitarModalidad = false,
  });

  @override
  List<Object?> get props => [especialidad, ciudad, modalidad, quitarModalidad];
}

class AgendarMedicoElegido extends AgendarEvent {
  final String uid;

  const AgendarMedicoElegido(this.uid);

  @override
  List<Object?> get props => [uid];
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

class AgendarOcupadosReintentados extends AgendarEvent {
  const AgendarOcupadosReintentados();
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
