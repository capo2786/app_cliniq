import 'package:equatable/equatable.dart';

import '../data/models/cita.dart';

enum CargaCitas { inicial, cargando, lista, error }

/// El resultado de una acción (cancelar), para que la pantalla lo avise una
/// vez. La secuencia cambia con cada acción: dos avisos iguales seguidos
/// también se ven.
class ResultadoAccion extends Equatable {
  final bool exito;
  final String mensaje;
  final int secuencia;

  const ResultadoAccion({
    required this.exito,
    required this.mensaje,
    required this.secuencia,
  });

  @override
  List<Object?> get props => [exito, mensaje, secuencia];
}

class CitasState extends Equatable {
  final CargaCitas carga;
  final List<Cita> citas;

  /// Se enseñan las guardadas en el teléfono porque no hubo conexión.
  final bool desdeCache;
  final DateTime? guardadasEn;

  final String? error;

  /// La cita que se está cancelando, para apagar sus botones.
  final String? cancelandoId;

  final ResultadoAccion? accion;

  const CitasState({
    this.carga = CargaCitas.inicial,
    this.citas = const [],
    this.desdeCache = false,
    this.guardadasEn,
    this.error,
    this.cancelandoId,
    this.accion,
  });

  bool get cargando => carga == CargaCitas.cargando;

  CitasState copiarCon({
    CargaCitas? carga,
    List<Cita>? citas,
    bool? desdeCache,
    DateTime? guardadasEn,
    String? error,
    bool limpiarError = false,
    String? cancelandoId,
    bool limpiarCancelando = false,
    ResultadoAccion? accion,
  }) {
    return CitasState(
      carga: carga ?? this.carga,
      citas: citas ?? this.citas,
      desdeCache: desdeCache ?? this.desdeCache,
      guardadasEn: guardadasEn ?? this.guardadasEn,
      error: limpiarError ? null : (error ?? this.error),
      cancelandoId: limpiarCancelando
          ? null
          : (cancelandoId ?? this.cancelandoId),
      accion: accion ?? this.accion,
    );
  }

  @override
  List<Object?> get props => [
    carga,
    citas,
    desdeCache,
    guardadasEn,
    error,
    cancelandoId,
    accion,
  ];
}
