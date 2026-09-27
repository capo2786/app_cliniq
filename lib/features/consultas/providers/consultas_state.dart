import 'package:equatable/equatable.dart';

import '../data/models/consulta.dart';

enum CargaConsultas { inicial, cargando, lista, error }

/// El resultado de una acción de la lista (borrar un borrador), para
/// avisarlo una vez. La secuencia cambia con cada acción: dos avisos iguales
/// seguidos también se ven.
class AvisoConsultas extends Equatable {
  final bool exito;
  final String mensaje;
  final int secuencia;

  const AvisoConsultas({
    required this.exito,
    required this.mensaje,
    required this.secuencia,
  });

  @override
  List<Object?> get props => [exito, mensaje, secuencia];
}

class ConsultasState extends Equatable {
  final CargaConsultas carga;
  final List<ConsultaResumen> consultas;

  /// Se enseñan las guardadas en el teléfono porque no hubo conexión.
  final bool desdeCache;
  final DateTime? guardadasEn;

  final String? error;

  /// El borrador que se está borrando, para apagar su botón.
  final String? eliminandoId;

  final AvisoConsultas? aviso;

  const ConsultasState({
    this.carga = CargaConsultas.inicial,
    this.consultas = const [],
    this.desdeCache = false,
    this.guardadasEn,
    this.error,
    this.eliminandoId,
    this.aviso,
  });

  bool get cargando => carga == CargaConsultas.cargando;

  ConsultasState copiarCon({
    CargaConsultas? carga,
    List<ConsultaResumen>? consultas,
    bool? desdeCache,
    DateTime? guardadasEn,
    String? error,
    bool limpiarError = false,
    String? eliminandoId,
    bool limpiarEliminando = false,
    AvisoConsultas? aviso,
  }) {
    return ConsultasState(
      carga: carga ?? this.carga,
      consultas: consultas ?? this.consultas,
      desdeCache: desdeCache ?? this.desdeCache,
      guardadasEn: guardadasEn ?? this.guardadasEn,
      error: limpiarError ? null : (error ?? this.error),
      eliminandoId: limpiarEliminando
          ? null
          : (eliminandoId ?? this.eliminandoId),
      aviso: aviso ?? this.aviso,
    );
  }

  @override
  List<Object?> get props => [
    carga,
    consultas,
    desdeCache,
    guardadasEn,
    error,
    eliminandoId,
    aviso,
  ];
}
