// lib/features/mediciones/dominio/ppg/espectro.dart

/// El espectro de la señal (Welch, con la FFT de `fftea`) y su pico.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

import 'constantes.dart';
import 'estadistica.dart';

/// Una densidad espectral de potencia: la potencia en cada frecuencia.
class Espectro {
  final Float64List potencia;

  /// La separación entre frecuencias, en Hz.
  final double paso;

  /// Lo que convierte una suma de potencias en la varianza de la señal en
  /// esa banda (Parseval, con la ventana y el relleno de [welch]).
  final double factorVarianza;

  const Espectro(this.potencia, this.paso, {this.factorVarianza = 0});

  /// La varianza de la parte de la señal que cae entre dos frecuencias: su
  /// raíz es la amplitud eficaz de esa banda, en las unidades de la señal.
  double varianzaEntre(double desdeHz, double hastaHz) =>
      potenciaEntre(desdeHz, hastaHz) * factorVarianza;

  double frecuencia(int indice) => indice * paso;

  int indice(double frecuenciaHz) =>
      (frecuenciaHz / paso).round().clamp(0, potencia.length - 1);

  /// La potencia total entre dos frecuencias.
  double potenciaEntre(double desdeHz, double hastaHz) {
    var suma = 0.0;
    for (var i = indice(desdeHz); i <= indice(hastaHz); i++) {
      suma += potencia[i];
    }
    return suma;
  }
}

int _potenciaDeDosDesde(int n) {
  var p = 1;
  while (p < n) {
    p <<= 1;
  }
  return p;
}

/// El método de Welch: la señal se parte en segmentos de
/// [segundosSegmento] con [solape], cada uno con ventana de Hann y
/// rellenado con ceros hasta [puntos] (potencia de dos), y se promedian
/// los periodogramas. Con menos datos que un segmento, es un periodograma
/// de toda la señal.
Espectro welch(
  List<double> x, {
  double fs = frecuenciaAnalisis,
  double segundosSegmento = 12,
  double solape = 0.5,
  int puntos = 4096,
}) {
  final n = x.length;
  final largo = math.min(n, (segundosSegmento * fs).round());
  final nfft = _potenciaDeDosDesde(math.max(puntos, largo));
  final potencia = Float64List(nfft ~/ 2 + 1);
  if (largo < 2) return Espectro(potencia, fs / nfft);

  final ventana = Window.hanning(largo);
  final fft = FFT(nfft);
  final avance = math.max(1, (largo * (1 - solape)).round());

  var segmentos = 0;
  for (var inicio = 0; inicio + largo <= n; inicio += avance) {
    final tramo = x.sublist(inicio, inicio + largo);
    final m = mediaDe(tramo);
    final entrada = Float64List(nfft);
    for (var i = 0; i < largo; i++) {
      entrada[i] = (tramo[i] - m) * ventana[i];
    }
    final cuadrados = fft
        .realFft(entrada)
        .discardConjugates()
        .squareMagnitudes();
    for (var i = 0; i < potencia.length; i++) {
      potencia[i] += cuadrados[i];
    }
    segmentos++;
  }
  if (segmentos > 1) {
    for (var i = 0; i < potencia.length; i++) {
      potencia[i] /= segmentos;
    }
  }

  var energiaVentana = 0.0;
  for (final w in ventana) {
    energiaVentana += w * w;
  }
  return Espectro(
    potencia,
    fs / nfft,
    factorVarianza: 2 / (nfft * energiaVentana),
  );
}

/// El pico de un espectro dentro de una banda.
class PicoEspectral {
  /// La frecuencia del pico, afinada con una parábola, en Hz.
  final double frecuencia;

  /// La potencia en el pico (±[anchoHz]) y su primer armónico, sobre la
  /// potencia de toda la banda: 1 es una sinusoide pura, y el ruido blanco
  /// queda cerca del ancho de las ventanas sobre el de la banda.
  final double prominencia;

  /// Cayó en el borde de la banda (o a menos de `margenBordeHz` de él): no
  /// es un pico de verdad, sino la cola de algo que está fuera.
  final bool enElBorde;

  const PicoEspectral({
    required this.frecuencia,
    required this.prominencia,
    this.enElBorde = false,
  });
}

/// Busca el pico de [espectro] entre [desdeHz] y [hastaHz].
///
/// Un pico a menos de [margenBordeHz] de un borde se marca
/// [PicoEspectral.enElBorde]: suele ser la fuga de una deriva más lenta.
///
/// Si el pico tiene a la mitad de su frecuencia otro con al menos el 40 %
/// de su potencia, se toma ese: es la fundamental y el primero era su
/// armónico (pasa con las ondas de pulso de muesca dícrota marcada).
PicoEspectral? picoEnBanda(
  Espectro espectro,
  double desdeHz,
  double hastaHz, {
  double anchoHz = 0.2,
  bool conArmonico = true,
  double margenBordeHz = 0,
}) {
  final p = espectro.potencia;
  final desde = espectro.indice(desdeHz);
  final hasta = espectro.indice(hastaHz);
  final total = espectro.potenciaEntre(desdeHz, hastaHz);
  if (total <= 0 || !total.isFinite) return null;

  int maximoEntre(int a, int b) {
    var mejor = a;
    for (var i = a; i <= b; i++) {
      if (p[i] > p[mejor]) mejor = i;
    }
    return mejor;
  }

  var k = maximoEntre(desde, hasta);

  // ¿Es un armónico? Se mira alrededor de la mitad.
  final mitad = espectro.frecuencia(k) / 2;
  if (mitad >= desdeHz) {
    final margen = math.max(1, espectro.indice(0.1));
    final a = math.max(desde, espectro.indice(mitad) - margen);
    final b = math.min(hasta, espectro.indice(mitad) + margen);
    final sub = maximoEntre(a, b);
    if (sub > desde && sub < hasta && p[sub] >= 0.4 * p[k]) {
      final esPico = p[sub] >= p[sub - 1] && p[sub] >= p[sub + 1];
      if (esPico) k = sub;
    }
  }

  // Parábola sobre los tres puntos del pico.
  var delta = 0.0;
  if (k > 0 && k < p.length - 1) {
    final denominador = p[k - 1] - 2 * p[k] + p[k + 1];
    if (denominador != 0) {
      delta = (0.5 * (p[k - 1] - p[k + 1]) / denominador).clamp(-0.5, 0.5);
    }
  }
  final f = (k + delta) * espectro.paso;

  var enPico = espectro.potenciaEntre(f - anchoHz, f + anchoHz);
  if (conArmonico && 2 * f + anchoHz <= hastaHz) {
    enPico += espectro.potenciaEntre(2 * f - anchoHz, 2 * f + anchoHz);
  }

  return PicoEspectral(
    frecuencia: f,
    prominencia: limitar01(enPico / total),
    enElBorde:
        k <= desde ||
        k >= hasta ||
        f < desdeHz + margenBordeHz ||
        f > hastaHz - margenBordeHz,
  );
}
