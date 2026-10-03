// lib/features/mediciones/dominio/ppg/tendencia.dart

/// Remuestrear la serie de la cámara a una rejilla uniforme y quitarle la
/// tendencia lenta.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'constantes.dart';
import 'estadistica.dart';

/// Pasa una serie con tiempos irregulares ([tiempos] en segundos,
/// crecientes) a una con muestras cada `1 / fs` segundos, por
/// interpolación lineal. Los tiempos repetidos o que van hacia atrás se
/// descartan.
Float64List remuestrear(
  List<double> tiempos,
  List<double> valores, {
  double fs = frecuenciaAnalisis,
}) {
  assert(tiempos.length == valores.length);

  final t = <double>[];
  final v = <double>[];
  for (var i = 0; i < tiempos.length; i++) {
    if (!tiempos[i].isFinite || !valores[i].isFinite) continue;
    if (t.isNotEmpty && tiempos[i] <= t.last) continue;
    t.add(tiempos[i]);
    v.add(valores[i]);
  }
  if (t.length < 2) return Float64List.fromList(v);

  final n = ((t.last - t.first) * fs).floor() + 1;
  final salida = Float64List(n);
  var j = 0;
  for (var i = 0; i < n; i++) {
    final instante = t.first + i / fs;
    while (j < t.length - 2 && t[j + 1] < instante) {
      j++;
    }
    final tramo = t[j + 1] - t[j];
    final peso = tramo <= 0 ? 0.0 : limitar01((instante - t[j]) / tramo);
    salida[i] = v[j] + (v[j + 1] - v[j]) * peso;
  }
  return salida;
}

/// Cuántos cuadros por segundo llegaron de verdad: el escáner los necesita
/// para decir que la cámara va demasiado lenta.
double cuadrosPorSegundo(List<double> tiempos) {
  if (tiempos.length < 2) return 0;
  final duracion = tiempos.last - tiempos.first;
  return duracion <= 0 ? 0 : (tiempos.length - 1) / duracion;
}

/// Quita la tendencia lenta con *smoothness priors* (Tarvainen, Ranta-aho y
/// Karjalainen, 2002): la tendencia es la señal suavizada que resuelve
/// `(I + λ² D₂ᵀD₂) t = x`, y lo que queda, `x − t`, es la señal sin deriva.
///
/// [corteHz] es la frecuencia por debajo de la cual se quita: λ sale de
/// `f = fs / (2π√λ)`. El sistema es pentadiagonal y se resuelve en tiempo
/// lineal (LDLᵀ en banda).
Float64List quitarTendencia(
  List<double> x, {
  double fs = frecuenciaAnalisis,
  double corteHz = 0.3,
}) {
  final n = x.length;
  final salida = Float64List(n);
  if (n < 4) {
    final m = mediaDe(x);
    for (var i = 0; i < n; i++) {
      salida[i] = x[i] - m;
    }
    return salida;
  }

  final raiz = fs / (2 * math.pi * corteHz);
  final lambda2 = math.pow(raiz * raiz, 2).toDouble();

  // La matriz A = I + λ² D₂ᵀD₂, por diagonales.
  final d0 = Float64List(n);
  final d1 = Float64List(n); // A[i][i-1]
  final d2 = Float64List(n); // A[i][i-2]
  for (var i = 0; i < n; i++) {
    final diagonal = (i == 0 || i == n - 1)
        ? 1.0
        : (i == 1 || i == n - 2)
        ? 5.0
        : 6.0;
    d0[i] = 1 + lambda2 * diagonal;
    if (i >= 1) {
      d1[i] = lambda2 * ((i == 1 || i == n - 1) ? -2.0 : -4.0);
    }
    if (i >= 2) d2[i] = lambda2;
  }

  // LDLᵀ en banda: l1[i] = L[i][i-1], l2[i] = L[i][i-2].
  final d = Float64List(n);
  final l1 = Float64List(n);
  final l2 = Float64List(n);
  for (var i = 0; i < n; i++) {
    if (i >= 2) l2[i] = d2[i] / d[i - 2];
    if (i >= 1) {
      final resto = i >= 2 ? l2[i] * l1[i - 1] * d[i - 2] : 0.0;
      l1[i] = (d1[i] - resto) / d[i - 1];
    }
    var diagonal = d0[i];
    if (i >= 1) diagonal -= l1[i] * l1[i] * d[i - 1];
    if (i >= 2) diagonal -= l2[i] * l2[i] * d[i - 2];
    d[i] = diagonal;
  }

  // L y = x; D z = y; Lᵀ t = z.
  final tendencia = Float64List(n);
  for (var i = 0; i < n; i++) {
    var valor = x[i];
    if (i >= 1) valor -= l1[i] * tendencia[i - 1];
    if (i >= 2) valor -= l2[i] * tendencia[i - 2];
    tendencia[i] = valor;
  }
  for (var i = 0; i < n; i++) {
    tendencia[i] /= d[i];
  }
  for (var i = n - 1; i >= 0; i--) {
    var valor = tendencia[i];
    if (i + 1 < n) valor -= l1[i + 1] * tendencia[i + 1];
    if (i + 2 < n) valor -= l2[i + 2] * tendencia[i + 2];
    tendencia[i] = valor;
  }

  for (var i = 0; i < n; i++) {
    salida[i] = x[i] - tendencia[i];
  }
  return salida;
}
