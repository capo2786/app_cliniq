// lib/core/configuracion/config_publica_service.dart

import 'package:dio/dio.dart';

import '../network/api_interceptor.dart';
import '../storage/cache_local.dart';
import 'config_publica.dart';

/// La configuración ya cargada y de dónde salió.
class ConfigPublicaCargada {
  final ConfigPublica config;

  /// Salió de la copia del teléfono porque no hubo respuesta.
  final bool desdeCache;

  /// Cuándo se descargó la copia que se está usando.
  final DateTime? guardadaEn;

  const ConfigPublicaCargada({
    required this.config,
    required this.desdeCache,
    this.guardadaEn,
  });
}

/// No hay configuración: ni respuesta del servidor ni copia guardada.
class ConfiguracionNoDisponible implements Exception {
  final Object? causa;

  const ConfiguracionNoDisponible([this.causa]);

  @override
  String toString() => 'ConfiguracionNoDisponible($causa)';
}

/// `GET /configuracion/publica`: pública (`@Public()`), sin secretos.
///
/// Se pide sin sesión —la pantalla de acceso ya necesita el nombre y el
/// logotipo de la clínica— y cada respuesta buena se guarda en el teléfono.
/// Sin red se usa la última copia; sin copia, [ConfiguracionNoDisponible]:
/// nunca se inventan valores.
class ConfigPublicaService {
  static const String ruta = '/configuracion/publica';

  /// Con el prefijo `configuracion`, que es de la clínica y no de una
  /// persona: sobrevive al cierre de sesión (ver `prefijosDeLaClinica`).
  static const String claveCache = 'configuracion:publica';

  final Dio _dio;
  final CacheLocal _cache;
  final DateTime Function() _ahora;

  ConfigPublicaService(this._dio, this._cache, {DateTime Function()? ahora})
    : _ahora = ahora ?? DateTime.now;

  /// La última copia guardada, o `null` si nunca se descargó (o la copia no
  /// se puede leer).
  Future<ConfigPublicaCargada?> guardada() async {
    try {
      final datos = await _cache.leer(claveCache);
      if (datos is! Map) return null;

      return ConfigPublicaCargada(
        config: ConfigPublica.desdeJson(datos['datos']),
        desdeCache: true,
        guardadaEn: DateTime.tryParse(datos['guardadaEn']?.toString() ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  /// La del servidor; si no responde (o responde algo que no se puede leer),
  /// la guardada. Sin ninguna de las dos, [ConfiguracionNoDisponible].
  Future<ConfigPublicaCargada> cargar() async {
    try {
      return await descargar();
    } catch (error) {
      final copia = await guardada();
      if (copia != null) return copia;

      throw ConfiguracionNoDisponible(error);
    }
  }

  /// Solo la del servidor. Si es válida, reemplaza la copia guardada.
  Future<ConfigPublicaCargada> descargar() async {
    final respuesta = await _dio.get<dynamic>(
      ruta,
      options: Options(extra: const {rutaPublica: true}),
    );

    final config = ConfigPublica.desdeJson(respuesta.data);
    final ahora = _ahora();

    await _cache.guardar(claveCache, {
      'guardadaEn': ahora.toUtc().toIso8601String(),
      'datos': config.aJson(),
    });

    return ConfigPublicaCargada(
      config: config,
      desdeCache: false,
      guardadaEn: ahora,
    );
  }
}
