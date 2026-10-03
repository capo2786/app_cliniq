// lib/features/mediciones/escaner/aviso_experimental.dart

import '../../../core/storage/cache_local.dart';

/// Si la persona ya leyó y aceptó el aviso del escáner («Función
/// experimental, no es un dispositivo médico…»).
///
/// Se recuerda en la caché cifrada (Hive), por persona: la primera vez se
/// enseña, después ya no. Como es de la persona, se borra al cerrar sesión
/// y al volver a entrar se enseña otra vez.
class AvisoDelEscaner {
  final CacheLocal _cache;

  const AvisoDelEscaner(this._cache);

  String _clave(String uid) => 'escaner-aviso:$uid';

  Future<bool> aceptado(String uid) async =>
      await _cache.leer(_clave(uid)) == true;

  Future<void> aceptar(String uid) => _cache.guardar(_clave(uid), true);
}
