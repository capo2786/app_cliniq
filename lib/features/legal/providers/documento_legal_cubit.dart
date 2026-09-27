// lib/features/legal/providers/documento_legal_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/legal_service.dart';

class DocumentoLegalState extends Equatable {
  final bool cargando;
  final TextoLegal? documento;

  /// El servidor dice que no existe o que ya no está vigente.
  final bool noEncontrado;

  /// Solo cuando no hay documento (ni del servidor ni guardado).
  final String? error;

  const DocumentoLegalState({
    this.cargando = true,
    this.documento,
    this.noEncontrado = false,
    this.error,
  });

  @override
  List<Object?> get props => [cargando, documento, noEncontrado, error];
}

/// El texto de un documento legal, para leerlo dentro de la aplicación.
class DocumentoLegalCubit extends Cubit<DocumentoLegalState> {
  final LegalService _servicio;
  final String slug;

  DocumentoLegalCubit(this._servicio, this.slug)
    : super(const DocumentoLegalState());

  Future<void> cargar() async {
    emit(DocumentoLegalState(documento: state.documento));

    try {
      final documento = await _servicio.texto(slug);
      if (isClosed) return;

      emit(DocumentoLegalState(cargando: false, documento: documento));
    } on DocumentoLegalNoEncontrado {
      if (isClosed) return;

      emit(const DocumentoLegalState(cargando: false, noEncontrado: true));
    } catch (error) {
      if (isClosed) return;

      emit(
        DocumentoLegalState(
          cargando: false,
          documento: state.documento,
          error: state.documento == null
              ? mensajeDeError(
                  error,
                  generico: 'No pudimos cargar el documento. Intenta de nuevo.',
                )
              : null,
        ),
      );
    }
  }
}
