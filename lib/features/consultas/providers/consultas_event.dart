import 'package:equatable/equatable.dart';

import '../data/models/consulta.dart';

sealed class ConsultasEvent extends Equatable {
  const ConsultasEvent();

  @override
  List<Object?> get props => [];
}

/// Traer las consultas de esta persona (y de sus dependientes).
class ConsultasSolicitadas extends ConsultasEvent {
  final String uid;

  const ConsultasSolicitadas(this.uid);

  @override
  List<Object?> get props => [uid];
}

/// Una consulta cambió en otra pantalla (se envió, se canceló, llegó un
/// mensaje): se pone al día en la lista sin esperar a la próxima carga.
class ConsultaActualizada extends ConsultasEvent {
  final ConsultaResumen consulta;

  const ConsultaActualizada(this.consulta);

  @override
  List<Object?> get props => [consulta];
}

/// Borrar un borrador.
class ConsultaBorradorEliminado extends ConsultasEvent {
  final ConsultaResumen consulta;

  const ConsultaBorradorEliminado(this.consulta);

  @override
  List<Object?> get props => [consulta];
}

/// Un borrador se borró en otra pantalla (desde el propio formulario).
class ConsultaQuitada extends ConsultasEvent {
  final String id;

  const ConsultaQuitada(this.id);

  @override
  List<Object?> get props => [id];
}

/// Se cerró la sesión: fuera todo lo de la persona anterior.
class ConsultasVaciadas extends ConsultasEvent {
  const ConsultasVaciadas();
}
