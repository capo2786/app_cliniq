// lib/features/ayuda/data/ayuda_contextual_service.dart

import 'package:dio/dio.dart';

import '../../../core/storage/cache_local.dart';
import '../../../core/storage/copia_guardada.dart';
import 'models/ayuda_de_accion.dart';

/// Los textos de los botones de ayuda («?»): `GET /ayuda/contextual`, con
/// la sesión.
///
/// El servidor manda solo los textos que tocan a los roles de quien entró
/// (para un paciente, las claves `app.*`), con las variables de la clínica
/// ya sustituidas. La respuesta se guarda en el teléfono tal como llegó, por
/// persona (se borra al cerrar sesión): sin red se usa esa copia, y sin copia
/// no hay textos y los botones no se enseñan. Nada se inventa.
class AyudaContextualService {
  static const String ruta = '/ayuda/contextual';

  final Dio _dio;
  final CacheLocal _cache;

  AyudaContextualService(this._dio, this._cache);

  String _clave(String uid) => 'ayuda-contextual:$uid';

  /// Pide los textos al servidor y guarda la copia. Lanza el error de la
  /// red o del servidor, o [FormatException] si la respuesta no se entiende
  /// (y entonces no se guarda).
  Future<Map<String, AyudaDeAccion>> pedir(String uid) async {
    final respuesta = await _dio.get<dynamic>(ruta);
    final mapa = interpretarMapaDeAyuda(respuesta.data);

    await _cache.guardarCopia(_clave(uid), respuesta.data);

    return mapa;
  }

  /// La última copia guardada de esa persona, si hay una legible.
  Future<Map<String, AyudaDeAccion>?> guardada(String uid) async {
    final copia = await _cache.leerCopia(_clave(uid));
    if (copia == null) return null;

    try {
      return interpretarMapaDeAyuda(copia.datos);
    } on FormatException {
      return null;
    }
  }
}
