// lib/features/mediciones/dominio/ppg/estadistica.dart

/// Las cuentas básicas del procesamiento de la PPG.
library;

import 'dart:math' as math;

/// La media.
double mediaDe(List<double> x) {
  if (x.isEmpty) return 0;
  var suma = 0.0;
  for (final v in x) {
    suma += v;
  }
  return suma / x.length;
}

/// La desviación típica (poblacional).
double desviacionDe(List<double> x) {
  if (x.length < 2) return 0;
  final m = mediaDe(x);
  var suma = 0.0;
  for (final v in x) {
    suma += (v - m) * (v - m);
  }
  return math.sqrt(suma / x.length);
}

/// La mediana.
double medianaDe(List<double> x) {
  if (x.isEmpty) return 0;
  final ordenados = [...x]..sort();
  final mitad = ordenados.length ~/ 2;
  return ordenados.length.isOdd
      ? ordenados[mitad]
      : (ordenados[mitad - 1] + ordenados[mitad]) / 2;
}

/// El percentil [p] (0–1), interpolado.
double percentilDe(List<double> x, double p) {
  if (x.isEmpty) return 0;
  final ordenados = [...x]..sort();
  final posicion = (ordenados.length - 1) * p;
  final abajo = posicion.floor();
  final arriba = posicion.ceil();
  if (abajo == arriba) return ordenados[abajo];
  return ordenados[abajo] +
      (ordenados[arriba] - ordenados[abajo]) * (posicion - abajo);
}

/// [x] entre [minimo] y [maximo]; un NaN es [minimo].
double limitar01(double x, [double minimo = 0, double maximo = 1]) =>
    x.isNaN ? minimo : x.clamp(minimo, maximo).toDouble();

/// De 0 (en [cero] o peor) a 1 (en [uno] o mejor), en línea recta. Sirve en
/// los dos sentidos: con [uno] < [cero], menos es mejor.
double rampa(double x, double cero, double uno) =>
    limitar01((x - cero) / (uno - cero));
