import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/errores.dart';
import '../../../core/storage/cache_local.dart';
import 'models/cita.dart';

/// Las citas del paciente, con la copia guardada en el teléfono.
class ResultadoCitas {
  final List<Cita> citas;

  /// Vienen de la copia guardada porque no hubo conexión.
  final bool desdeCache;

  /// Cuándo se guardó esa copia (hora del teléfono).
  final DateTime? guardadasEn;

  const ResultadoCitas({
    required this.citas,
    this.desdeCache = false,
    this.guardadasEn,
  });
}

/// `GET /agenda/paciente/mis-citas`: las citas del titular y de sus
/// dependientes, con el nombre y la especialidad del médico ya adjuntos.
class CitasService {
  final Dio _dio;
  final CacheLocal _cache;

  CitasService(this._dio, this._cache);

  String _clave(String uid) => 'citas:$uid';

  /// Las citas desde el servidor; sin conexión, las guardadas.
  ///
  /// Solo cae a la copia cuando el problema es la red: un 403 o un 500 no se
  /// esconden detrás de datos viejos, se dicen.
  Future<ResultadoCitas> misCitas(String uid) async {
    try {
      final respuesta = await _dio.get<dynamic>('/agenda/paciente/mis-citas');
      final citas = interpretarCitas(respuesta.data);

      await _cache.guardar(_clave(uid), {
        'guardadasEn': DateTime.now().toUtc().toIso8601String(),
        'citas': [for (final c in citas) c.aJson()],
      });

      return ResultadoCitas(citas: citas);
    } catch (error) {
      if (!esFaltaDeRed(error)) rethrow;

      final guardadas = await citasGuardadas(uid);
      if (guardadas == null) rethrow;

      return guardadas;
    }
  }

  /// La última copia guardada de las citas de esta persona, si hay.
  Future<ResultadoCitas?> citasGuardadas(String uid) async {
    try {
      final datos = await _cache.leer(_clave(uid));
      if (datos is! Map || datos['citas'] is! List) return null;

      return ResultadoCitas(
        citas: interpretarCitas(datos['citas']),
        desdeCache: true,
        guardadasEn: DateTime.tryParse(
          datos['guardadasEn']?.toString() ?? '',
        )?.toLocal(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Lee la lista de citas, saltando las que no se puedan leer.
///
/// Una cita con una fecha rota no puede tumbar la pantalla entera: se
/// descarta y se deja constancia en depuración.
List<Cita> interpretarCitas(Object? datos) {
  if (datos is! List) return const [];

  final citas = <Cita>[];

  for (final item in datos) {
    if (item is! Map) continue;

    try {
      citas.add(Cita.desdeJson(item));
    } catch (error) {
      debugPrint('Cliniq · cita ilegible descartada: $error');
    }
  }

  return citas;
}
