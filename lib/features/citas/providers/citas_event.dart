import 'package:equatable/equatable.dart';

import '../data/models/cita.dart';

sealed class CitasEvent extends Equatable {
  const CitasEvent();

  @override
  List<Object?> get props => [];
}

/// Traer las citas de esta persona (y de sus dependientes).
class CitasSolicitadas extends CitasEvent {
  final String uid;

  const CitasSolicitadas(this.uid);

  @override
  List<Object?> get props => [uid];
}

/// Cancelar una cita con un motivo del catálogo y, si se quiere, un detalle.
class CitaCancelacionSolicitada extends CitasEvent {
  final Cita cita;
  final String motivo;
  final String? detalle;

  const CitaCancelacionSolicitada({
    required this.cita,
    required this.motivo,
    this.detalle,
  });

  @override
  List<Object?> get props => [cita, motivo, detalle];
}

/// Una cita cambió en otra pantalla (se reprogramó o se agendó).
class CitaActualizada extends CitasEvent {
  final Cita cita;

  const CitaActualizada(this.cita);

  @override
  List<Object?> get props => [cita];
}

/// Se cerró la sesión: fuera todo lo de la persona anterior.
class CitasVaciadas extends CitasEvent {
  const CitasVaciadas();
}

/// Cambió la configuración de la clínica o sus catálogos: los recordatorios
/// se vuelven a programar (o se cancelan, si la clínica los apagó).
class CitasRecordatoriosRevisados extends CitasEvent {
  const CitasRecordatoriosRevisados();
}
