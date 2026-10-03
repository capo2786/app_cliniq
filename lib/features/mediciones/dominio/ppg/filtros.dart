// lib/features/mediciones/dominio/ppg/filtros.dart

/// El filtro Butterworth (secciones biquad propias, aplicadas de ida y
/// vuelta) y el recorte de artefactos.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'constantes.dart';
import 'estadistica.dart';

/// Una sección de segundo orden (biquad) en forma directa II transpuesta.
///
/// Los coeficientes salen del *Audio EQ Cookbook* de Robert
/// Bristow-Johnson (transformada bilineal con la frecuencia de corte
/// exacta). Un Butterworth de orden 4 son dos secciones con Q 0,5412 y
/// 1,3066.
class Biquad {
  final double b0, b1, b2, a1, a2;

  const Biquad._(this.b0, this.b1, this.b2, this.a1, this.a2);

  factory Biquad._normalizado(
    double b0,
    double b1,
    double b2,
    double a0,
    double a1,
    double a2,
  ) => Biquad._(b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0);

  factory Biquad.pasaBajos(double corteHz, double fs, double q) {
    final w0 = 2 * math.pi * corteHz / fs;
    final coseno = math.cos(w0);
    final alfa = math.sin(w0) / (2 * q);
    return Biquad._normalizado(
      (1 - coseno) / 2,
      1 - coseno,
      (1 - coseno) / 2,
      1 + alfa,
      -2 * coseno,
      1 - alfa,
    );
  }

  factory Biquad.pasaAltos(double corteHz, double fs, double q) {
    final w0 = 2 * math.pi * corteHz / fs;
    final coseno = math.cos(w0);
    final alfa = math.sin(w0) / (2 * q);
    return Biquad._normalizado(
      (1 + coseno) / 2,
      -(1 + coseno),
      (1 + coseno) / 2,
      1 + alfa,
      -2 * coseno,
      1 - alfa,
    );
  }

  /// Filtra [x] una vez, hacia adelante, empezando en reposo.
  Float64List aplicar(List<double> x) {
    final y = Float64List(x.length);
    var z1 = 0.0;
    var z2 = 0.0;
    for (var i = 0; i < x.length; i++) {
      final entrada = x[i];
      final salida = b0 * entrada + z1;
      z1 = b1 * entrada - a1 * salida + z2;
      z2 = b2 * entrada - a2 * salida;
      y[i] = salida;
    }
    return y;
  }

  /// La ganancia en [frecuenciaHz] (el módulo de la respuesta en
  /// frecuencia), para comprobar el diseño.
  double ganancia(double frecuenciaHz, double fs) {
    final w = 2 * math.pi * frecuenciaHz / fs;
    // H(e^jw) = (b0 + b1 e^-jw + b2 e^-2jw) / (1 + a1 e^-jw + a2 e^-2jw)
    final numRe = b0 + b1 * math.cos(w) + b2 * math.cos(2 * w);
    final numIm = -b1 * math.sin(w) - b2 * math.sin(2 * w);
    final denRe = 1 + a1 * math.cos(w) + a2 * math.cos(2 * w);
    final denIm = -a1 * math.sin(w) - a2 * math.sin(2 * w);
    return math.sqrt(
      (numRe * numRe + numIm * numIm) / (denRe * denRe + denIm * denIm),
    );
  }
}

const List<double> _qButterworth4 = [0.5411961, 1.3065630];

/// Las secciones de un pasa banda Butterworth: un pasa altos de orden 4 en
/// [bajaHz] seguido de un pasa bajos de orden 4 en [altaHz].
List<Biquad> pasaBanda(
  double bajaHz,
  double altaHz, {
  double fs = frecuenciaAnalisis,
}) => [
  for (final q in _qButterworth4) Biquad.pasaAltos(bajaHz, fs, q),
  for (final q in _qButterworth4) Biquad.pasaBajos(altaHz, fs, q),
];

/// Las secciones de un pasa bajos Butterworth de orden 4.
List<Biquad> pasaBajos(double corteHz, {double fs = frecuenciaAnalisis}) => [
  for (final q in _qButterworth4) Biquad.pasaBajos(corteHz, fs, q),
];

/// La ganancia de una cadena de secciones en una frecuencia.
double gananciaDe(List<Biquad> secciones, double frecuenciaHz, double fs) {
  var g = 1.0;
  for (final s in secciones) {
    g *= s.ganancia(frecuenciaHz, fs);
  }
  return g;
}

/// Aplica [secciones] hacia adelante y hacia atrás (como `filtfilt`): la
/// fase queda en cero —los picos no se corren— y la atenuación se duplica.
/// Los bordes se alargan con su reflejo impar y cada pasada arranca en
/// régimen, para que el arranque del filtro no deje un transitorio.
Float64List filtrarIdaYVuelta(
  List<double> x,
  List<Biquad> secciones, {
  double fs = frecuenciaAnalisis,
}) {
  final n = x.length;
  if (n < 3) return Float64List.fromList(x);

  final relleno = math.min(n - 1, (fs * 3).round());
  final extendida = Float64List(n + 2 * relleno);
  for (var i = 0; i < relleno; i++) {
    extendida[i] = 2 * x[0] - x[relleno - i];
    extendida[n + relleno + i] = 2 * x[n - 1] - x[n - 2 - i];
  }
  for (var i = 0; i < n; i++) {
    extendida[relleno + i] = x[i];
  }

  // Cada pasada arranca «en régimen» para el primer valor: se le resta y
  // se le devuelve multiplicado por la ganancia en continua (1 en un pasa
  // bajos, 0 en un pasa altos). Por linealidad es lo mismo que iniciar el
  // filtro en su estado estacionario, y evita el escalón de arrancar en
  // reposo con una señal de nivel 180.
  final gananciaContinua = gananciaDe(secciones, 0, fs);
  List<double> pasada(List<double> entrada) {
    final inicio = entrada.first;
    List<double> y = [for (final v in entrada) v - inicio];
    for (final s in secciones) {
      y = s.aplicar(y);
    }
    return [for (final v in y) v + inicio * gananciaContinua];
  }

  final y = pasada(pasada(extendida).reversed.toList());

  final salida = Float64List(n);
  for (var i = 0; i < n; i++) {
    salida[i] = y[y.length - 1 - relleno - i];
  }
  return salida;
}

/// Recorta lo que pasa de [veces] la desviación típica robusta (1,4826 ×
/// la mediana de las desviaciones absolutas): un movimiento brusco deja un
/// pico enorme que, sin recortar, se come el espectro entero.
Float64List recortarArtefactos(List<double> x, {double veces = 3.5}) {
  final mediana = medianaDe(x);
  final mad = medianaDe([for (final v in x) (v - mediana).abs()]);
  final limite = veces * 1.4826 * mad;
  if (limite <= 0) return Float64List.fromList(x);

  return Float64List.fromList([
    for (final v in x) mediana + (v - mediana).clamp(-limite, limite),
  ]);
}
