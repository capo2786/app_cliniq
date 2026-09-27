// lib/features/mi_salud/providers/documento_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/mi_salud_service.dart';
import '../data/models/mi_salud.dart';

enum CargaDocumento { inicial, cargando, lista, error }

class DocumentoState<T extends DocumentoClinico> extends Equatable {
  final CargaDocumento carga;
  final T? documento;
  final bool desdeCache;
  final DateTime? guardadoEn;

  /// Sin documento, en lugar de la pantalla; con él, como aviso encima.
  final String? error;

  const DocumentoState({
    this.carga = CargaDocumento.inicial,
    this.documento,
    this.desdeCache = false,
    this.guardadoEn,
    this.error,
  });

  DocumentoState<T> copiarCon({
    CargaDocumento? carga,
    T? documento,
    bool? desdeCache,
    DateTime? guardadoEn,
    String? error,
    bool limpiarError = false,
  }) {
    return DocumentoState<T>(
      carga: carga ?? this.carga,
      documento: documento ?? this.documento,
      desdeCache: desdeCache ?? this.desdeCache,
      guardadoEn: guardadoEn ?? this.guardadoEn,
      error: limpiarError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [carga, documento, desdeCache, guardadoEn, error];
}

/// Una receta o una orden abierta.
///
/// Si se abre desde Mi salud, arranca con el documento que ya venía en la
/// lista ([inicial]) y lo pone al día con el de su propia ruta
/// (`/portal/recetas/:id`, `/portal/ordenes/:id`); sin conexión, con la
/// copia guardada.
class DocumentoCubit<T extends DocumentoClinico>
    extends Cubit<DocumentoState<T>> {
  final Future<ResultadoDocumento<T>> Function() _pedir;

  DocumentoCubit(this._pedir, {T? inicial})
    : super(
        DocumentoState<T>(
          documento: inicial,
          carga: inicial == null
              ? CargaDocumento.inicial
              : CargaDocumento.lista,
        ),
      );

  Future<void> cargar() async {
    emit(
      state.copiarCon(
        carga: state.documento == null ? CargaDocumento.cargando : null,
        limpiarError: true,
      ),
    );

    try {
      final resultado = await _pedir();
      if (isClosed) return;

      emit(
        state.copiarCon(
          carga: CargaDocumento.lista,
          documento: resultado.documento,
          desdeCache: resultado.desdeCache,
          guardadoEn: resultado.guardadoEn,
          limpiarError: true,
        ),
      );
    } catch (error) {
      if (isClosed) return;

      emit(
        state.copiarCon(
          carga: state.documento == null
              ? CargaDocumento.error
              : CargaDocumento.lista,
          error: mensajeDeError(
            error,
            generico: 'No pudimos abrir el documento. Intenta de nuevo.',
          ),
        ),
      );
    }
  }
}
