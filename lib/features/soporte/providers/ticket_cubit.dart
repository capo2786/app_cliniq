// lib/features/soporte/providers/ticket_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/archivos/archivo_local.dart';
import '../../../core/archivos/archivo_meta.dart';
import '../../../core/archivos/eleccion.dart';
import '../../../core/archivos/selector_de_archivos.dart';
import '../../../core/configuracion/config_publica.dart';
import '../../../core/network/errores.dart';
import '../data/models/ticket.dart';
import '../data/soporte_service.dart';
import '../dominio/reglas_soporte.dart';
import 'aviso_soporte.dart';

enum CargaTicket { inicial, cargando, lista, error }

class TicketState extends Equatable {
  final CargaTicket carga;
  final Ticket? ticket;

  final bool desdeCache;
  final DateTime? guardadoEn;

  /// Por qué no se pudo abrir (solo cuando no hay nada que enseñar).
  final String? error;

  final bool refrescando;

  /// El archivo elegido para el próximo mensaje.
  final ArchivoLocal? adjunto;

  /// Ese archivo, si ya subió: un reintento no lo vuelve a subir.
  final ArchivoMeta? adjuntoSubido;

  final bool enviando;

  /// «Subiendo el archivo…», «Enviando…».
  final String? progreso;

  final String? errorEnvio;

  /// Cuántos mensajes salieron desde que se abrió: la pantalla vacía el
  /// campo cada vez que cambia.
  final int enviados;

  final AvisoSoporte? aviso;

  const TicketState({
    this.carga = CargaTicket.inicial,
    this.ticket,
    this.desdeCache = false,
    this.guardadoEn,
    this.error,
    this.refrescando = false,
    this.adjunto,
    this.adjuntoSubido,
    this.enviando = false,
    this.progreso,
    this.errorEnvio,
    this.enviados = 0,
    this.aviso,
  });

  /// Se puede escribir: el ticket no está cerrado.
  bool get puedeEscribir => ticket?.estado.admiteMensajes ?? false;

  TicketState copiarCon({
    CargaTicket? carga,
    Ticket? ticket,
    bool? desdeCache,
    DateTime? guardadoEn,
    String? error,
    bool limpiarError = false,
    bool? refrescando,
    ArchivoLocal? adjunto,
    ArchivoMeta? adjuntoSubido,
    bool limpiarAdjunto = false,
    bool? enviando,
    String? progreso,
    bool limpiarProgreso = false,
    String? errorEnvio,
    bool limpiarErrorEnvio = false,
    int? enviados,
    AvisoSoporte? aviso,
  }) {
    return TicketState(
      carga: carga ?? this.carga,
      ticket: ticket ?? this.ticket,
      desdeCache: desdeCache ?? this.desdeCache,
      guardadoEn: guardadoEn ?? this.guardadoEn,
      error: limpiarError ? null : (error ?? this.error),
      refrescando: refrescando ?? this.refrescando,
      adjunto: limpiarAdjunto ? null : (adjunto ?? this.adjunto),
      adjuntoSubido: limpiarAdjunto
          ? null
          : (adjuntoSubido ?? this.adjuntoSubido),
      enviando: enviando ?? this.enviando,
      progreso: limpiarProgreso ? null : (progreso ?? this.progreso),
      errorEnvio: limpiarErrorEnvio ? null : (errorEnvio ?? this.errorEnvio),
      enviados: enviados ?? this.enviados,
      aviso: aviso ?? this.aviso,
    );
  }

  @override
  List<Object?> get props => [
    carga,
    ticket,
    desdeCache,
    guardadoEn,
    error,
    refrescando,
    adjunto,
    adjuntoSubido,
    enviando,
    progreso,
    errorEnvio,
    enviados,
    aviso,
  ];
}

/// Un ticket abierto: la conversación con soporte, escribir y adjuntar.
///
/// Abre con lo que ya se tenga (el resumen de la lista o la copia
/// guardada) y pide el ticket entero. Al escribir se usa el ticket que
/// devuelve el servidor; una respuesta de una carga anterior que llega
/// después no lo pisa.
class TicketCubit extends Cubit<TicketState> {
  final SoporteService _servicio;
  final String _uid;
  final String _id;

  /// Qué archivos se aceptan y hasta qué tamaño.
  final ReglasArchivos _archivos;

  int _secuencia = 0;

  /// Sube con cada mensaje enviado: una carga que salió antes ya no vale.
  int _generacion = 0;

  TicketCubit({
    required this._servicio,
    required this._uid,
    required this._id,
    required this._archivos,
    Ticket? inicial,
  }) : super(TicketState(ticket: inicial));

  AvisoSoporte _aviso(String mensaje, {bool exito = false}) =>
      AvisoSoporte(mensaje: mensaje, exito: exito, secuencia: ++_secuencia);

  // ── Cargar ─────────────────────────────────────────────────────────

  /// Lo guardado primero, si no hay conversación a la vista, y después el
  /// servidor.
  Future<void> cargar() async {
    if (state.ticket?.mensajes == null) {
      final guardado = await _servicio.ticketGuardado(_uid, _id);
      if (isClosed) return;

      if (guardado != null) {
        emit(
          state.copiarCon(
            ticket: guardado.ticket,
            desdeCache: true,
            guardadoEn: guardado.guardadoEn,
          ),
        );
      }
    }

    await _pedir(avisarSiFalla: false);
  }

  /// Deslizar para refrescar: si falla, se avisa.
  Future<void> refrescar() => _pedir(avisarSiFalla: true);

  Future<void> _pedir({required bool avisarSiFalla}) async {
    final hayAlgo = state.ticket != null;
    final generacion = _generacion;

    emit(
      state.copiarCon(
        carga: hayAlgo ? null : CargaTicket.cargando,
        refrescando: hayAlgo,
        limpiarError: true,
      ),
    );

    try {
      final resultado = await _servicio.detalle(_uid, _id);
      if (isClosed) return;

      if (generacion != _generacion) {
        emit(state.copiarCon(refrescando: false));
        return;
      }

      emit(
        state.copiarCon(
          carga: CargaTicket.lista,
          ticket: resultado.ticket,
          desdeCache: resultado.desdeCache,
          guardadoEn: resultado.guardadoEn,
          refrescando: false,
        ),
      );
    } catch (error) {
      if (isClosed) return;

      final mensaje = mensajeDeError(
        error,
        generico: 'No pudimos abrir el ticket. Intenta de nuevo.',
      );

      emit(
        state.copiarCon(
          carga: hayAlgo ? CargaTicket.lista : CargaTicket.error,
          refrescando: false,
          error: hayAlgo ? null : mensaje,
          aviso: hayAlgo && avisarSiFalla ? _aviso(mensaje) : null,
        ),
      );
    }
  }

  // ── Escribir ───────────────────────────────────────────────────────

  void elegirAdjunto(SeleccionDeArchivos seleccion) {
    final eleccion = unSoloArchivo(seleccion, _archivos);
    final archivo = eleccion.archivo;

    if (archivo == null) {
      final problema = eleccion.problema;
      if (problema != null) emit(state.copiarCon(aviso: _aviso(problema)));
      return;
    }

    // Un archivo nuevo reemplaza al anterior, aunque aquel ya hubiera subido.
    emit(
      state
          .copiarCon(limpiarAdjunto: true)
          .copiarCon(
            adjunto: archivo,
            limpiarErrorEnvio: true,
            aviso: eleccion.habiaVarios
                ? _aviso(
                    'Cada mensaje lleva un solo archivo: adjuntamos el '
                    'primero.',
                  )
                : null,
          ),
    );
  }

  void quitarAdjunto() => emit(state.copiarCon(limpiarAdjunto: true));

  Future<void> enviar(String texto) async {
    final ticket = state.ticket;
    if (ticket == null || !state.puedeEscribir || state.enviando) return;

    final local = state.adjunto;
    final problema = errorDelMensaje(texto, conAdjunto: local != null);
    if (problema != null) {
      emit(state.copiarCon(errorEnvio: problema));
      return;
    }

    final cuerpo = texto.trim().isEmpty && local != null
        ? textoDeAdjunto(local.nombreParaSubir)
        : texto.trim();

    _generacion++;
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
        subido = await _servicio.subirAdjunto(ticket.id, local);
        emit(state.copiarCon(adjuntoSubido: subido, progreso: 'Enviando…'));
      }

      final nuevo = await _servicio.responder(
        _uid,
        ticket.id,
        cuerpo,
        adjuntoId: subido?.id,
      );

      emit(
        state.copiarCon(
          carga: CargaTicket.lista,
          ticket: nuevo,
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
}
