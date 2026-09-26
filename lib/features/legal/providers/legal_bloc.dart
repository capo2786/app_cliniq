import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/legal_service.dart';

// ── Eventos ──────────────────────────────────────────────────────────

sealed class LegalEvent extends Equatable {
  const LegalEvent();

  @override
  List<Object?> get props => [];
}

class LegalSolicitado extends LegalEvent {
  const LegalSolicitado();
}

class LegalMarcado extends LegalEvent {
  final String clave;
  final bool aceptado;

  const LegalMarcado(this.clave, {required this.aceptado});

  @override
  List<Object?> get props => [clave, aceptado];
}

class LegalAceptado extends LegalEvent {
  const LegalAceptado();
}

// ── Estado ───────────────────────────────────────────────────────────

class LegalState extends Equatable {
  final bool cargando;
  final String? error;
  final List<DocumentoPendiente> pendientes;
  final List<AceptacionLegal> aceptaciones;

  /// Las claves que la persona ya marcó en pantalla.
  final Set<String> marcados;

  final bool enviando;

  /// Ya no queda nada pendiente: se puede seguir.
  final bool completo;

  const LegalState({
    this.cargando = true,
    this.error,
    this.pendientes = const [],
    this.aceptaciones = const [],
    this.marcados = const {},
    this.enviando = false,
    this.completo = false,
  });

  /// Se puede aceptar cuando cada documento tiene su casilla marcada.
  bool get todosMarcados =>
      pendientes.isNotEmpty &&
      pendientes.every((d) => marcados.contains(d.clave));

  LegalState copiarCon({
    bool? cargando,
    String? error,
    bool limpiarError = false,
    List<DocumentoPendiente>? pendientes,
    List<AceptacionLegal>? aceptaciones,
    Set<String>? marcados,
    bool? enviando,
    bool? completo,
  }) {
    return LegalState(
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
      pendientes: pendientes ?? this.pendientes,
      aceptaciones: aceptaciones ?? this.aceptaciones,
      marcados: marcados ?? this.marcados,
      enviando: enviando ?? this.enviando,
      completo: completo ?? this.completo,
    );
  }

  @override
  List<Object?> get props => [
    cargando,
    error,
    pendientes,
    aceptaciones,
    marcados,
    enviando,
    completo,
  ];
}

// ── Bloc ─────────────────────────────────────────────────────────────

/// La aceptación de documentos legales: una casilla por documento y un
/// solo envío con todos.
///
/// Se acepta uno por uno a propósito —no hay «aceptar todo»—: cada
/// documento tiene su botón para leerlo y su casilla, así queda claro qué se
/// está aceptando, que es de lo que va un consentimiento.
class LegalBloc extends Bloc<LegalEvent, LegalState> {
  final LegalService _servicio;

  LegalBloc(this._servicio) : super(const LegalState()) {
    on<LegalSolicitado>(_alSolicitar);
    on<LegalMarcado>(_alMarcar);
    on<LegalAceptado>(_alAceptar);
  }

  Future<void> _alSolicitar(
    LegalSolicitado event,
    Emitter<LegalState> emit,
  ) async {
    emit(state.copiarCon(cargando: true, limpiarError: true));

    try {
      final datos = await _servicio.misAceptaciones();

      emit(
        state.copiarCon(
          cargando: false,
          pendientes: datos.pendientes,
          aceptaciones: datos.aceptaciones,
          completo: datos.pendientes.isEmpty,
        ),
      );
    } catch (error) {
      emit(state.copiarCon(cargando: false, error: mensajeDeError(error)));
    }
  }

  void _alMarcar(LegalMarcado event, Emitter<LegalState> emit) {
    final marcados = {...state.marcados};

    if (event.aceptado) {
      marcados.add(event.clave);
    } else {
      marcados.remove(event.clave);
    }

    emit(state.copiarCon(marcados: marcados));
  }

  Future<void> _alAceptar(LegalAceptado event, Emitter<LegalState> emit) async {
    if (!state.todosMarcados || state.enviando) return;

    emit(state.copiarCon(enviando: true, limpiarError: true));

    try {
      final datos = await _servicio.aceptar(state.pendientes);

      emit(
        state.copiarCon(
          enviando: false,
          pendientes: datos.pendientes,
          aceptaciones: datos.aceptaciones,
          marcados: const {},
          completo: datos.pendientes.isEmpty,
        ),
      );
    } catch (error) {
      emit(
        state.copiarCon(
          enviando: false,
          error: mensajeDeError(
            error,
            generico: 'No pudimos registrar tu aceptación. Intenta de nuevo.',
          ),
        ),
      );
    }
  }
}
