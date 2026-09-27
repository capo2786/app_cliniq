// lib/features/encuestas/providers/encuestas_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../citas/data/models/cita.dart';
import '../data/encuestas_service.dart';

class EncuestasState extends Equatable {
  /// Las citas por calificar, la más reciente primero.
  final List<Cita> pendientes;
  final bool cargando;

  const EncuestasState({this.pendientes = const [], this.cargando = false});

  @override
  List<Object?> get props => [pendientes, cargando];
}

/// Las encuestas por responder de quien entró: el aviso del inicio.
///
/// Se piden al entrar y al volver a la aplicación. Si no se pueden traer (ni
/// hay copia), no hay aviso: no es algo que deba estorbar.
class EncuestasCubit extends Cubit<EncuestasState> {
  final EncuestasService _servicio;

  String? _uid;

  EncuestasCubit(this._servicio) : super(const EncuestasState());

  Future<void> cargar(String uid) async {
    if (_uid != uid) {
      _uid = uid;
      emit(const EncuestasState());
    }

    emit(EncuestasState(pendientes: state.pendientes, cargando: true));

    try {
      final datos = await _servicio.pendientes(uid);
      if (isClosed || _uid != uid) return;

      emit(EncuestasState(pendientes: datos.citas));
    } catch (_) {
      if (isClosed || _uid != uid) return;

      emit(EncuestasState(pendientes: state.pendientes));
    }
  }

  /// Se respondió (o ya estaba respondida): deja de estar pendiente.
  void respondida(String citaId) {
    final quedan = [
      for (final c in state.pendientes)
        if (c.id != citaId) c,
    ];
    if (quedan.length == state.pendientes.length) return;

    emit(EncuestasState(pendientes: quedan, cargando: state.cargando));

    final uid = _uid;
    if (uid != null) _servicio.guardarCopia(uid, quedan).ignore();
  }

  /// Se cerró la sesión.
  void vaciar() {
    _uid = null;
    emit(const EncuestasState());
  }
}
