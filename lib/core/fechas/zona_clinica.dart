// lib/core/fechas/zona_clinica.dart

import 'package:flutter/foundation.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// La zona horaria de la clínica, la que dice la configuración pública
/// (`clinica.zonaHoraria`, p. ej. `America/Guayaquil`).
///
/// Antes se suponía Ecuador continental con UTC−5 fijo. Ahora la zona la dice
/// el servidor, y el desfase de cada instante sale de la base de datos de
/// zonas del paquete `timezone`: una clínica en una zona con horario de
/// verano también queda bien.
///
/// Mientras no se conoce la configuración —el primer arranque, antes de la
/// primera respuesta— el desfase es cero. Ninguna pantalla con fechas se ve
/// en ese momento: la aplicación espera la configuración antes de enseñar
/// nada (ver `EsperaDatosDeLaClinica`).
class ZonaClinica {
  const ZonaClinica._();

  static bool _baseCargada = false;
  static tz.Location? _ubicacion;

  /// La zona en uso, o `null` si todavía no se conoce.
  static tz.Location? get ubicacion => _ubicacion;

  /// El nombre IANA en uso (`America/Guayaquil`), o `null`.
  static String? get nombre => _ubicacion?.name;

  /// Aplica la zona que manda el servidor. Un nombre que la base de zonas no
  /// conoce se descarta y se conserva la zona anterior: un error del servidor
  /// no puede correr todas las horas de la aplicación.
  static bool aplicar(String nombreIana) {
    final nombre = nombreIana.trim();
    if (nombre.isEmpty) return false;
    if (_ubicacion?.name == nombre) return true;

    try {
      if (!_baseCargada) {
        tz_data.initializeTimeZones();
        _baseCargada = true;
      }

      _ubicacion = tz.getLocation(nombre);
      return true;
    } catch (error) {
      debugPrint('Cliniq · zona horaria desconocida «$nombre»: $error');
      return false;
    }
  }

  /// La diferencia de la clínica con UTC en ese instante.
  static Duration desfaseEn(DateTime instante) {
    final zona = _ubicacion;
    if (zona == null) return Duration.zero;

    final ms = instante.toUtc().millisecondsSinceEpoch;
    return zona.timeZone(ms).offset;
  }

  /// Olvida la zona. Solo para pruebas.
  @visibleForTesting
  static void olvidar() => _ubicacion = null;
}
