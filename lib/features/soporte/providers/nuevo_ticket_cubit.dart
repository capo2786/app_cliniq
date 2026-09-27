// lib/features/soporte/providers/nuevo_ticket_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/archivos/archivo_local.dart';
import '../../../core/archivos/eleccion.dart';
import '../../../core/archivos/selector_de_archivos.dart';
import '../../../core/configuracion/config_publica.dart';
import '../../../core/network/errores.dart';
import '../data/models/ticket.dart';
import '../data/soporte_service.dart';
import '../dominio/reglas_soporte.dart';
import 'aviso_soporte.dart';

class NuevoTicketState extends Equatable {
  /// Código de `CATEGORIA_TICKET`; vacío si todavía no se eligió.
  final String categoria;

  /// Código de `SEVERIDAD_TICKET`.
  final String severidad;

  /// El archivo que acompaña al ticket (una captura, por ejemplo).
  final ArchivoLocal? adjunto;

  final bool enviando;

  /// Qué se está haciendo: «Enviando el ticket…», «Subiendo el archivo…».
  final String? progreso;

  final String? errorCategoria;
  final String? errorAsunto;
  final String? errorDescripcion;

  /// El ticket ya creado: la pantalla se cierra con él.
  final Ticket? creado;

  /// Se creó el ticket pero el archivo no subió: se dice por qué, y se
  /// puede volver a adjuntar desde la conversación.
  final String? problemaDelAdjunto;

  final AvisoSoporte? aviso;

  const NuevoTicketState({
    this.categoria = '',
    this.severidad = severidadPorDefecto,
    this.adjunto,
    this.enviando = false,
    this.progreso,
    this.errorCategoria,
    this.errorAsunto,
    this.errorDescripcion,
    this.creado,
    this.problemaDelAdjunto,
    this.aviso,
  });

  NuevoTicketState copiarCon({
    String? categoria,
    String? severidad,
    ArchivoLocal? adjunto,
    bool limpiarAdjunto = false,
    bool? enviando,
    String? progreso,
    bool limpiarProgreso = false,
    String? errorCategoria,
    String? errorAsunto,
    String? errorDescripcion,
    bool limpiarErrores = false,
    Ticket? creado,
    String? problemaDelAdjunto,
    AvisoSoporte? aviso,
  }) {
    return NuevoTicketState(
      categoria: categoria ?? this.categoria,
      severidad: severidad ?? this.severidad,
      adjunto: limpiarAdjunto ? null : (adjunto ?? this.adjunto),
      enviando: enviando ?? this.enviando,
      progreso: limpiarProgreso ? null : (progreso ?? this.progreso),
      errorCategoria: limpiarErrores
          ? errorCategoria
          : (errorCategoria ?? this.errorCategoria),
      errorAsunto: limpiarErrores
          ? errorAsunto
          : (errorAsunto ?? this.errorAsunto),
      errorDescripcion: limpiarErrores
          ? errorDescripcion
          : (errorDescripcion ?? this.errorDescripcion),
      creado: creado ?? this.creado,
      problemaDelAdjunto: problemaDelAdjunto ?? this.problemaDelAdjunto,
      aviso: aviso ?? this.aviso,
    );
  }

  @override
  List<Object?> get props => [
    categoria,
    severidad,
    adjunto,
    enviando,
    progreso,
    errorCategoria,
    errorAsunto,
    errorDescripcion,
    creado,
    problemaDelAdjunto,
    aviso,
  ];
}

/// Abrir un ticket: categoría, severidad, asunto, descripción y un archivo
/// opcional.
///
/// Se valida con las reglas del servidor antes de mandar nada. El archivo
/// sube después de crear el ticket (la ruta de adjuntos es del ticket) y va
/// en un mensaje «Adjunto: …», como en el panel. Si el archivo falla, el
/// ticket ya existe: se cierra igual y se dice qué pasó con el archivo.
class NuevoTicketCubit extends Cubit<NuevoTicketState> {
  final SoporteService _servicio;
  final String _uid;

  /// Qué archivos se aceptan y hasta qué tamaño (configuración de la
  /// clínica).
  final ReglasArchivos _archivos;

  int _secuencia = 0;

  NuevoTicketCubit({
    required this._servicio,
    required this._uid,
    required this._archivos,
    String categoria = '',
    String severidad = severidadPorDefecto,
  }) : super(NuevoTicketState(categoria: categoria, severidad: severidad));

  AvisoSoporte _aviso(String mensaje, {bool exito = false}) =>
      AvisoSoporte(mensaje: mensaje, exito: exito, secuencia: ++_secuencia);

  void elegirCategoria(String categoria) => emit(
    state.copiarCon(
      categoria: categoria,
      limpiarErrores: true,
      errorAsunto: state.errorAsunto,
      errorDescripcion: state.errorDescripcion,
    ),
  );

  void elegirSeveridad(String severidad) =>
      emit(state.copiarCon(severidad: severidad));

  void elegirAdjunto(SeleccionDeArchivos seleccion) {
    final eleccion = unSoloArchivo(seleccion, _archivos);
    final archivo = eleccion.archivo;

    if (archivo == null) {
      final problema = eleccion.problema;
      if (problema != null) emit(state.copiarCon(aviso: _aviso(problema)));
      return;
    }

    emit(
      state.copiarCon(
        adjunto: archivo,
        aviso: eleccion.habiaVarios
            ? _aviso('El ticket lleva un solo archivo: adjuntamos el primero.')
            : null,
      ),
    );
  }

  void quitarAdjunto() => emit(state.copiarCon(limpiarAdjunto: true));

  Future<void> enviar({
    required String asunto,
    required String descripcion,
  }) async {
    if (state.enviando || state.creado != null) return;

    final errorCategoria = state.categoria.isEmpty
        ? 'Elige de qué se trata.'
        : null;
    final errorAsunto = errorDelAsunto(asunto);
    final errorDescripcion = errorDeLaDescripcion(descripcion);

    emit(
      state.copiarCon(
        limpiarErrores: true,
        errorCategoria: errorCategoria,
        errorAsunto: errorAsunto,
        errorDescripcion: errorDescripcion,
      ),
    );

    if (errorCategoria != null ||
        errorAsunto != null ||
        errorDescripcion != null) {
      return;
    }

    emit(state.copiarCon(enviando: true, progreso: 'Enviando el ticket…'));

    final Ticket creado;
    try {
      creado = await _servicio.crear(
        NuevoTicket(
          categoria: state.categoria,
          severidad: state.severidad,
          asunto: asunto,
          descripcion: descripcion,
        ),
      );
    } catch (error) {
      emit(
        state.copiarCon(
          enviando: false,
          limpiarProgreso: true,
          aviso: _aviso(
            mensajeDeError(
              error,
              generico: 'No se pudo enviar el ticket. Intenta de nuevo.',
            ),
          ),
        ),
      );
      return;
    }

    final adjunto = state.adjunto;
    if (adjunto == null) {
      emit(
        state.copiarCon(enviando: false, limpiarProgreso: true, creado: creado),
      );
      return;
    }

    emit(state.copiarCon(progreso: 'Subiendo el archivo…'));

    try {
      final subido = await _servicio.subirAdjunto(creado.id, adjunto);
      final conArchivo = await _servicio.responder(
        _uid,
        creado.id,
        textoDeAdjunto(adjunto.nombreParaSubir),
        adjuntoId: subido.id,
      );

      emit(
        state.copiarCon(
          enviando: false,
          limpiarProgreso: true,
          creado: conArchivo,
        ),
      );
    } catch (error) {
      final motivo = mensajeDeError(error);

      emit(
        state.copiarCon(
          enviando: false,
          limpiarProgreso: true,
          creado: creado,
          problemaDelAdjunto:
              'El ticket se creó, pero el archivo no se pudo subir: $motivo '
              'Puedes adjuntarlo desde la conversación.',
        ),
      );
    }
  }
}
