// lib/features/fotos_perfil/providers/foto_perfil_cubit.dart

import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/fotos_perfil_service.dart';
import '../data/selector_de_foto.dart';
import '../dominio/foto_perfil.dart';

/// En qué va el cambio de foto.
enum FaseFoto {
  /// Sin foto nueva elegida: se ofrece la cámara, la galería o quitar.
  eligiendo,

  /// Recortando la foto elegida.
  procesando,

  /// La foto nueva, recortada, esperando «Guardar» o «Cambiar».
  vistaPrevia,

  guardando,
  quitando,

  /// Se guardó o se quitó: la hoja se cierra.
  listo,
}

class FotoPerfilState extends Equatable {
  final FaseFoto fase;

  /// La foto nueva ya recortada (JPEG de 512 px), en la vista previa.
  final Uint8List? nueva;

  /// Qué salió mal, para decirlo dentro de la hoja.
  final String? error;

  /// Al terminar: se quitó la foto (y no se guardó una nueva).
  final bool quitada;

  /// Al terminar: la versión nueva, si la API la devolvió.
  final int? version;

  const FotoPerfilState({
    this.fase = FaseFoto.eligiendo,
    this.nueva,
    this.error,
    this.quitada = false,
    this.version,
  });

  bool get ocupado =>
      fase == FaseFoto.procesando ||
      fase == FaseFoto.guardando ||
      fase == FaseFoto.quitando;

  @override
  List<Object?> get props => [fase, nueva, error, quitada, version];
}

/// Elegir, recortar, guardar o quitar una foto de perfil: la propia o la de
/// un dependiente.
class FotoPerfilCubit extends Cubit<FotoPerfilState> {
  final FotosPerfilService _fotos;
  final SelectorDeFoto _selector;
  final Future<Uint8List> Function(Uint8List bytes) _recortar;

  /// De quién es la foto, si no es la propia (un dependiente): va a
  /// `/auth/:id/foto`. Sin él, a `/auth/me/foto`.
  final String? uid;

  /// El uid propio, para dejar la foto nueva en la caché.
  final String? uidPropio;

  FotoPerfilCubit({
    required this._fotos,
    required this._selector,
    Future<Uint8List> Function(Uint8List bytes)? recortar,
    this.uid,
    this.uidPropio,
  }) : _recortar = recortar ?? recortarFotoDePerfil,
       super(const FotoPerfilState());

  /// Abre la cámara o la galería y recorta lo elegido.
  Future<void> elegir(OrigenFoto origen) async {
    if (state.ocupado) return;

    final Uint8List? elegida;
    try {
      elegida = await _selector.elegir(origen);
    } catch (_) {
      if (isClosed) return;
      emit(
        FotoPerfilState(
          fase: state.nueva == null ? FaseFoto.eligiendo : FaseFoto.vistaPrevia,
          nueva: state.nueva,
          error: origen == OrigenFoto.camara
              ? 'No pudimos abrir la cámara. Revisa los permisos de la '
                    'aplicación en los ajustes del teléfono.'
              : 'No pudimos abrir tus fotos. Revisa los permisos de la '
                    'aplicación en los ajustes del teléfono.',
        ),
      );
      return;
    }

    // Se arrepintió: todo queda como estaba.
    if (elegida == null || isClosed) return;

    final anterior = state.nueva;
    emit(FotoPerfilState(fase: FaseFoto.procesando, nueva: anterior));

    try {
      final recortada = await _recortar(elegida);
      if (isClosed) return;
      emit(FotoPerfilState(fase: FaseFoto.vistaPrevia, nueva: recortada));
    } catch (_) {
      if (isClosed) return;
      emit(
        FotoPerfilState(
          fase: anterior == null ? FaseFoto.eligiendo : FaseFoto.vistaPrevia,
          nueva: anterior,
          error: 'No pudimos leer esa imagen. Prueba con otra foto.',
        ),
      );
    }
  }

  /// Sube la foto de la vista previa.
  Future<void> guardar() async {
    final nueva = state.nueva;
    if (nueva == null || state.ocupado) return;

    emit(FotoPerfilState(fase: FaseFoto.guardando, nueva: nueva));

    try {
      final version = await _fotos.subir(nueva, uid: uid, uidPropio: uidPropio);
      if (isClosed) return;
      emit(FotoPerfilState(fase: FaseFoto.listo, version: version));
    } catch (error) {
      if (isClosed) return;
      emit(
        FotoPerfilState(
          fase: FaseFoto.vistaPrevia,
          nueva: nueva,
          error: mensajeAlGuardarFoto(error),
        ),
      );
    }
  }

  /// Quita la foto guardada: vuelven las iniciales.
  Future<void> quitar() async {
    if (state.ocupado) return;

    final nueva = state.nueva;
    emit(FotoPerfilState(fase: FaseFoto.quitando, nueva: nueva));

    try {
      await _fotos.quitar(uid: uid, uidPropio: uidPropio);
      if (isClosed) return;
      emit(const FotoPerfilState(fase: FaseFoto.listo, quitada: true));
    } catch (error) {
      if (isClosed) return;
      emit(
        FotoPerfilState(
          fase: nueva == null ? FaseFoto.eligiendo : FaseFoto.vistaPrevia,
          nueva: nueva,
          error: mensajeDeError(
            error,
            generico: 'No pudimos quitar la foto. Intenta de nuevo.',
          ),
        ),
      );
    }
  }
}

/// Qué decir si la API no aceptó la foto.
///
/// El tamaño (413) y el tipo (415) se dicen con palabras propias: los
/// rechaza el servidor antes de llegar a la regla que explica el motivo, y
/// su texto puede no estar en español. Lo demás (la medida, 400; el
/// permiso), con el mensaje de la API.
String mensajeAlGuardarFoto(Object error) {
  return switch (estadoDe(error)) {
    413 => 'La foto pesa más de 1 MB. Prueba con otra.',
    415 => 'Ese tipo de imagen no se acepta. Usa una foto JPEG, PNG o WebP.',
    _ => mensajeDeError(
      error,
      generico: 'No pudimos guardar la foto. Intenta de nuevo.',
    ),
  };
}
