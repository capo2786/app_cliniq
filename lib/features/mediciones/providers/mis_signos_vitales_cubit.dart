// lib/features/mediciones/providers/mis_signos_vitales_cubit.dart

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/cola_mediciones.dart';
import '../data/mediciones_service.dart';
import '../data/models/medicion.dart';

enum CargaSignos { inicial, cargando, lista, error }

class MisSignosVitalesState extends Equatable {
  final CargaSignos carga;

  /// Las del servidor, la más reciente primero.
  final List<Medicion> mediciones;

  /// Las que están en el teléfono esperando red (o que el servidor
  /// rechazó), de este paciente.
  final List<EnvioPendiente> pendientes;

  final bool hayMas;
  final int pagina;
  final String parametroPagina;
  final bool cargandoMas;

  final bool desdeCache;
  final DateTime? guardadaEn;

  /// Sin datos, en lugar de la lista; con datos, como aviso encima.
  final String? error;

  final String? eliminandoId;

  /// Un aviso de una sola vez (borrada, no se pudo borrar…).
  final ({String mensaje, bool exito, int secuencia})? aviso;

  const MisSignosVitalesState({
    this.carga = CargaSignos.inicial,
    this.mediciones = const [],
    this.pendientes = const [],
    this.hayMas = false,
    this.pagina = 1,
    this.parametroPagina = 'page',
    this.cargandoMas = false,
    this.desdeCache = false,
    this.guardadaEn,
    this.error,
    this.eliminandoId,
    this.aviso,
  });

  bool get hayAlgo => mediciones.isNotEmpty || pendientes.isNotEmpty;

  MisSignosVitalesState copiarCon({
    CargaSignos? carga,
    List<Medicion>? mediciones,
    List<EnvioPendiente>? pendientes,
    bool? hayMas,
    int? pagina,
    String? parametroPagina,
    bool? cargandoMas,
    bool? desdeCache,
    DateTime? guardadaEn,
    String? error,
    bool limpiarError = false,
    String? eliminandoId,
    bool limpiarEliminando = false,
    ({String mensaje, bool exito, int secuencia})? aviso,
  }) => MisSignosVitalesState(
    carga: carga ?? this.carga,
    mediciones: mediciones ?? this.mediciones,
    pendientes: pendientes ?? this.pendientes,
    hayMas: hayMas ?? this.hayMas,
    pagina: pagina ?? this.pagina,
    parametroPagina: parametroPagina ?? this.parametroPagina,
    cargandoMas: cargandoMas ?? this.cargandoMas,
    desdeCache: desdeCache ?? this.desdeCache,
    guardadaEn: guardadaEn ?? this.guardadaEn,
    error: limpiarError ? null : (error ?? this.error),
    eliminandoId: limpiarEliminando
        ? null
        : (eliminandoId ?? this.eliminandoId),
    aviso: aviso ?? this.aviso,
  );

  @override
  List<Object?> get props => [
    carga,
    mediciones,
    pendientes,
    hayMas,
    pagina,
    parametroPagina,
    cargandoMas,
    desdeCache,
    guardadaEn,
    error,
    eliminandoId,
    aviso,
  ];
}

/// «Mis signos vitales» de una persona: el titular o un dependiente.
///
/// Abre con la copia guardada, si hay; envía lo pendiente (si hay red) y
/// pide la lista al servidor. Escucha la cola: cuando lo pendiente sale
/// solo (volvió la red), se refresca.
class MisSignosVitalesCubit extends Cubit<MisSignosVitalesState> {
  final MedicionesService _servicio;
  final ColaMediciones _cola;
  final String _uid;

  /// El dependiente, o `null` para el titular.
  final String? _pacienteId;

  int _secuencia = 0;
  int _avisos = 0;

  /// La cola cambia por algo de esta pantalla (enviar al cargar, descartar):
  /// no hace falta volver a pedir la lista por eso.
  bool _cambioPropio = false;

  MisSignosVitalesCubit({
    required this._servicio,
    required this._cola,
    required this._uid,
    this._pacienteId,
  }) : super(const MisSignosVitalesState()) {
    _cola.cambios.addListener(_alCambiarLaCola);
  }

  bool _esDeEstePaciente(EnvioPendiente e) =>
      (e.pacienteId ?? '') == (_pacienteId ?? '');

  Future<void> _leerPendientes() async {
    final todos = await _cola.pendientes(_uid);
    if (isClosed) return;
    emit(
      state.copiarCon(
        pendientes: [
          for (final e in todos)
            if (_esDeEstePaciente(e)) e,
        ],
      ),
    );
  }

  void _alCambiarLaCola() {
    if (isClosed) return;
    if (_cambioPropio) {
      unawaited(_leerPendientes());
      return;
    }
    final antes = state.pendientes.length;
    unawaited(
      _leerPendientes().then((_) {
        // Algo salió de la cola hacia el servidor: la lista cambió.
        if (!isClosed && state.pendientes.length < antes) unawaited(cargar());
      }),
    );
  }

  Future<void> iniciar() async {
    final guardada = await _servicio.guardada(_uid, pacienteId: _pacienteId);
    if (isClosed) return;
    if (guardada != null) {
      emit(
        state.copiarCon(
          mediciones: guardada.mediciones,
          hayMas: guardada.hayMas,
          desdeCache: true,
          guardadaEn: guardada.guardadaEn,
        ),
      );
    }
    await _leerPendientes();
    await cargar();
  }

  /// Envía lo pendiente y pide la primera página.
  Future<void> cargar() async {
    final secuencia = ++_secuencia;
    emit(
      state.copiarCon(
        carga: state.mediciones.isEmpty ? CargaSignos.cargando : state.carga,
        limpiarError: true,
      ),
    );

    _cambioPropio = true;
    try {
      await _cola.enviarPendientes(_uid);
    } finally {
      _cambioPropio = false;
    }
    await _leerPendientes();
    if (secuencia != _secuencia || isClosed) return;

    try {
      final pagina = await _servicio.listar(_uid, pacienteId: _pacienteId);
      if (secuencia != _secuencia || isClosed) return;
      emit(
        state.copiarCon(
          carga: CargaSignos.lista,
          mediciones: pagina.mediciones,
          hayMas: pagina.hayMas,
          pagina: pagina.pagina,
          parametroPagina: pagina.parametroPagina,
          desdeCache: pagina.desdeCache,
          guardadaEn: pagina.guardadaEn,
          limpiarError: true,
        ),
      );
    } catch (error) {
      if (secuencia != _secuencia || isClosed) return;
      emit(
        state.copiarCon(
          carga: state.hayAlgo ? CargaSignos.lista : CargaSignos.error,
          error: mensajeDeError(
            error,
            generico: 'No pudimos cargar tus signos vitales. Intenta de nuevo.',
          ),
        ),
      );
    }
  }

  /// «Ver anteriores»: la página siguiente.
  Future<void> verMas() async {
    if (!state.hayMas || state.cargandoMas) return;
    emit(state.copiarCon(cargandoMas: true));
    try {
      final pagina = await _servicio.listar(
        _uid,
        pacienteId: _pacienteId,
        pagina: state.pagina + 1,
        parametroPagina: state.parametroPagina,
      );
      if (isClosed) return;
      final vistas = {for (final m in state.mediciones) m.id};
      emit(
        state.copiarCon(
          cargandoMas: false,
          mediciones: [
            ...state.mediciones,
            for (final m in pagina.mediciones)
              if (!vistas.contains(m.id)) m,
          ],
          hayMas: pagina.hayMas,
          pagina: pagina.pagina,
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copiarCon(
          cargandoMas: false,
          aviso: _aviso(mensajeDeError(error), exito: false),
        ),
      );
    }
  }

  ({String mensaje, bool exito, int secuencia}) _aviso(
    String mensaje, {
    required bool exito,
  }) => (mensaje: mensaje, exito: exito, secuencia: ++_avisos);

  /// Borra una medición propia que el médico no usó (el servidor lo
  /// comprueba).
  Future<void> eliminar(String id) async {
    if (state.eliminandoId != null) return;
    emit(state.copiarCon(eliminandoId: id));
    try {
      await _servicio.eliminar(id);
      if (isClosed) return;
      emit(
        state.copiarCon(
          limpiarEliminando: true,
          mediciones: [
            for (final m in state.mediciones)
              if (m.id != id) m,
          ],
          aviso: _aviso('Medición eliminada.', exito: true),
        ),
      );
    } catch (error) {
      if (isClosed) return;
      emit(
        state.copiarCon(
          limpiarEliminando: true,
          aviso: _aviso(
            mensajeDeError(error, generico: 'No pudimos eliminar la medición.'),
            exito: false,
          ),
        ),
      );
    }
  }

  /// Quita del teléfono un envío pendiente o rechazado.
  Future<void> descartarPendiente(String idLocal) async {
    _cambioPropio = true;
    try {
      await _cola.descartar(_uid, idLocal);
    } finally {
      _cambioPropio = false;
    }
    await _leerPendientes();
  }

  @override
  Future<void> close() {
    _cola.cambios.removeListener(_alCambiarLaCola);
    return super.close();
  }
}
