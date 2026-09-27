// lib/core/configuracion/logo_clinica_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../network/api_interceptor.dart';
import '../storage/cache_local.dart';

/// Una imagen del logotipo: su tipo y sus bytes.
class ImagenDeLogo extends Equatable {
  final String mime;
  final Uint8List bytes;

  const ImagenDeLogo(this.mime, this.bytes);

  bool get esSvg => mime.contains('svg');

  @override
  List<Object?> get props => [mime, bytes];
}

/// El logotipo de la clínica desde su dirección
/// (`GET /configuracion/logo?v=…`), con copia en el teléfono.
///
/// La ruta es pública: se pide sin la sesión (`rutaPublica`), porque la
/// pantalla de acceso ya lo enseña. La copia va en la caché cifrada con el
/// prefijo `configuracion`, que es de la clínica: sobrevive al cierre de
/// sesión, igual que la configuración.
///
/// - La dirección lleva la huella del archivo (`?v=`): si no cambió, se usa
///   la copia y no se vuelve a bajar. Si cambió, se baja la nueva.
/// - Sin red, o si el servidor no lo entrega, la última copia guardada
///   aunque sea de la dirección anterior: mejor el logotipo de ayer que
///   ninguno. Sin copia, `null` y se ve el de marca.
class LogoClinicaService {
  static const String claveCache = 'configuracion:logo';

  /// Más de esto no es un logotipo (la clínica sube hasta 200 KB).
  static const int tamanoMaximo = 2 * 1024 * 1024;

  final Dio _dio;
  final CacheLocal _cache;

  final Map<String, ImagenDeLogo> _enMemoria = {};
  final Map<String, Future<ImagenDeLogo?>> _enCurso = {};

  LogoClinicaService(this._dio, this._cache);

  /// El de esa dirección, si ya se tiene en memoria: se pinta sin esperar.
  ImagenDeLogo? enMemoria(Uri url) => _enMemoria[url.toString()];

  /// El logotipo de [url]: de memoria, de la copia del teléfono o bajado.
  /// Varias pantallas a la vez comparten la misma petición.
  Future<ImagenDeLogo?> obtener(Uri url) {
    final clave = url.toString();
    final listo = _enMemoria[clave];
    if (listo != null) return SynchronousFuture(listo);

    // El bloque no devuelve nada a propósito: si devolviera lo que quita del
    // mapa (esta misma petición), `whenComplete` se quedaría esperándola.
    return _enCurso[clave] ??= _obtener(url).whenComplete(() {
      _enCurso.remove(clave);
    });
  }

  Future<ImagenDeLogo?> _obtener(Uri url) async {
    final clave = url.toString();
    final copia = await _leerCopia();

    if (copia != null && copia.url == clave) {
      return _enMemoria[clave] = copia.imagen;
    }

    try {
      final imagen = await _descargar(url);
      _enMemoria[clave] = imagen;
      await _cache.guardar(claveCache, {
        'url': clave,
        'mime': imagen.mime,
        'base64': base64Encode(imagen.bytes),
      });

      return imagen;
    } catch (error) {
      debugPrint('Cliniq · no se pudo bajar el logotipo: $error');
      if (copia == null) return null;

      // La de antes, hasta la próxima vez que se abra la aplicación.
      return _enMemoria[clave] = copia.imagen;
    }
  }

  Future<({String url, ImagenDeLogo imagen})?> _leerCopia() async {
    try {
      final datos = await _cache.leer(claveCache);
      if (datos is! Map) return null;

      final url = datos['url'];
      final mime = datos['mime'];
      final codificada = datos['base64'];
      if (url is! String || mime is! String || codificada is! String) {
        return null;
      }

      final bytes = base64Decode(codificada);
      if (bytes.isEmpty) return null;

      return (url: url, imagen: ImagenDeLogo(mime, bytes));
    } catch (_) {
      return null;
    }
  }

  Future<ImagenDeLogo> _descargar(Uri url) async {
    final respuesta = await _dio.getUri<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        headers: const {'Accept': 'image/*'},
        extra: const {rutaPublica: true},
      ),
    );

    final datos = respuesta.data ?? const <int>[];
    final bytes = datos is Uint8List ? datos : Uint8List.fromList(datos);
    if (bytes.isEmpty || bytes.length > tamanoMaximo) {
      throw const FormatException('El logotipo no tiene un tamaño válido');
    }

    final delServidor = respuesta.headers
        .value(Headers.contentTypeHeader)
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    final mime = tipoDeImagen(bytes, delServidor);
    if (mime == null) {
      throw const FormatException('El logotipo no es una imagen');
    }

    return ImagenDeLogo(mime, bytes);
  }
}

/// El tipo de una imagen de logotipo: el del servidor si es de imagen, o el
/// que dicen sus primeros bytes (PNG, JPG, WEBP o SVG). `null` si no es una
/// imagen.
String? tipoDeImagen(Uint8List bytes, String? delServidor) {
  if (delServidor != null && delServidor.startsWith('image/')) {
    return delServidor;
  }

  bool empieza(List<int> firma) {
    if (bytes.length < firma.length) return false;
    for (var i = 0; i < firma.length; i++) {
      if (bytes[i] != firma[i]) return false;
    }
    return true;
  }

  if (empieza(const [0x89, 0x50, 0x4e, 0x47])) return 'image/png';
  if (empieza(const [0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (empieza(const [0x52, 0x49, 0x46, 0x46]) &&
      bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }

  final inicio = utf8
      .decode(
        bytes.sublist(0, bytes.length < 1024 ? bytes.length : 1024),
        allowMalformed: true,
      )
      .toLowerCase();
  if (inicio.contains('<svg')) return 'image/svg+xml';

  return null;
}
