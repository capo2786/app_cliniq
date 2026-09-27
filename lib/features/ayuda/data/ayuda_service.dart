// lib/features/ayuda/data/ayuda_service.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/errores.dart';
import '../../../core/storage/cache_local.dart';
import '../dominio/busqueda_ayuda.dart';
import 'models/articulo_ayuda.dart';

/// Artículos de ayuda y de dónde salieron.
class ResultadoAyuda {
  final List<ArticuloAyuda> articulos;

  /// Vienen de la copia guardada porque no hubo conexión.
  final bool desdeCache;
  final DateTime? guardadaEn;

  const ResultadoAyuda({
    required this.articulos,
    this.desdeCache = false,
    this.guardadaEn,
  });
}

/// El centro de ayuda con sesión: `GET /ayuda?q=`.
///
/// El servidor busca (todas las palabras, sin tildes) y ya reemplaza las
/// variables `{{…}}` con la configuración de la clínica. La lista completa
/// se guarda en el teléfono; sin conexión se busca sobre esa copia con la
/// misma regla.
class AyudaService {
  static const String _ruta = '/ayuda';

  final Dio _dio;
  final CacheLocal _cache;

  AyudaService(this._dio, this._cache);

  String _clave(String uid) => 'ayuda:$uid';

  /// Busca [q]; vacío, todos los artículos.
  Future<ResultadoAyuda> buscar(String uid, {String q = ''}) async {
    final texto = q.trim();

    try {
      final respuesta = await _dio.get<dynamic>(
        _ruta,
        queryParameters: {if (texto.isNotEmpty) 'q': texto},
      );
      final articulos = interpretarArticulos(respuesta.data);

      // Solo la lista completa: una búsqueda pisaría la copia.
      if (texto.isEmpty) await _guardar(uid, respuesta.data);

      return ResultadoAyuda(articulos: articulos);
    } catch (error) {
      if (!esFaltaDeRed(error)) rethrow;

      final copia = await guardados(uid);
      if (copia == null) rethrow;

      return ResultadoAyuda(
        articulos: filtrarArticulos(copia.articulos, texto),
        desdeCache: true,
        guardadaEn: copia.guardadaEn,
      );
    }
  }

  /// La última lista completa guardada, si hay.
  Future<ResultadoAyuda?> guardados(String uid) async {
    try {
      final copia = await _cache.leer(_clave(uid));
      if (copia is! Map || copia['datos'] is! List) return null;

      return ResultadoAyuda(
        articulos: interpretarArticulos(copia['datos']),
        desdeCache: true,
        guardadaEn: DateTime.tryParse(copia['guardadaEn']?.toString() ?? '')
            ?.toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _guardar(String uid, Object? datos) async {
    try {
      await _cache.guardar(_clave(uid), {
        'guardadaEn': DateTime.now().toUtc().toIso8601String(),
        'datos': datos,
      });
    } catch (error) {
      debugPrint('Cliniq · no se pudo guardar la ayuda: $error');
    }
  }
}
