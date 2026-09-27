import 'package:equatable/equatable.dart';

import '../../../core/archivos/archivo_local.dart';
import '../../../core/archivos/archivo_meta.dart';
import '../data/models/consulta.dart';
import 'consultas_state.dart';

enum CargaDetalle { inicial, cargando, lista, error }

class DetalleConsultaState extends Equatable {
  final CargaDetalle carga;
  final ConsultaDetalle? detalle;

  /// Se enseña la copia guardada porque no hubo conexión.
  final bool desdeCache;
  final DateTime? guardadaEn;

  /// Por qué no se pudo cargar (solo cuando no hay nada que enseñar).
  final String? error;

  /// Se está preguntando al servidor por novedades.
  final bool refrescando;

  /// El archivo elegido para el próximo mensaje.
  final ArchivoLocal? adjunto;

  /// Ese archivo, si ya subió: un reintento del mensaje no lo vuelve a
  /// subir.
  final ArchivoMeta? adjuntoSubido;

  final bool enviando;

  /// Qué se está haciendo al enviar: «Subiendo el archivo…».
  final String? progreso;

  final String? errorEnvio;

  /// Cuántos mensajes salieron desde que se abrió: la pantalla vacía el
  /// campo cada vez que cambia.
  final int enviados;

  final bool cancelando;

  final AvisoConsultas? aviso;

  const DetalleConsultaState({
    this.carga = CargaDetalle.inicial,
    this.detalle,
    this.desdeCache = false,
    this.guardadaEn,
    this.error,
    this.refrescando = false,
    this.adjunto,
    this.adjuntoSubido,
    this.enviando = false,
    this.progreso,
    this.errorEnvio,
    this.enviados = 0,
    this.cancelando = false,
    this.aviso,
  });

  bool get puedeEscribir => detalle?.puedeEscribir ?? false;

  bool get puedeCancelar => detalle?.estado == EstadoConsulta.enviada;

  DetalleConsultaState copiarCon({
    CargaDetalle? carga,
    ConsultaDetalle? detalle,
    bool? desdeCache,
    DateTime? guardadaEn,
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
    bool? cancelando,
    AvisoConsultas? aviso,
  }) {
    return DetalleConsultaState(
      carga: carga ?? this.carga,
      detalle: detalle ?? this.detalle,
      desdeCache: desdeCache ?? this.desdeCache,
      guardadaEn: guardadaEn ?? this.guardadaEn,
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
      cancelando: cancelando ?? this.cancelando,
      aviso: aviso ?? this.aviso,
    );
  }

  @override
  List<Object?> get props => [
    carga,
    detalle,
    desdeCache,
    guardadaEn,
    error,
    refrescando,
    adjunto,
    adjuntoSubido,
    enviando,
    progreso,
    errorEnvio,
    enviados,
    cancelando,
    aviso,
  ];
}
