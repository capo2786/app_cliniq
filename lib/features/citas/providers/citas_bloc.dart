import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/catalogos/catalogos_cubit.dart';
import '../../../core/configuracion/config_publica.dart';
import '../../../core/fechas/fecha_local.dart';
import '../../../core/network/errores.dart';
import '../../../core/notificaciones/recordatorios_citas.dart';
import '../../agendar/data/portal_service.dart';
import '../data/citas_service.dart';
import '../data/models/cita.dart';
import 'citas_event.dart';
import 'citas_state.dart';

/// Las citas del paciente: cargar, cancelar y mantener los recordatorios.
///
/// Vive en la raíz de la aplicación porque la usan el inicio (la próxima
/// cita) y la pestaña de citas: las dos tienen que ver la misma lista.
///
/// Los recordatorios siguen la configuración de la clínica —cuáles suenan, o
/// ninguno— y sus textos salen de los catálogos: por eso lee los dos cada vez
/// que los programa.
class CitasBloc extends Bloc<CitasEvent, CitasState> {
  final CitasService _citas;
  final PortalService _portal;
  final ProgramadorDeRecordatorios _recordatorios;
  final RelojClinica _reloj;
  final ConfigPublica? Function() _config;
  final CatalogosState Function() _catalogos;

  String? _uid;
  int _secuencia = 0;

  CitasBloc({
    required this._citas,
    required this._portal,
    required this._recordatorios,
    RelojClinica? reloj,
    required this._config,
    required this._catalogos,
  }) : _reloj = reloj ?? RelojClinica(),
       super(const CitasState()) {
    on<CitasSolicitadas>(_alSolicitar);
    on<CitaCancelacionSolicitada>(_alCancelar);
    on<CitaActualizada>(_alActualizar);
    on<CitasVaciadas>(_alVaciar);
    on<CitasRecordatoriosRevisados>(_alRevisarRecordatorios);
  }

  /// Programa los recordatorios de estas citas con la configuración vigente.
  /// Sin configuración todavía no se toca nada: se programan cuando llegue
  /// (ver [CitasRecordatoriosRevisados]).
  void _reprogramar(List<Cita> citas) {
    final config = _config();
    if (config == null) return;

    unawaited(
      _recordatorios.programar(
        recordatoriosPara(
          citas,
          _reloj.ahora(),
          agenda: config.agenda,
          catalogos: _catalogos(),
        ),
      ),
    );
  }

  /// Cambió la configuración o los catálogos: los recordatorios se rehacen
  /// con las citas que ya se tienen. Si la clínica los apagó, se cancelan.
  void _alRevisarRecordatorios(
    CitasRecordatoriosRevisados event,
    Emitter<CitasState> emit,
  ) {
    if (_uid == null) return;

    _reprogramar(state.citas);
  }

  Future<void> _alSolicitar(
    CitasSolicitadas event,
    Emitter<CitasState> emit,
  ) async {
    _uid = event.uid;

    // Si todavía no hay nada en pantalla, se enseña primero lo guardado:
    // abrir con las citas de ayer es mejor que abrir con una rueda.
    if (state.citas.isEmpty) {
      final guardadas = await _citas.citasGuardadas(event.uid);
      if (guardadas != null && guardadas.citas.isNotEmpty) {
        emit(
          state.copiarCon(
            citas: guardadas.citas,
            desdeCache: true,
            guardadasEn: guardadas.guardadasEn,
          ),
        );
      }
    }

    emit(state.copiarCon(carga: CargaCitas.cargando, limpiarError: true));

    try {
      final resultado = await _citas.misCitas(event.uid);
      if (_uid != event.uid) return;

      emit(
        state.copiarCon(
          carga: CargaCitas.lista,
          citas: resultado.citas,
          desdeCache: resultado.desdeCache,
          guardadasEn: resultado.guardadasEn,
          limpiarError: true,
        ),
      );

      // Cada sincronización buena reprograma los recordatorios: una cita
      // cancelada desde la clínica deja de sonar.
      if (!resultado.desdeCache) _reprogramar(resultado.citas);
    } catch (error) {
      emit(
        state.copiarCon(
          carga: state.citas.isEmpty ? CargaCitas.error : CargaCitas.lista,
          error: mensajeDeError(
            error,
            generico: 'No pudimos traer tus citas. Intenta de nuevo.',
          ),
        ),
      );
    }
  }

  Future<void> _alCancelar(
    CitaCancelacionSolicitada event,
    Emitter<CitasState> emit,
  ) async {
    if (state.cancelandoId != null) return;

    emit(state.copiarCon(cancelandoId: event.cita.id));

    try {
      await _portal.cancelar(
        event.cita.id,
        event.motivo,
        detalle: event.detalle,
      );

      final citas = [
        for (final c in state.citas)
          c.id == event.cita.id ? c.copiarCon(estado: EstadoCita.cancelada) : c,
      ];

      emit(
        state.copiarCon(
          citas: citas,
          limpiarCancelando: true,
          accion: ResultadoAccion(
            exito: true,
            mensaje: 'Cita cancelada. Le avisamos al médico.',
            secuencia: ++_secuencia,
          ),
        ),
      );

      _reprogramar(citas);

      final uid = _uid;
      if (uid != null) add(CitasSolicitadas(uid));
    } catch (error) {
      emit(
        state.copiarCon(
          limpiarCancelando: true,
          accion: ResultadoAccion(
            exito: false,
            mensaje: mensajeDeError(
              error,
              generico: 'No se pudo cancelar la cita.',
            ),
            secuencia: ++_secuencia,
          ),
        ),
      );
    }
  }

  void _alActualizar(CitaActualizada event, Emitter<CitasState> emit) {
    final existe = state.citas.any((c) => c.id == event.cita.id);
    final citas = existe
        ? [for (final c in state.citas) c.id == event.cita.id ? event.cita : c]
        : [...state.citas, event.cita];

    emit(state.copiarCon(citas: citas));

    _reprogramar(citas);

    final uid = _uid;
    if (uid != null) add(CitasSolicitadas(uid));
  }

  void _alVaciar(CitasVaciadas event, Emitter<CitasState> emit) {
    _uid = null;
    emit(const CitasState());
  }
}
