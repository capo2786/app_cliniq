// lib/features/avisos/providers/campana_cubit.dart

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/avisos_service.dart';
import '../dominio/avisos.dart';

class CampanaState extends Equatable {
  /// El menú de la aplicación trae la campana (`/notificaciones`).
  final bool activa;

  /// Cuántos avisos quedan sin leer, según la última respuesta.
  final int noLeidos;

  const CampanaState({this.activa = false, this.noLeidos = 0});

  @override
  List<Object?> get props => [activa, noLeidos];
}

/// La campana de la cabecera: cuántos avisos quedan sin leer.
///
/// Es administrable: solo existe si el menú de la aplicación de la persona
/// trae un enlace a `/notificaciones` (el tablero la enciende o la apaga con
/// [activar]). Encendida, pregunta al entrar, al volver a primer plano
/// ([reanudar]) y cada [intervaloCampana] mientras la aplicación está
/// abierta; en segundo plano no pregunta ([pausar]).
///
/// El contador nunca rompe la cabecera: si el servidor no responde, se queda
/// el último número conocido.
class CampanaCubit extends Cubit<CampanaState> {
  final AvisosService _servicio;

  /// Los latidos que marcan cada pregunta. En las pruebas, un
  /// `StreamController`: así no hay que esperar un minuto de verdad.
  final Stream<void> Function() _latidos;

  StreamSubscription<void>? _suscripcion;
  Future<void>? _enCurso;

  CampanaCubit(this._servicio, {Stream<void> Function()? latidos})
    : _latidos = latidos ?? (() => Stream<void>.periodic(intervaloCampana)),
      super(const CampanaState());

  /// Enciende o apaga la campana, según lo que diga el menú. Apagada se
  /// olvida el contador (también al cerrar sesión).
  void activar(bool activa) {
    if (activa == state.activa) return;

    if (!activa) {
      _detener();
      emit(const CampanaState());
      return;
    }

    emit(const CampanaState(activa: true));
    reanudar();
  }

  /// Pregunta ya y vuelve a preguntar cada intervalo. Al entrar y al volver
  /// a primer plano.
  void reanudar() {
    if (!state.activa || isClosed) return;

    _detener();
    _suscripcion = _latidos().listen((_) => unawaited(refrescar()));
    unawaited(refrescar());
  }

  /// La aplicación pasó a segundo plano: deja de preguntar.
  void pausar() => _detener();

  /// Pregunta cuántos quedan sin leer. Dos pedidos a la vez son uno.
  Future<void> refrescar() =>
      _enCurso ??= _contar().whenComplete(() => _enCurso = null);

  Future<void> _contar() async {
    if (!state.activa) return;

    try {
      final total = await _servicio.contarNoLeidas();
      if (isClosed || !state.activa) return;

      emit(CampanaState(activa: true, noLeidos: total));
    } catch (_) {
      // Se queda el último número: la campana no se cae por un aviso.
    }
  }

  /// Se leyeron o se borraron [cuantos] avisos sin leer en la lista.
  void descontar([int cuantos = 1]) {
    if (!state.activa) return;

    final quedan = state.noLeidos - cuantos;
    emit(CampanaState(activa: true, noLeidos: quedan < 0 ? 0 : quedan));
  }

  /// Se marcaron todos como leídos.
  void ponerEnCero() {
    if (!state.activa) return;

    emit(const CampanaState(activa: true));
  }

  void _detener() {
    unawaited(_suscripcion?.cancel());
    _suscripcion = null;
  }

  @override
  Future<void> close() {
    _detener();
    return super.close();
  }
}
