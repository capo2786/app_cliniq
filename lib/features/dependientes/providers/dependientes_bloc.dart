import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/dependientes_service.dart';
import '../data/models/dependiente.dart';

// ── Eventos ──────────────────────────────────────────────────────────

sealed class DependientesEvent extends Equatable {
  const DependientesEvent();

  @override
  List<Object?> get props => [];
}

class DependientesSolicitados extends DependientesEvent {
  final String uid;

  const DependientesSolicitados(this.uid);

  @override
  List<Object?> get props => [uid];
}

/// Crear (sin `id`) o editar (con `id`) un dependiente.
class DependienteGuardado extends DependientesEvent {
  final String? id;
  final DatosDependiente datos;

  const DependienteGuardado({this.id, required this.datos});

  @override
  List<Object?> get props => [id, datos];
}

class DependienteEliminado extends DependientesEvent {
  final Dependiente dependiente;

  const DependienteEliminado(this.dependiente);

  @override
  List<Object?> get props => [dependiente];
}

class DependientesVaciados extends DependientesEvent {
  const DependientesVaciados();
}

// ── Estado ───────────────────────────────────────────────────────────

enum CargaDependientes { inicial, cargando, lista, error }

/// Cómo terminó el último guardado o borrado.
class OperacionDependiente extends Equatable {
  final bool exito;
  final String mensaje;

  /// El dependiente guardado, para quien lo creó desde otra pantalla (el
  /// paso «para quién» del agendamiento lo elige al volver).
  final Dependiente? guardado;

  final int secuencia;

  const OperacionDependiente({
    required this.exito,
    required this.mensaje,
    required this.secuencia,
    this.guardado,
  });

  @override
  List<Object?> get props => [exito, mensaje, guardado, secuencia];
}

class DependientesState extends Equatable {
  final CargaDependientes carga;
  final List<Dependiente> lista;
  final bool desdeCache;
  final String? error;
  final bool guardando;
  final OperacionDependiente? operacion;

  const DependientesState({
    this.carga = CargaDependientes.inicial,
    this.lista = const [],
    this.desdeCache = false,
    this.error,
    this.guardando = false,
    this.operacion,
  });

  DependientesState copiarCon({
    CargaDependientes? carga,
    List<Dependiente>? lista,
    bool? desdeCache,
    String? error,
    bool limpiarError = false,
    bool? guardando,
    OperacionDependiente? operacion,
  }) {
    return DependientesState(
      carga: carga ?? this.carga,
      lista: lista ?? this.lista,
      desdeCache: desdeCache ?? this.desdeCache,
      error: limpiarError ? null : (error ?? this.error),
      guardando: guardando ?? this.guardando,
      operacion: operacion ?? this.operacion,
    );
  }

  @override
  List<Object?> get props => [
    carga,
    lista,
    desdeCache,
    error,
    guardando,
    operacion,
  ];
}

// ── Bloc ─────────────────────────────────────────────────────────────

/// Los dependientes del titular: listar, crear, editar y quitar.
class DependientesBloc extends Bloc<DependientesEvent, DependientesState> {
  final DependientesService _servicio;

  String? _uid;
  int _secuencia = 0;

  DependientesBloc(this._servicio) : super(const DependientesState()) {
    on<DependientesSolicitados>(_alSolicitar);
    on<DependienteGuardado>(_alGuardar);
    on<DependienteEliminado>(_alEliminar);
    on<DependientesVaciados>((event, emit) {
      _uid = null;
      emit(const DependientesState());
    });
  }

  Future<void> _alSolicitar(
    DependientesSolicitados event,
    Emitter<DependientesState> emit,
  ) async {
    _uid = event.uid;
    emit(
      state.copiarCon(carga: CargaDependientes.cargando, limpiarError: true),
    );

    try {
      final resultado = await _servicio.listar(event.uid);

      emit(
        state.copiarCon(
          carga: CargaDependientes.lista,
          lista: resultado.lista,
          desdeCache: resultado.desdeCache,
          limpiarError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copiarCon(
          carga: state.lista.isEmpty
              ? CargaDependientes.error
              : CargaDependientes.lista,
          error: mensajeDeError(error),
        ),
      );
    }
  }

  Future<void> _alGuardar(
    DependienteGuardado event,
    Emitter<DependientesState> emit,
  ) async {
    if (state.guardando) return;

    emit(state.copiarCon(guardando: true));

    try {
      final id = event.id;
      final guardado = id == null
          ? await _servicio.crear(event.datos)
          : await _servicio.actualizar(id, event.datos);

      final lista =
          [
            for (final d in state.lista)
              if (d.uid != guardado.uid) d,
            guardado,
          ]..sort(
            (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
          );

      emit(
        state.copiarCon(
          guardando: false,
          lista: lista,
          operacion: OperacionDependiente(
            exito: true,
            mensaje: id == null
                ? 'Dependiente registrado.'
                : 'Datos actualizados.',
            guardado: guardado,
            secuencia: ++_secuencia,
          ),
        ),
      );
    } catch (error) {
      emit(
        state.copiarCon(
          guardando: false,
          operacion: OperacionDependiente(
            exito: false,
            mensaje: mensajeDeError(
              error,
              generico: 'No se pudo guardar. Intenta de nuevo.',
            ),
            secuencia: ++_secuencia,
          ),
        ),
      );
    }
  }

  Future<void> _alEliminar(
    DependienteEliminado event,
    Emitter<DependientesState> emit,
  ) async {
    if (state.guardando) return;

    emit(state.copiarCon(guardando: true));

    try {
      await _servicio.eliminar(event.dependiente.uid);

      emit(
        state.copiarCon(
          guardando: false,
          lista: [
            for (final d in state.lista)
              if (d.uid != event.dependiente.uid) d,
          ],
          operacion: OperacionDependiente(
            exito: true,
            mensaje: '${event.dependiente.nombre} ya no aparece en tu cuenta.',
            secuencia: ++_secuencia,
          ),
        ),
      );
    } catch (error) {
      // 409: tiene citas pendientes. El servidor explica qué hacer.
      emit(
        state.copiarCon(
          guardando: false,
          operacion: OperacionDependiente(
            exito: false,
            mensaje: mensajeDeError(
              error,
              generico: 'No se pudo quitar. Intenta de nuevo.',
            ),
            secuencia: ++_secuencia,
          ),
        ),
      );
    }

    final uid = _uid;
    if (uid != null && state.operacion?.exito == false) {
      add(DependientesSolicitados(uid));
    }
  }
}
