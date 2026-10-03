// lib/features/mediciones/providers/tendencias_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/mediciones_service.dart';
import '../data/models/medicion.dart';
import '../dominio/tendencias.dart';

class TendenciasState extends Equatable {
  final PeriodoTendencia periodo;
  final bool cargando;

  /// Las del periodo, del servidor; `null` si no se pudieron pedir (sin
  /// red): entonces la pantalla usa lo que ya tiene en «Registro».
  final List<Medicion>? mediciones;

  /// El periodo tenía más mediciones de las que se pidieron.
  final bool incompleto;

  const TendenciasState({
    this.periodo = PeriodoTendencia.mes,
    this.cargando = false,
    this.mediciones,
    this.incompleto = false,
  });

  @override
  List<Object?> get props => [periodo, cargando, mediciones, incompleto];
}

/// Las tendencias de una persona: pide al servidor las mediciones del
/// periodo elegido (7 días, 30 días o 3 meses) cada vez que cambia.
class TendenciasCubit extends Cubit<TendenciasState> {
  final MedicionesService _servicio;
  final String _uid;
  final String? _pacienteId;
  final DateTime Function() _ahora;
  int _secuencia = 0;

  TendenciasCubit({
    required this._servicio,
    required this._uid,
    this._pacienteId,
    required this._ahora,
  }) : super(const TendenciasState());

  DateTime get ahora => _ahora();

  Future<void> cargar([PeriodoTendencia? periodo]) async {
    final elegido = periodo ?? state.periodo;
    final secuencia = ++_secuencia;
    emit(
      TendenciasState(
        periodo: elegido,
        cargando: true,
        mediciones: elegido == state.periodo ? state.mediciones : null,
      ),
    );
    try {
      final r = await _servicio.delPeriodo(
        _uid,
        pacienteId: _pacienteId,
        desde: elegido.desde(_ahora()),
      );
      if (isClosed || secuencia != _secuencia) return;
      emit(
        TendenciasState(
          periodo: elegido,
          mediciones: r.mediciones,
          incompleto: !r.completo,
        ),
      );
    } catch (_) {
      if (isClosed || secuencia != _secuencia) return;
      emit(TendenciasState(periodo: elegido));
    }
  }
}
