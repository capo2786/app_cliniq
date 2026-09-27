// lib/core/storage/copia_guardada.dart

import 'package:flutter/foundation.dart';

import 'cache_local.dart';

/// Una respuesta de la API guardada tal como llegó, y cuándo se guardó.
///
/// Guardar la respuesta entera (y no un modelo ya leído) conserva lo que
/// esta versión todavía no enseña, y la copia se vuelve a leer con el mismo
/// código que lee la respuesta del servidor.
class CopiaGuardada {
  final Object? datos;

  /// Hora del teléfono en que se guardó.
  final DateTime? guardadaEn;

  const CopiaGuardada({required this.datos, this.guardadaEn});
}

/// Guardar y leer copias de respuestas de la API en la caché local.
extension CopiasDeLaApi on CacheLocal {
  /// Guarda [datos] (lo que llegó del servidor) con la hora de ahora. Un
  /// fallo al guardar no se propaga: se pierde la copia, no la pantalla.
  Future<void> guardarCopia(String clave, Object? datos) async {
    try {
      await guardar(clave, {
        'guardadaEn': DateTime.now().toUtc().toIso8601String(),
        'datos': datos,
      });
    } catch (error) {
      debugPrint('Cliniq · no se pudo guardar $clave: $error');
    }
  }

  /// La copia guardada con esa clave, o `null` si no hay o no se puede leer.
  Future<CopiaGuardada?> leerCopia(String clave) async {
    try {
      final copia = await leer(clave);
      if (copia is! Map || !copia.containsKey('datos')) return null;

      return CopiaGuardada(
        datos: copia['datos'],
        guardadaEn: DateTime.tryParse(copia['guardadaEn']?.toString() ?? '')
            ?.toLocal(),
      );
    } catch (_) {
      return null;
    }
  }
}
