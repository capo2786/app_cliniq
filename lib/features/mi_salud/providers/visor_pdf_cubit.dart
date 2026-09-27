// lib/features/mi_salud/providers/visor_pdf_cubit.dart

import 'dart:ui';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/archivos/salida_de_archivos.dart';
import '../../../core/network/errores.dart';
import '../data/documentos_pdf_service.dart';

enum CargaPdf { cargando, listo, error }

/// Cómo terminó «Guardar en el teléfono» o «Compartir».
enum ResultadoSalida { hecho, cancelado, fallo }

class VisorPdfState extends Equatable {
  final CargaPdf carga;
  final PdfGuardado? pdf;
  final String? error;

  /// Se está guardando o compartiendo: los botones esperan.
  final bool ocupado;

  const VisorPdfState({
    this.carga = CargaPdf.cargando,
    this.pdf,
    this.error,
    this.ocupado = false,
  });

  VisorPdfState copiarCon({
    CargaPdf? carga,
    PdfGuardado? pdf,
    String? error,
    bool limpiarError = false,
    bool? ocupado,
  }) {
    return VisorPdfState(
      carga: carga ?? this.carga,
      pdf: pdf ?? this.pdf,
      error: limpiarError ? null : (error ?? this.error),
      ocupado: ocupado ?? this.ocupado,
    );
  }

  @override
  List<Object?> get props => [carga, pdf, error, ocupado];
}

/// El PDF firmado abierto en la aplicación: bajarlo (o tomar su copia) y,
/// si la persona lo pide, guardarlo en el teléfono o compartirlo.
class VisorPdfCubit extends Cubit<VisorPdfState> {
  final Future<PdfGuardado> Function() _pedir;
  final SalidaDeArchivos _salida;

  /// El nombre con que se guarda o se comparte («Receta UC7F6DB5UU.pdf»).
  final String nombreArchivo;

  /// El asunto, si se comparte por correo.
  final String asunto;

  VisorPdfCubit(
    this._pedir,
    this._salida, {
    required this.nombreArchivo,
    required this.asunto,
  }) : super(const VisorPdfState());

  Future<void> cargar() async {
    emit(state.copiarCon(carga: CargaPdf.cargando, limpiarError: true));

    try {
      final pdf = await _pedir();
      if (isClosed) return;

      emit(state.copiarCon(carga: CargaPdf.listo, pdf: pdf));
    } catch (error) {
      if (isClosed) return;

      emit(
        state.copiarCon(
          carga: CargaPdf.error,
          error: error is PdfNoValido
              ? error.mensaje
              : mensajeDeError(
                  error,
                  generico: 'No pudimos abrir el PDF. Intenta de nuevo.',
                ),
        ),
      );
    }
  }

  /// Abre el diálogo del sistema para guardar una copia.
  Future<ResultadoSalida> guardar() => _sacar(
    (pdf) async => await _salida.guardarEnElTelefono(
      ruta: pdf.ruta,
      nombre: nombreArchivo,
      mime: 'application/pdf',
    ),
  );

  /// Abre la hoja de compartir del sistema.
  Future<ResultadoSalida> compartir({Rect? origen}) => _sacar((pdf) async {
    await _salida.compartir(
      ruta: pdf.ruta,
      nombre: nombreArchivo,
      mime: 'application/pdf',
      asunto: asunto,
      origen: origen,
    );
    return true;
  });

  Future<ResultadoSalida> _sacar(
    Future<bool> Function(PdfGuardado pdf) accion,
  ) async {
    final pdf = state.pdf;
    if (pdf == null || state.ocupado) return ResultadoSalida.cancelado;

    emit(state.copiarCon(ocupado: true));

    try {
      final hecho = await accion(pdf);
      return hecho ? ResultadoSalida.hecho : ResultadoSalida.cancelado;
    } catch (error) {
      debugPrint('Cliniq · no se pudo sacar el PDF: $error');
      return ResultadoSalida.fallo;
    } finally {
      if (!isClosed) emit(state.copiarCon(ocupado: false));
    }
  }
}
