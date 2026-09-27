// lib/features/encuestas/providers/encuesta_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../../citas/data/models/cita.dart';
import '../data/encuestas_service.dart';
import '../dominio/reglas_encuesta.dart';
import 'encuestas_cubit.dart';

/// En qué momento está la encuesta.
enum EtapaEncuesta {
  cargando,
  formulario,

  /// La cita no está entre las pendientes: ya se respondió o pasó la
  /// ventana.
  noDisponible,

  gracias,

  /// El servidor dice que ya tenía respuesta (409).
  yaRespondida,
}

class EncuestaState extends Equatable {
  final EtapaEncuesta etapa;
  final String citaId;

  /// La cita que se califica, si está entre las pendientes.
  final Cita? cita;

  /// Las demás por calificar: «Responder la siguiente».
  final List<Cita> otras;

  /// No se pudo traer la lista: se responde igual, sin los datos de la cita.
  final bool sinDatosDeLaCita;

  /// De 1 a 5; 0 mientras no se elija.
  final int puntuacion;

  /// De 0 a 10; `null` mientras no se elija.
  final int? recomendaria;

  /// Se intentó enviar: desde ahí se enseñan los errores de lo que falta.
  final bool intentado;

  final bool enviando;
  final String? error;

  const EncuestaState({
    required this.citaId,
    this.etapa = EtapaEncuesta.cargando,
    this.cita,
    this.otras = const [],
    this.sinDatosDeLaCita = false,
    this.puntuacion = 0,
    this.recomendaria,
    this.intentado = false,
    this.enviando = false,
    this.error,
  });

  bool get puntuacionValida =>
      puntuacion >= 1 && puntuacion <= puntuacionMaxima;

  bool get recomendacionValida {
    final valor = recomendaria;
    return valor != null && valor >= 0 && valor <= recomendacionMaxima;
  }

  EncuestaState copiarCon({
    EtapaEncuesta? etapa,
    int? puntuacion,
    int? recomendaria,
    bool? intentado,
    bool? enviando,
    String? error,
    bool limpiarError = false,
  }) => EncuestaState(
    citaId: citaId,
    etapa: etapa ?? this.etapa,
    cita: cita,
    otras: otras,
    sinDatosDeLaCita: sinDatosDeLaCita,
    puntuacion: puntuacion ?? this.puntuacion,
    recomendaria: recomendaria ?? this.recomendaria,
    intentado: intentado ?? this.intentado,
    enviando: enviando ?? this.enviando,
    error: limpiarError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [
    etapa,
    citaId,
    cita,
    otras,
    sinDatosDeLaCita,
    puntuacion,
    recomendaria,
    intentado,
    enviando,
    error,
  ];
}

/// La encuesta de una cita (`/portal/encuesta/:citaId`), como la del panel:
/// busca la cita entre las pendientes, pide las dos respuestas y las manda.
/// Al terminar avisa a las [pendientes] del inicio.
class EncuestaCubit extends Cubit<EncuestaState> {
  final EncuestasService _servicio;
  final String uid;
  final EncuestasCubit? pendientes;

  EncuestaCubit(
    this._servicio, {
    required String citaId,
    required this.uid,
    this.pendientes,
  }) : super(EncuestaState(citaId: citaId));

  Future<void> cargar() async {
    final citaId = state.citaId;
    emit(EncuestaState(citaId: citaId));

    try {
      final datos = await _servicio.pendientes(uid);
      if (isClosed) return;

      _mostrar(citaId, datos.citas);
    } catch (_) {
      if (isClosed) return;

      // Sin la lista no hay datos de la cita, pero se puede responder igual:
      // el servidor decide si todavía se puede.
      emit(
        EncuestaState(
          citaId: citaId,
          etapa: EtapaEncuesta.formulario,
          sinDatosDeLaCita: true,
        ),
      );
    }
  }

  /// Pasa a otra de las pendientes, sin volver a pedir la lista. La que se
  /// acaba de responder ya no está entre las [EncuestaState.otras].
  void responderOtra(String citaId) => _mostrar(citaId, state.otras);

  void _mostrar(String citaId, List<Cita> pendientes) {
    Cita? cita;
    for (final c in pendientes) {
      if (c.id == citaId) cita = c;
    }

    emit(
      EncuestaState(
        citaId: citaId,
        etapa: cita == null
            ? EtapaEncuesta.noDisponible
            : EtapaEncuesta.formulario,
        cita: cita,
        otras: [
          for (final c in pendientes)
            if (c.id != citaId) c,
        ],
      ),
    );
  }

  void elegirPuntuacion(int valor) =>
      emit(state.copiarCon(puntuacion: valor.clamp(1, puntuacionMaxima)));

  void elegirRecomendacion(int valor) =>
      emit(state.copiarCon(recomendaria: valor.clamp(0, recomendacionMaxima)));

  /// Manda la respuesta. Sin las dos preguntas contestadas, solo marca que
  /// se intentó (la pantalla dice qué falta).
  Future<void> enviar({String comentario = ''}) async {
    if (state.enviando) return;

    if (!state.puntuacionValida || !state.recomendacionValida) {
      emit(state.copiarCon(intentado: true));
      return;
    }

    emit(state.copiarCon(intentado: true, enviando: true, limpiarError: true));

    try {
      await _servicio.responder(
        RespuestaEncuesta(
          citaId: state.citaId,
          puntuacion: state.puntuacion,
          recomendaria: state.recomendaria!,
          comentario: comentario,
        ),
      );
      if (isClosed) return;

      pendientes?.respondida(state.citaId);
      emit(state.copiarCon(etapa: EtapaEncuesta.gracias, enviando: false));
    } on EncuestaYaRespondida {
      if (isClosed) return;

      pendientes?.respondida(state.citaId);
      emit(state.copiarCon(etapa: EtapaEncuesta.yaRespondida, enviando: false));
    } catch (error) {
      if (isClosed) return;

      emit(
        state.copiarCon(
          enviando: false,
          error: mensajeDeError(
            error,
            generico: 'No pudimos enviar tu respuesta. Intenta de nuevo.',
          ),
        ),
      );
    }
  }
}
