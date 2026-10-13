// test/dobles/fotos_perfil.dart

import 'dart:typed_data';

import 'package:app_cliniq/features/fotos_perfil/data/fotos_perfil_service.dart';
import 'package:app_cliniq/features/fotos_perfil/data/selector_de_foto.dart';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;

/// Una imagen PNG de [ancho] × [alto], de un color, para las pruebas.
Uint8List pngDePrueba(int ancho, int alto) {
  final imagen = img.Image(width: ancho, height: alto);
  img.fill(imagen, color: img.ColorRgb8(200, 120, 80));
  return img.encodePng(imagen);
}

/// Unos bytes que hacen de JPEG ya recortado (empiezan como uno).
final Uint8List jpegFalso = Uint8List.fromList([0xFF, 0xD8, 0xFF, 1, 2, 3]);

/// La cámara y la galería, con lo que la prueba programe.
class SelectorDeFotoFalso implements SelectorDeFoto {
  /// Lo que devuelve; `null` es «se arrepintió».
  Uint8List? foto;

  /// Si se pone, `elegir` lanza esto (un permiso negado).
  Object? error;

  final List<OrigenFoto> pedidos = [];

  SelectorDeFotoFalso({this.foto, this.error});

  @override
  Future<Uint8List?> elegir(OrigenFoto origen) async {
    pedidos.add(origen);
    if (error != null) throw error!;
    return foto;
  }
}

/// El servicio de fotos sin red ni disco: contesta lo que la prueba
/// programe y anota lo que se le pidió.
class FotosPerfilFalso extends FotosPerfilService {
  final Map<String, Uint8List> fotos;
  final List<String> llamadas = [];

  /// La versión que devuelve `subir`.
  int? versionNueva;

  /// Si se pone, `subir` y `quitar` lanzan esto.
  Object? error;

  FotosPerfilFalso({Map<String, Uint8List>? fotos, this.versionNueva = 2})
    : fotos = fotos ?? {},
      super(Dio());

  @override
  Uint8List? enMemoria(String uid, int? version) => null;

  @override
  Future<Uint8List?> obtener(String uid, int? version) async {
    llamadas.add('obtener:$uid@$version');
    return version == null ? null : fotos['$uid@$version'];
  }

  @override
  Uint8List? vigenteEnMemoria(String uid) => null;

  @override
  Future<Uint8List?> obtenerVigente(String uid) async {
    llamadas.add('vigente:$uid');
    return fotos['$uid@vigente'];
  }

  @override
  Future<int?> subir(Uint8List jpeg, {String? uid, String? uidPropio}) async {
    llamadas.add('subir:${uid ?? 'me'}');
    if (error != null) throw error!;
    return versionNueva;
  }

  @override
  Future<void> quitar({String? uid, String? uidPropio}) async {
    llamadas.add('quitar:${uid ?? 'me'}');
    if (error != null) throw error!;
  }
}
