// lib/features/fotos_perfil/dominio/foto_perfil.dart

import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// El lado, en píxeles, de la foto de perfil que se sube.
///
/// La API acepta de 128 a 1024 px por lado y hasta 1 MB; 512 px en JPEG
/// pesan entre 30 y 90 KB y se ven nítidos en el avatar más grande de la
/// aplicación (el del perfil, a 3× de densidad).
const int ladoFotoPerfil = 512;

/// La calidad JPEG de la foto que se sube.
const int calidadFotoPerfil = 85;

/// Dos letras para el avatar mientras no hay foto: «Ana María Pérez» → «AM».
String inicialesDe(String nombre) {
  final partes = nombre
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();

  if (partes.isEmpty) return '?';
  if (partes.length == 1) return partes.first[0].toUpperCase();

  return (partes[0][0] + partes[1][0]).toUpperCase();
}

/// La versión de la foto que manda la API (`fotoVersion`,
/// `doctorFotoVersion`…): un entero positivo, o `null` si no tiene foto.
int? versionDeFoto(Object? valor) {
  final version = switch (valor) {
    int v => v,
    num v => v.toInt(),
    String v => int.tryParse(v.trim()),
    _ => null,
  };

  return version == null || version <= 0 ? null : version;
}

/// La `fotoVersion` de la respuesta de `PUT …/foto`: el usuario actualizado,
/// suelto o dentro de `user`.
int? versionEnRespuesta(Object? datos) {
  if (datos is! Map) return null;

  final usuario = datos['user'] is Map ? datos['user'] as Map : datos;

  return versionDeFoto(usuario['fotoVersion']);
}

/// El cuadrado centrado más grande que cabe en una imagen de [ancho] ×
/// [alto]: su esquina superior izquierda y su lado.
({int x, int y, int lado}) recorteCentrado(int ancho, int alto) {
  if (ancho <= 0 || alto <= 0) {
    throw ArgumentError('La imagen no tiene tamaño ($ancho × $alto).');
  }

  final lado = ancho < alto ? ancho : alto;

  return (x: (ancho - lado) ~/ 2, y: (alto - lado) ~/ 2, lado: lado);
}

/// La imagen elegida, recortada en cuadrado al centro y pasada a JPEG de
/// [lado] px.
///
/// Corre en un isolate aparte: decodificar una foto de 1024 px en el hilo
/// de la interfaz se notaría como un tirón. Respeta la orientación EXIF de
/// la cámara. Lanza [FormatException] si los bytes no son una imagen que se
/// sepa leer.
Future<Uint8List> recortarFotoDePerfil(
  Uint8List bytes, {
  int lado = ladoFotoPerfil,
  int calidad = calidadFotoPerfil,
}) {
  return Isolate.run(
    () => recortarFotoDePerfilSincrono(bytes, lado: lado, calidad: calidad),
  );
}

/// Lo mismo que [recortarFotoDePerfil], en el hilo que lo llame.
Uint8List recortarFotoDePerfilSincrono(
  Uint8List bytes, {
  int lado = ladoFotoPerfil,
  int calidad = calidadFotoPerfil,
}) {
  final original = img.decodeImage(bytes);
  if (original == null) {
    throw const FormatException('No es una imagen que se pueda leer.');
  }

  final derecha = img.bakeOrientation(original);
  final corte = recorteCentrado(derecha.width, derecha.height);

  final cuadrada = img.copyCrop(
    derecha,
    x: corte.x,
    y: corte.y,
    width: corte.lado,
    height: corte.lado,
  );

  final reducida = img.copyResize(
    cuadrada,
    width: lado,
    height: lado,
    interpolation: corte.lado > lado
        ? img.Interpolation.average
        : img.Interpolation.linear,
  );

  // JPEG no tiene transparencia: lo transparente (una PNG) va sobre blanco,
  // no sobre negro
  final opaca = reducida.hasAlpha
      ? img.compositeImage(
          img.Image(width: lado, height: lado)
            ..clear(img.ColorRgb8(255, 255, 255)),
          reducida,
        )
      : reducida;

  return img.encodeJpg(opaca, quality: calidad);
}
