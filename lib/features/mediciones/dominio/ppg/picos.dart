// lib/features/mediciones/dominio/ppg/picos.dart

/// La FC por el conteo de picos de la señal filtrada.
library;

import 'dart:math' as math;

import 'constantes.dart';
import 'estadistica.dart';

/// Los latidos: máximos locales con prominencia suficiente y separados al
/// menos [separacionMinima] segundos (210 lpm). Devuelve los instantes de
/// cada uno en segundos, afinados con una parábola.
List<double> detectarPicos(
  List<double> x, {
  double fs = frecuenciaAnalisis,
  double separacionMinima = 0.27,
}) {
  final n = x.length;
  if (n < 3) return const [];

  final candidatos = <int>[];
  for (var i = 1; i < n - 1; i++) {
    if (x[i] > x[i - 1] && x[i] >= x[i + 1]) candidatos.add(i);
  }
  if (candidatos.isEmpty) return const [];

  // Prominencia: cuánto sobresale el pico del valle más alto que lo separa
  // de un pico más alto (o del borde), a cada lado.
  final prominencias = <double>[];
  for (final i in candidatos) {
    var minIzq = x[i];
    for (var j = i - 1; j >= 0 && x[j] <= x[i]; j--) {
      if (x[j] < minIzq) minIzq = x[j];
    }
    var minDer = x[i];
    for (var j = i + 1; j < n && x[j] <= x[i]; j++) {
      if (x[j] < minDer) minDer = x[j];
    }
    prominencias.add(x[i] - math.max(minIzq, minDer));
  }

  final umbral = 0.3 * percentilDe(prominencias, 0.9);
  final separacion = (separacionMinima * fs).round();

  // Los más prominentes primero; se descarta lo que cae demasiado cerca de
  // uno ya elegido.
  final orden = [
    for (var k = 0; k < candidatos.length; k++)
      if (prominencias[k] >= umbral && prominencias[k] > 0) k,
  ]..sort((a, b) => prominencias[b].compareTo(prominencias[a]));

  final elegidos = <int>[];
  for (final k in orden) {
    final i = candidatos[k];
    if (elegidos.every((e) => (e - i).abs() >= separacion)) elegidos.add(i);
  }
  elegidos.sort();

  return [for (final i in elegidos) (i + _desplazamientoParabolico(x, i)) / fs];
}

double _desplazamientoParabolico(List<double> x, int i) {
  if (i <= 0 || i >= x.length - 1) return 0;
  final denominador = x[i - 1] - 2 * x[i] + x[i + 1];
  if (denominador == 0) return 0;
  return (0.5 * (x[i - 1] - x[i + 1]) / denominador).clamp(-0.5, 0.5);
}

/// La FC por el conteo de picos y qué tan regulares son los intervalos.
class ConteoDePicos {
  /// Latidos por minuto, por la mediana de los intervalos.
  final double fc;

  /// El coeficiente de variación de los intervalos válidos (0 = metrónomo).
  final double variacion;

  final int latidos;

  const ConteoDePicos({
    required this.fc,
    required this.variacion,
    required this.latidos,
  });
}

/// De los instantes de los latidos a la FC. Los intervalos fuera de
/// 42–210 lpm no cuentan. Con menos de cuatro latidos, `null`.
ConteoDePicos? fcPorPicos(List<double> instantes) {
  if (instantes.length < 4) return null;

  final intervalos = <double>[
    for (var i = 1; i < instantes.length; i++)
      if (instantes[i] - instantes[i - 1] >= 1 / fcMaximaHz &&
          instantes[i] - instantes[i - 1] <= 1 / fcMinimaHz)
        instantes[i] - instantes[i - 1],
  ];
  if (intervalos.length < 3) return null;

  final mediana = medianaDe(intervalos);
  final media = mediaDe(intervalos);
  return ConteoDePicos(
    fc: 60 / mediana,
    variacion: media <= 0 ? 1 : desviacionDe(intervalos) / media,
    latidos: instantes.length,
  );
}
