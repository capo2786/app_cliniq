// lib/features/soporte/providers/soporte_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/models/ticket.dart';
import '../data/soporte_service.dart';
import '../dominio/reglas_soporte.dart';

enum CargaTickets { inicial, cargando, lista, error }

class SoporteState extends Equatable {
  final CargaTickets carga;

  /// Los abiertos primero, lo más reciente arriba.
  final List<Ticket> tickets;

  final bool desdeCache;
  final DateTime? guardadosEn;

  /// Sin tickets, en lugar de la lista; con ellos, como aviso encima.
  final String? error;

  final bool refrescando;

  const SoporteState({
    this.carga = CargaTickets.inicial,
    this.tickets = const [],
    this.desdeCache = false,
    this.guardadosEn,
    this.error,
    this.refrescando = false,
  });

  SoporteState copiarCon({
    CargaTickets? carga,
    List<Ticket>? tickets,
    bool? desdeCache,
    DateTime? guardadosEn,
    String? error,
    bool limpiarError = false,
    bool? refrescando,
  }) {
    return SoporteState(
      carga: carga ?? this.carga,
      tickets: tickets ?? this.tickets,
      desdeCache: desdeCache ?? this.desdeCache,
      guardadosEn: guardadosEn ?? this.guardadosEn,
      error: limpiarError ? null : (error ?? this.error),
      refrescando: refrescando ?? this.refrescando,
    );
  }

  @override
  List<Object?> get props => [
    carga,
    tickets,
    desdeCache,
    guardadosEn,
    error,
    refrescando,
  ];
}

/// Mis tickets de soporte.
///
/// Abre con la copia guardada, si hay, y enseguida pregunta al servidor.
/// Un ticket que se abre o se escribe desde otra pantalla se pone al día
/// aquí con [recordar], sin volver a pedir la lista.
class SoporteCubit extends Cubit<SoporteState> {
  final SoporteService _servicio;
  final String _uid;

  SoporteCubit({required this._servicio, required this._uid})
    : super(const SoporteState());

  /// El servicio con que se abren los tickets y se crean los nuevos.
  SoporteService get servicio => _servicio;

  String get uid => _uid;

  Future<void> cargar() async {
    if (state.tickets.isEmpty && state.carga == CargaTickets.inicial) {
      final guardados = await _servicio.ticketsGuardados(_uid);
      if (isClosed) return;

      if (guardados != null) {
        emit(
          state.copiarCon(
            tickets: ordenarTickets(guardados.tickets),
            desdeCache: true,
            guardadosEn: guardados.guardadosEn,
            carga: CargaTickets.lista,
          ),
        );
      }
    }

    final hayAlgo = state.carga == CargaTickets.lista;
    emit(
      state.copiarCon(
        carga: hayAlgo ? null : CargaTickets.cargando,
        refrescando: hayAlgo,
        limpiarError: true,
      ),
    );

    try {
      final resultado = await _servicio.listar(_uid);
      if (isClosed) return;

      emit(
        state.copiarCon(
          carga: CargaTickets.lista,
          tickets: ordenarTickets(resultado.tickets),
          desdeCache: resultado.desdeCache,
          guardadosEn: resultado.guardadosEn,
          refrescando: false,
        ),
      );
    } catch (error) {
      if (isClosed) return;

      emit(
        state.copiarCon(
          carga: hayAlgo ? CargaTickets.lista : CargaTickets.error,
          refrescando: false,
          error: mensajeDeError(
            error,
            generico: 'No pudimos cargar tus tickets. Intenta de nuevo.',
          ),
        ),
      );
    }
  }

  /// Pone al día (o agrega) un ticket que cambió en otra pantalla.
  void recordar(Ticket ticket) => emit(
    state.copiarCon(
      carga: CargaTickets.lista,
      tickets: conTicket(state.tickets, ticket),
    ),
  );
}
