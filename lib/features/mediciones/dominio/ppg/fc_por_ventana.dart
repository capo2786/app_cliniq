// lib/features/mediciones/dominio/ppg/fc_por_ventana.dart

/// La frecuencia cardiaca a lo largo de la medición: una estimación por
/// segundo, cada una sobre los segundos anteriores.
library;

import 'dart:math' as math;

import 'constantes.dart';
import 'espectro.dart';

/// Una estimación de la FC en un momento de la medición.
typedef PuntoFc = ({double segundo, double fc});

/// La FC cada [paso] segundos sobre ventanas de [segundosVentana] de la
/// señal ya filtrada (el mismo Welch y el mismo pico que el análisis
/// entero). Solo entran las ventanas con un pico claro (prominencia ≥
/// [prominenciaMinima]): lo demás no se sabe y no se dibuja.
///
/// El [PuntoFc.segundo] es el final de cada ventana, desde la primera
/// muestra.
List<PuntoFc> fcPorVentana(
  List<double> filtrada, {
  double fs = frecuenciaAnalisis,
  double segundosVentana = 8,
  double paso = 1,
  double prominenciaMinima = 0.35,
}) {
  final largo = (segundosVentana * fs).round();
  final avance = math.max(1, (paso * fs).round());
  if (filtrada.length < largo || largo < 2) return const [];

  final puntos = <PuntoFc>[];
  for (var fin = largo; fin <= filtrada.length; fin += avance) {
    final tramo = filtrada.sublist(fin - largo, fin);
    final pico = picoEnBanda(
      welch(tramo, fs: fs, segundosSegmento: segundosVentana),
      fcMinimaHz,
      fcMaximaHz,
    );
    if (pico == null || pico.prominencia < prominenciaMinima) continue;
    puntos.add((segundo: fin / fs, fc: pico.frecuencia * 60));
  }
  return puntos;
}
