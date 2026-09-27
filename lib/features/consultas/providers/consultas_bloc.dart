import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/consultas_service.dart';
import '../data/models/consulta.dart';
import 'consultas_event.dart';
import 'consultas_state.dart';

/// Las consultas en línea del paciente: la lista, los borradores y lo que
/// cambia en otras pantallas.
///
/// Vive en la raíz de la aplicación, como las citas: el inicio avisa de las
/// respuestas por leer y la pantalla de consultas enseña la misma lista.
class ConsultasBloc extends Bloc<ConsultasEvent, ConsultasState> {
  final ConsultasService _servicio;

  String? _uid;
  int _secuencia = 0;

  ConsultasBloc(this._servicio) : super(const ConsultasState()) {
    on<ConsultasSolicitadas>(_alSolicitar);
    on<ConsultaActualizada>(_alActualizar);
    on<ConsultaBorradorEliminado>(_alEliminar);
    on<ConsultaQuitada>(_alQuitar);
    on<ConsultasVaciadas>(_alVaciar);
  }

  Future<void> _alSolicitar(
    ConsultasSolicitadas event,
    Emitter<ConsultasState> emit,
  ) async {
    _uid = event.uid;

    // Primero lo guardado, si todavía no hay nada en pantalla.
    if (state.consultas.isEmpty) {
      final guardadas = await _servicio.consultasGuardadas(event.uid);
      if (guardadas != null && guardadas.consultas.isNotEmpty) {
        emit(
          state.copiarCon(
            consultas: guardadas.consultas,
            desdeCache: true,
            guardadasEn: guardadas.guardadasEn,
          ),
        );
      }
    }

    emit(state.copiarCon(carga: CargaConsultas.cargando, limpiarError: true));

    try {
      final resultado = await _servicio.listar(event.uid);
      if (_uid != event.uid) return;

      emit(
        state.copiarCon(
          carga: CargaConsultas.lista,
          consultas: resultado.consultas,
          desdeCache: resultado.desdeCache,
          guardadasEn: resultado.guardadasEn,
          limpiarError: true,
        ),
      );
    } catch (error) {
      if (_uid != event.uid) return;

      emit(
        state.copiarCon(
          carga: state.consultas.isEmpty
              ? CargaConsultas.error
              : CargaConsultas.lista,
          error: mensajeDeError(
            error,
            generico: 'No pudimos traer tus consultas. Intenta de nuevo.',
          ),
        ),
      );
    }
  }

  void _alActualizar(ConsultaActualizada event, Emitter<ConsultasState> emit) {
    final nueva = event.consulta;
    final existe = state.consultas.any((c) => c.id == nueva.id);

    // Una nueva va arriba: la lista va de la más reciente a la más antigua.
    final consultas = existe
        ? [for (final c in state.consultas) c.id == nueva.id ? nueva : c]
        : [nueva, ...state.consultas];

    emit(state.copiarCon(consultas: consultas));
  }

  Future<void> _alEliminar(
    ConsultaBorradorEliminado event,
    Emitter<ConsultasState> emit,
  ) async {
    if (state.eliminandoId != null) return;
    if (event.consulta.estado != EstadoConsulta.borrador) return;

    emit(state.copiarCon(eliminandoId: event.consulta.id));

    try {
      await _servicio.eliminar(event.consulta.id);

      emit(
        state.copiarCon(
          consultas: [
            for (final c in state.consultas)
              if (c.id != event.consulta.id) c,
          ],
          limpiarEliminando: true,
          aviso: AvisoConsultas(
            exito: true,
            mensaje: 'Borrador eliminado.',
            secuencia: ++_secuencia,
          ),
        ),
      );
    } catch (error) {
      emit(
        state.copiarCon(
          limpiarEliminando: true,
          aviso: AvisoConsultas(
            exito: false,
            mensaje: mensajeDeError(
              error,
              generico: 'No se pudo eliminar el borrador.',
            ),
            secuencia: ++_secuencia,
          ),
        ),
      );
    }
  }

  void _alQuitar(ConsultaQuitada event, Emitter<ConsultasState> emit) {
    emit(
      state.copiarCon(
        consultas: [
          for (final c in state.consultas)
            if (c.id != event.id) c,
        ],
      ),
    );
  }

  void _alVaciar(ConsultasVaciadas event, Emitter<ConsultasState> emit) {
    _uid = null;
    emit(const ConsultasState());
  }
}
