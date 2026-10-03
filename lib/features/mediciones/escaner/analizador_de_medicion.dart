// lib/features/mediciones/escaner/analizador_de_medicion.dart

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/analisis_en_servidor.dart';
import 'motor_signos_camara.dart';
import 'serie_senal.dart';

/// Decide quién analiza la medición al terminar.
///
/// El teléfono calcula siempre (es inmediato) y, si hay red, se pide el
/// análisis experimental del servidor con la misma serie de números. Si el
/// servidor responde a tiempo, manda su resultado («Analizado en el
/// servidor»); si falla, no hay red o tarda más de
/// [AnalisisEnServidor.plazo], queda el del teléfono («Calculado en el
/// teléfono»). Los valores nunca se mezclan: son de uno u otro, y su motor
/// queda en las notas de la medición. El detalle de la medición (las
/// gráficas) es siempre el del teléfono.
class AnalizadorDeMedicion {
  final MotorSignosCamara local;

  /// El del servidor; `null` para medir solo en el teléfono.
  final AnalisisEnServidor? servidor;

  /// Si hay red con lo que se sabe ahora (`SondeoDeRed.hayRed`).
  final bool Function() hayRed;

  /// Cuánto se espera al servidor.
  final Duration plazo;

  const AnalizadorDeMedicion({
    required this.local,
    required this.hayRed,
    this.servidor,
    this.plazo = AnalisisEnServidor.plazo,
  });

  Future<ResultadoEscaner> analizar(SerieSenal serie) async {
    final enElTelefono = local.analizar(serie);

    final remoto = servidor;
    if (remoto == null || !hayRed() || !AnalisisEnServidor.admite(serie)) {
      return enElTelefono;
    }

    try {
      final delServidor = await remoto.analizar(serie).timeout(plazo);
      // El detalle y las gráficas siempre salen del teléfono.
      return delServidor.conDetalle(enElTelefono.detalle);
    } catch (error) {
      debugPrint('Cliniq · escáner: el análisis del servidor no llegó: $error');
      return enElTelefono;
    }
  }
}
