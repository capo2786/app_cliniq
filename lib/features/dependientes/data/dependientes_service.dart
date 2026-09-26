import 'package:dio/dio.dart';

import '../../../core/network/errores.dart';
import '../../../core/storage/cache_local.dart';
import 'models/dependiente.dart';

/// Los dependientes del titular: `/portal/dependientes`.
///
/// El servidor solo deja ver y tocar los propios; cualquier otro responde
/// 404. Quitar uno con citas pendientes responde 409 con la explicación.
class DependientesService {
  final Dio _dio;
  final CacheLocal _cache;

  DependientesService(this._dio, this._cache);

  String _clave(String uid) => 'dependientes:$uid';

  /// La lista del servidor; sin conexión, la guardada.
  Future<({List<Dependiente> lista, bool desdeCache})> listar(
    String uid,
  ) async {
    try {
      final respuesta = await _dio.get<dynamic>('/portal/dependientes');
      final lista = interpretarDependientes(respuesta.data);

      await _cache.guardar(_clave(uid), [for (final d in lista) d.aJson()]);

      return (lista: lista, desdeCache: false);
    } catch (error) {
      if (!esFaltaDeRed(error)) rethrow;

      final guardada = await _cache.leer(_clave(uid));
      if (guardada is! List) rethrow;

      return (lista: interpretarDependientes(guardada), desdeCache: true);
    }
  }

  Future<Dependiente> crear(DatosDependiente datos) async {
    final respuesta = await _dio.post<dynamic>(
      '/portal/dependientes',
      data: datos.aJson(),
    );

    return Dependiente.desdeJson(respuesta.data as Map);
  }

  Future<Dependiente> actualizar(String id, DatosDependiente datos) async {
    final respuesta = await _dio.patch<dynamic>(
      '/portal/dependientes/$id',
      data: datos.aJson(),
    );

    return Dependiente.desdeJson(respuesta.data as Map);
  }

  Future<void> eliminar(String id) async {
    await _dio.delete<dynamic>('/portal/dependientes/$id');
  }
}

List<Dependiente> interpretarDependientes(Object? datos) {
  if (datos is! List) return const [];

  return [
      for (final d in datos)
        if (d is Map) Dependiente.desdeJson(d),
    ].where((d) => d.uid.isNotEmpty).toList()
    ..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
}
