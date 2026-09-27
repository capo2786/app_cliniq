// lib/features/privacidad/providers/arco_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/arco_service.dart';

class ArcoState extends Equatable {
  final List<SolicitudArco> solicitudes;
  final bool cargando;
  final bool desdeCache;

  /// Solo cuando no hay solicitudes que enseñar (ni del servidor ni
  /// guardadas).
  final String? error;

  final bool enviando;

  /// Por qué no se pudo enviar la última solicitud.
  final String? errorAlEnviar;

  const ArcoState({
    this.solicitudes = const [],
    this.cargando = true,
    this.desdeCache = false,
    this.error,
    this.enviando = false,
    this.errorAlEnviar,
  });

  ArcoState copiarCon({
    List<SolicitudArco>? solicitudes,
    bool? cargando,
    bool? desdeCache,
    String? error,
    bool limpiarError = false,
    bool? enviando,
    String? errorAlEnviar,
    bool limpiarErrorAlEnviar = false,
  }) => ArcoState(
    solicitudes: solicitudes ?? this.solicitudes,
    cargando: cargando ?? this.cargando,
    desdeCache: desdeCache ?? this.desdeCache,
    error: limpiarError ? null : (error ?? this.error),
    enviando: enviando ?? this.enviando,
    errorAlEnviar: limpiarErrorAlEnviar
        ? null
        : (errorAlEnviar ?? this.errorAlEnviar),
  );

  @override
  List<Object?> get props => [
    solicitudes,
    cargando,
    desdeCache,
    error,
    enviando,
    errorAlEnviar,
  ];
}

/// Mis solicitudes ARCO: la lista y el envío de una nueva.
class ArcoCubit extends Cubit<ArcoState> {
  final ArcoService _servicio;
  final String uid;

  ArcoCubit(this._servicio, {required this.uid}) : super(const ArcoState());

  Future<void> cargar() async {
    emit(state.copiarCon(cargando: true, limpiarError: true));

    try {
      final datos = await _servicio.mias(uid);
      if (isClosed) return;

      emit(
        state.copiarCon(
          solicitudes: datos.solicitudes,
          cargando: false,
          desdeCache: datos.desdeCache,
        ),
      );
    } catch (error) {
      if (isClosed) return;

      emit(
        state.copiarCon(
          cargando: false,
          error: state.solicitudes.isEmpty
              ? mensajeDeError(
                  error,
                  generico:
                      'No pudimos cargar tus solicitudes. Intenta de nuevo.',
                )
              : null,
        ),
      );
    }
  }

  /// Envía una solicitud nueva. Devuelve si se registró; si no,
  /// [ArcoState.errorAlEnviar] dice por qué (con las palabras del servidor).
  Future<bool> enviar({required String tipo, required String detalle}) async {
    if (state.enviando) return false;

    emit(state.copiarCon(enviando: true, limpiarErrorAlEnviar: true));

    try {
      final creada = await _servicio.crear(tipo: tipo, detalle: detalle.trim());
      if (isClosed) return true;

      final solicitudes = [
        creada,
        for (final s in state.solicitudes)
          if (s.id != creada.id) s,
      ];

      emit(state.copiarCon(enviando: false, solicitudes: solicitudes));
      await _servicio.guardarCopia(uid, solicitudes);

      return true;
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copiarCon(
            enviando: false,
            errorAlEnviar: mensajeDeError(
              error,
              generico: 'No pudimos enviar tu solicitud. Intenta de nuevo.',
            ),
          ),
        );
      }

      return false;
    }
  }
}
