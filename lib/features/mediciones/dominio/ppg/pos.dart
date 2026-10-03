// lib/features/mediciones/dominio/ppg/pos.dart

/// POS: la señal del pulso a partir de los tres colores del rostro.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'constantes.dart';
import 'estadistica.dart';

/// *Plane-Orthogonal-to-Skin* (Wang, den Brinker, Stuijk y de Haan, 2017).
///
/// En ventanas de [segundosVentana] se normaliza cada canal por su media,
/// se proyecta sobre el plano ortogonal al tono de la piel
/// (`S₁ = G − B`, `S₂ = G + B − 2R`) y se combinan las dos proyecciones
/// con el cociente de sus desviaciones (`h = S₁ + σ₁/σ₂ · S₂`); las
/// ventanas se suman solapadas. Los cambios de brillo, que afectan a los
/// tres canales por igual, se cancelan, y queda el pulso.
///
/// Las tres listas son los promedios por cuadro, ya remuestreados a [fs].
Float64List pos(
  List<double> rojo,
  List<double> verde,
  List<double> azul, {
  double fs = frecuenciaAnalisis,
  double segundosVentana = 1.6,
}) {
  final n = math.min(rojo.length, math.min(verde.length, azul.length));
  final h = Float64List(n);
  final l = (segundosVentana * fs).ceil();
  if (n < l) return h;

  final s1 = Float64List(l);
  final s2 = Float64List(l);
  for (var fin = l - 1; fin < n; fin++) {
    final inicio = fin - l + 1;
    var mr = 0.0, mg = 0.0, mb = 0.0;
    for (var i = inicio; i <= fin; i++) {
      mr += rojo[i];
      mg += verde[i];
      mb += azul[i];
    }
    mr /= l;
    mg /= l;
    mb /= l;
    if (mr <= 0 || mg <= 0 || mb <= 0) continue;

    for (var i = 0; i < l; i++) {
      final r = rojo[inicio + i] / mr;
      final g = verde[inicio + i] / mg;
      final b = azul[inicio + i] / mb;
      s1[i] = g - b;
      s2[i] = g + b - 2 * r;
    }
    final d1 = desviacionDe(s1);
    final d2 = desviacionDe(s2);
    final alfa = d2 > 0 ? d1 / d2 : 0.0;

    var media = 0.0;
    for (var i = 0; i < l; i++) {
      media += s1[i] + alfa * s2[i];
    }
    media /= l;
    for (var i = 0; i < l; i++) {
      h[inicio + i] += s1[i] + alfa * s2[i] - media;
    }
  }
  return h;
}
