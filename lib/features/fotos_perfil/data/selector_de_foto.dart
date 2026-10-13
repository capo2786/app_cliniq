// lib/features/fotos_perfil/data/selector_de_foto.dart

import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// De dónde sale la foto de perfil.
enum OrigenFoto { camara, galeria }

/// La cámara o la galería, para la foto de perfil.
///
/// Es una interfaz para que las pruebas elijan una foto sin cámara ni
/// galería.
abstract class SelectorDeFoto {
  /// Los bytes de la foto elegida, o `null` si la persona se arrepintió.
  Future<Uint8List?> elegir(OrigenFoto origen);
}

/// La cámara y la galería del teléfono, con `image_picker`.
///
/// La foto llega ya reducida a 1024 px de lado (lo más que acepta la API):
/// el recorte a 512 px que sigue trabaja sobre una imagen pequeña y rápida.
class SelectorDeFotoDelSistema implements SelectorDeFoto {
  static const double ladoMaximo = 1024;
  static const int calidad = 92;

  final ImagePicker _fotos;

  SelectorDeFotoDelSistema([ImagePicker? fotos])
    : _fotos = fotos ?? ImagePicker();

  @override
  Future<Uint8List?> elegir(OrigenFoto origen) async {
    final foto = await _fotos.pickImage(
      source: origen == OrigenFoto.camara
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: ladoMaximo,
      maxHeight: ladoMaximo,
      imageQuality: calidad,
      // La cámara frontal, la de las fotos de perfil.
      preferredCameraDevice: CameraDevice.front,
      // Sin pedir los metadatos completos, iOS no necesita el permiso de la
      // fototeca para elegir: basta con su selector.
      requestFullMetadata: false,
    );

    return foto?.readAsBytes();
  }
}
