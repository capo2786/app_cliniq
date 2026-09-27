import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/archivos/archivo_local.dart';
import '../../../core/network/errores.dart';
import '../data/consultas_service.dart';
import '../dominio/reglas_consultas.dart';
import 'consultas_state.dart';
import 'detalle_consulta_event.dart';
import 'detalle_consulta_state.dart';

/// Cada cuánto se pregunta por mensajes nuevos mientras el detalle se ve.
const Duration intervaloDeSondeo = Duration(seconds: 30);

Stream<void> _latidosCada30Segundos() =>
    Stream<void>.periodic(intervaloDeSondeo);

/// Una consulta abierta: su estado, la conversación, escribir, adjuntar y
/// cancelar.
///
/// Mientras la pantalla se ve, pregunta cada 30 segundos si hay novedades:
/// la respuesta del médico aparece sola, sin tener que deslizar. Los latidos
/// se inyectan para que las pruebas los den a mano, sin esperar relojes.
class DetalleConsultaBloc
    extends Bloc<DetalleConsultaEvent, DetalleConsultaState> {
  final ConsultasService _servicio;
  final String _uid;
  final String _id;
  final Stream<void> Function() _latidos;

  StreamSubscription<void>? _sondeo;
  int _secuencia = 0;

  /// Sube con cada cambio hecho desde aquí (escribir, cancelar): una
  /// respuesta del sondeo que salió antes ya no vale y se descarta, para que
  /// no pise el mensaje recién enviado con una copia vieja.
  int _generacion = 0;

  DetalleConsultaBloc({
    required this._servicio,
    required this._uid,
    required this._id,
    Stream<void> Function()? latidos,
  }) : _latidos = latidos ?? _latidosCada30Segundos,
       super(const DetalleConsultaState()) {
    on<DetalleConsultaSolicitado>(_alSolicitar);
    on<DetalleConsultaRefrescado>(_alRefrescar);
    on<DetalleConsultaSondeoCambiado>(_alCambiarSondeo);
    on<DetalleConsultaAdjuntoElegido>(_alElegirAdjunto);
    on<DetalleConsultaAdjuntoQuitado>(
      (event, emit) => emit(state.copiarCon(limpiarAdjunto: true)),
    );
    on<DetalleConsultaMensajeEnviado>(_alEscribir);
    on<DetalleConsultaCancelada>(_alCancelar);
  }

  /// Si el sondeo está encendido.
  bool get sondeando => _sondeo != null;

  AvisoConsultas _aviso(String mensaje, {bool exito = false}) =>
      AvisoConsultas(exito: exito, mensaje: mensaje, secuencia: ++_secuencia);

  // ── Cargar ─────────────────────────────────────────────────────────

  Future<void> _alSolicitar(
    DetalleConsultaSolicitado event,
    Emitter<DetalleConsultaState> emit,
  ) async {
    if (state.detalle == null) {
      final guardado = await _servicio.detalleGuardado(_uid, _id);
      if (guardado != null) {
        emit(
          state.copiarCon(
            detalle: guardado.detalle,
            desdeCache: true,
            guardadaEn: guardado.guardadaEn,
          ),
        );
      }
    }

    emit(state.copiarCon(carga: CargaDetalle.cargando, limpiarError: true));

    final generacion = _generacion;

    try {
      final resultado = await _servicio.detalle(_uid, _id);
      if (generacion != _generacion) return;

      emit(
        state.copiarCon(
          carga: CargaDetalle.lista,
          detalle: resultado.detalle,
          desdeCache: resultado.desdeCache,
          guardadaEn: resultado.guardadaEn,
          limpiarError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copiarCon(
          carga: state.detalle == null
              ? CargaDetalle.error
              : CargaDetalle.lista,
          error: mensajeDeError(
            error,
            generico: 'No pudimos abrir la consulta. Intenta de nuevo.',
          ),
        ),
      );
    }
  }

  Future<void> _alRefrescar(
    DetalleConsultaRefrescado event,
    Emitter<DetalleConsultaState> emit,
  ) async {
    final actual = state.detalle;

    if (event.silencioso) {
      // El sondeo no pregunta por lo que no puede cambiar ni se cruza con
      // lo que la persona está haciendo.
      if (actual == null || actual.estado.terminada) return;
      if (state.refrescando || state.enviando || state.cancelando) return;
    } else if (actual == null) {
      add(const DetalleConsultaSolicitado());
      return;
    }

    final generacion = _generacion;
    emit(state.copiarCon(refrescando: true));

    try {
      final resultado = await _servicio.detalle(_uid, _id);

      if (generacion != _generacion) {
        emit(state.copiarCon(refrescando: false));
        return;
      }

      emit(
        state.copiarCon(
          carga: CargaDetalle.lista,
          detalle: resultado.detalle,
          desdeCache: resultado.desdeCache,
          guardadaEn: resultado.guardadaEn,
          refrescando: false,
          limpiarError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copiarCon(
          refrescando: false,
          aviso: event.silencioso
              ? null
              : _aviso(
                  mensajeDeError(
                    error,
                    generico: 'No pudimos actualizar la consulta.',
                  ),
                ),
        ),
      );
    }
  }

  // ── Sondeo ─────────────────────────────────────────────────────────

  Future<void> _alCambiarSondeo(
    DetalleConsultaSondeoCambiado event,
    Emitter<DetalleConsultaState> emit,
  ) async {
    if (!event.activo) {
      await _sondeo?.cancel();
      _sondeo = null;
      return;
    }

    _sondeo ??= _latidos().listen((_) {
      if (!isClosed) add(const DetalleConsultaRefrescado(silencioso: true));
    });
  }

  // ── Escribir ───────────────────────────────────────────────────────

  void _alElegirAdjunto(
    DetalleConsultaAdjuntoElegido event,
    Emitter<DetalleConsultaState> emit,
  ) {
    final seleccion = event.seleccion;

    if (seleccion.archivos.isEmpty) {
      if (seleccion.problemas.isNotEmpty) {
        emit(state.copiarCon(aviso: _aviso(seleccion.problemas.join('\n'))));
      }
      return;
    }

    // Un mensaje lleva un solo archivo: se toma el primero.
    final archivo = seleccion.archivos.first;
    final problema = problemaDelArchivo(archivo);

    if (problema != null) {
      emit(state.copiarCon(aviso: _aviso(problema)));
      return;
    }

    // Un archivo nuevo reemplaza al anterior, aunque aquel ya hubiera subido.
    emit(
      state
          .copiarCon(limpiarAdjunto: true)
          .copiarCon(
            adjunto: archivo,
            limpiarErrorEnvio: true,
            aviso: seleccion.archivos.length > 1
                ? _aviso(
                    'Cada mensaje lleva un solo archivo: adjuntamos el '
                    'primero.',
                  )
                : null,
          ),
    );
  }

  Future<void> _alEscribir(
    DetalleConsultaMensajeEnviado event,
    Emitter<DetalleConsultaState> emit,
  ) async {
    final detalle = state.detalle;
    if (detalle == null || !detalle.puedeEscribir || state.enviando) return;

    final texto = event.texto.trim();

    if (texto.isEmpty) {
      emit(
        state.copiarCon(
          errorEnvio: state.adjunto == null
              ? 'Escribe tu mensaje.'
              : 'Escribe un mensaje para acompañar el archivo.',
        ),
      );
      return;
    }

    if (texto.length > maximoMensaje) {
      emit(
        state.copiarCon(
          errorEnvio: 'El mensaje admite hasta $maximoMensaje caracteres.',
        ),
      );
      return;
    }

    _generacion++;

    final local = state.adjunto;
    var subido = state.adjuntoSubido;

    emit(
      state.copiarCon(
        enviando: true,
        limpiarErrorEnvio: true,
        progreso: local != null && subido == null
            ? 'Subiendo el archivo…'
            : 'Enviando…',
      ),
    );

    try {
      if (local != null && subido == null) {
        subido = await _servicio.subirAdjunto(detalle.id, local);
        emit(state.copiarCon(adjuntoSubido: subido, progreso: 'Enviando…'));
      }

      final nuevo = await _servicio.escribir(
        detalle.id,
        texto,
        adjuntoId: subido?.id,
      );

      await _servicio.recordar(_uid, nuevo);

      emit(
        state.copiarCon(
          detalle: nuevo,
          desdeCache: false,
          enviando: false,
          limpiarProgreso: true,
          limpiarAdjunto: true,
          enviados: state.enviados + 1,
        ),
      );
    } catch (error) {
      emit(
        state.copiarCon(
          enviando: false,
          limpiarProgreso: true,
          errorEnvio: mensajeDeError(
            error,
            generico: 'No se pudo enviar el mensaje. Intenta de nuevo.',
          ),
        ),
      );
    }
  }

  // ── Cancelar ───────────────────────────────────────────────────────

  Future<void> _alCancelar(
    DetalleConsultaCancelada event,
    Emitter<DetalleConsultaState> emit,
  ) async {
    final detalle = state.detalle;
    if (detalle == null || !state.puedeCancelar || state.cancelando) return;

    final motivo = event.motivo.trim();
    if (motivo.isEmpty) {
      emit(state.copiarCon(aviso: _aviso('Cuéntanos por qué la cancelas.')));
      return;
    }

    _generacion++;
    emit(state.copiarCon(cancelando: true));

    try {
      final cancelada = await _servicio.cancelar(detalle.id, motivo);
      await _servicio.recordar(_uid, cancelada);

      emit(
        state.copiarCon(
          detalle: cancelada,
          desdeCache: false,
          cancelando: false,
          aviso: _aviso(
            'Consulta cancelada. Le avisamos al médico.',
            exito: true,
          ),
        ),
      );
    } catch (error) {
      emit(
        state.copiarCon(
          cancelando: false,
          aviso: _aviso(
            mensajeDeError(error, generico: 'No se pudo cancelar la consulta.'),
          ),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _sondeo?.cancel();
    _sondeo = null;
    return super.close();
  }
}
