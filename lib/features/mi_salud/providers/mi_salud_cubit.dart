// lib/features/mi_salud/providers/mi_salud_cubit.dart

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../../dependientes/data/dependientes_service.dart';
import '../../dependientes/data/models/dependiente.dart';
import '../data/mi_salud_service.dart';
import '../data/models/mi_salud.dart';

enum CargaMiSalud { inicial, cargando, lista, error }

class MiSaludState extends Equatable {
  final CargaMiSalud carga;
  final MiSalud? datos;

  /// Se enseña la copia guardada porque no hubo conexión.
  final bool desdeCache;
  final DateTime? guardadaEn;

  /// Por qué no se pudo cargar. Sin datos, en lugar de la pantalla; con
  /// datos (los guardados), como aviso encima.
  final String? error;

  /// Se está preguntando al servidor con algo ya en pantalla.
  final bool refrescando;

  /// Los dependientes del titular, para elegir de quién se ve la salud.
  final List<Dependiente> dependientes;

  /// El uid del dependiente elegido; vacío, el titular.
  final String para;

  const MiSaludState({
    this.carga = CargaMiSalud.inicial,
    this.datos,
    this.desdeCache = false,
    this.guardadaEn,
    this.error,
    this.refrescando = false,
    this.dependientes = const [],
    this.para = '',
  });

  MiSaludState copiarCon({
    CargaMiSalud? carga,
    MiSalud? datos,
    bool limpiarDatos = false,
    bool? desdeCache,
    DateTime? guardadaEn,
    String? error,
    bool limpiarError = false,
    bool? refrescando,
    List<Dependiente>? dependientes,
    String? para,
  }) {
    return MiSaludState(
      carga: carga ?? this.carga,
      datos: limpiarDatos ? null : (datos ?? this.datos),
      desdeCache: desdeCache ?? this.desdeCache,
      guardadaEn: limpiarDatos ? null : (guardadaEn ?? this.guardadaEn),
      error: limpiarError ? null : (error ?? this.error),
      refrescando: refrescando ?? this.refrescando,
      dependientes: dependientes ?? this.dependientes,
      para: para ?? this.para,
    );
  }

  @override
  List<Object?> get props => [
    carga,
    datos,
    desdeCache,
    guardadaEn,
    error,
    refrescando,
    dependientes,
    para,
  ];
}

/// Mi salud del titular o de uno de sus dependientes.
///
/// Abre con la copia guardada, si hay, y enseguida pregunta al servidor.
/// Cambiar de persona no deja ver los datos de la anterior ni un instante:
/// se vacía, se enseña la copia de la nueva (si hay) y se pide la suya. Una
/// respuesta que llega tarde, de una persona que ya no está elegida, se
/// descarta.
class MiSaludCubit extends Cubit<MiSaludState> {
  final MiSaludService _servicio;
  final String _uid;

  /// Solo si la cuenta puede ver a sus dependientes (`portal.dependientes`),
  /// como en el panel. Sin él, solo se ve la del titular.
  final DependientesService? _dependientes;

  int _secuencia = 0;

  MiSaludCubit({
    required this._servicio,
    required this._uid,
    this._dependientes,
  }) : super(const MiSaludState());

  /// Al abrir: los dependientes (sin esperar por ellos) y la salud del
  /// titular.
  Future<void> iniciar() async {
    unawaited(_cargarDependientes());
    await cargar();
  }

  Future<void> _cargarDependientes() async {
    final servicio = _dependientes;
    if (servicio == null) return;

    try {
      final lista = (await servicio.listar(_uid)).lista;
      if (!isClosed) emit(state.copiarCon(dependientes: lista));
    } catch (_) {
      // Sin la lista se ve igual la salud del titular.
    }
  }

  /// Ver la salud de otra persona: el titular (`''`) o un dependiente.
  Future<void> elegir(String para) async {
    if (para == state.para) return;

    emit(
      state.copiarCon(
        para: para,
        carga: CargaMiSalud.inicial,
        limpiarDatos: true,
        desdeCache: false,
        limpiarError: true,
      ),
    );

    await cargar();
  }

  /// Lo guardado primero, si no hay nada en pantalla, y después el servidor.
  Future<void> cargar() async {
    final secuencia = ++_secuencia;
    final para = state.para.isEmpty ? null : state.para;

    if (state.datos == null) {
      final guardada = await _servicio.guardada(_uid, pacienteId: para);
      if (secuencia != _secuencia || isClosed) return;

      if (guardada != null) {
        emit(
          state.copiarCon(
            datos: guardada.datos,
            desdeCache: true,
            guardadaEn: guardada.guardadaEn,
          ),
        );
      }
    }

    final hayAlgo = state.datos != null;
    emit(
      state.copiarCon(
        carga: hayAlgo ? state.carga : CargaMiSalud.cargando,
        refrescando: hayAlgo,
        limpiarError: true,
      ),
    );

    try {
      final resultado = await _servicio.cargar(_uid, pacienteId: para);
      if (secuencia != _secuencia || isClosed) return;

      emit(
        state.copiarCon(
          carga: CargaMiSalud.lista,
          datos: resultado.datos,
          desdeCache: resultado.desdeCache,
          guardadaEn: resultado.guardadaEn,
          refrescando: false,
          limpiarError: true,
        ),
      );
    } catch (error) {
      if (secuencia != _secuencia || isClosed) return;

      emit(
        state.copiarCon(
          carga: state.datos == null ? CargaMiSalud.error : CargaMiSalud.lista,
          refrescando: false,
          error: mensajeDeError(
            error,
            generico:
                'No pudimos cargar tu historia clínica. Intenta de nuevo.',
          ),
        ),
      );
    }
  }
}
