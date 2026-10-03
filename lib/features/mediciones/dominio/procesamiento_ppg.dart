// lib/features/mediciones/dominio/procesamiento_ppg.dart

/// El procesamiento de la fotopletismografía (PPG) del escáner experimental:
/// de una serie de números por cuadro a la frecuencia cardiaca, la
/// frecuencia respiratoria aproximada y la calidad de la señal.
///
/// Es **puro**: no sabe nada de la cámara ni de Flutter. Recibe tiempos y
/// valores (el promedio del canal rojo por cuadro en el modo dedo, o los
/// promedios RGB de la frente y las mejillas en el modo rostro) y devuelve
/// números. Por eso se prueba entero con señales sintéticas
/// (`test/procesamiento_ppg_test.dart`).
///
/// La cadena, en el orden en que se aplica:
///
/// 1. **Remuestrear** a [frecuenciaAnalisis] (30 Hz): la cámara no entrega
///    los cuadros a intervalos exactos y a veces se salta alguno.
/// 2. **Quitar la tendencia** con el método de los *smoothness priors*
///    (Tarvainen et al., 2002): se lleva la deriva lenta (la presión del
///    dedo que cambia, la luz que se mueve) sin tocar la banda del pulso.
/// 3. **Filtro pasa banda** Butterworth de 0,7 a 3,5 Hz (42–210 lpm), de
///    orden 4 por lado, aplicado hacia adelante y hacia atrás (fase cero).
/// 4. **Recortar artefactos**: los picos que pasan de varias veces la
///    desviación típica robusta (un movimiento brusco) se recortan.
/// 5. **FC por el espectro**: Welch (segmentos de 12 s con ventana de Hann
///    y solape del 50 %) y el pico de la banda, afinado con una parábola.
/// 6. **FC por el conteo de picos**: la mediana de los intervalos entre
///    latidos.
/// 7. **Calidad (SQI)**: la prominencia del pico espectral (la potencia en
///    la fundamental y su primer armónico sobre la de toda la banda), el
///    acuerdo entre los dos métodos, la regularidad de los intervalos y, en
///    el modo dedo, la cobertura de la yema y la saturación de la imagen.
/// 8. **FR**: en la banda de 0,1 a 0,5 Hz de la línea base y de la
///    envolvente (la amplitud de cada latido); solo con calidad ≥
///    [calidadMinimaFr].
///
/// El modo rostro pasa antes por **POS** (*Plane-Orthogonal-to-Skin*, Wang
/// et al., 2017), que combina los tres canales de modo que se cancelen los
/// cambios de brillo comunes y quede el pulso.
///
/// Nada de esto es un dispositivo médico: los valores son referenciales
/// (ver «Escáner experimental» en el README).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

/// La frecuencia a la que se remuestrea toda señal antes de analizarla.
const double frecuenciaAnalisis = 30;

/// La banda de la frecuencia cardiaca: 42 a 210 latidos por minuto.
const double fcMinimaHz = 0.7;
const double fcMaximaHz = 3.5;

/// La banda de la frecuencia respiratoria: 6 a 30 respiraciones por minuto.
const double frMinimaHz = 0.1;
const double frMaximaHz = 0.5;

/// Con menos calidad que esta no se da la frecuencia respiratoria.
const double calidadMinimaFr = 0.6;

/// Cuántos segundos hacen falta, como mínimo, para dar un resultado.
const double segundosMinimos = 8;

// ── Utilidades ─────────────────────────────────────────────────────────

double _media(List<double> x) {
  if (x.isEmpty) return 0;
  var suma = 0.0;
  for (final v in x) {
    suma += v;
  }
  return suma / x.length;
}

double _desviacion(List<double> x) {
  if (x.length < 2) return 0;
  final m = _media(x);
  var suma = 0.0;
  for (final v in x) {
    suma += (v - m) * (v - m);
  }
  return math.sqrt(suma / x.length);
}

double _mediana(List<double> x) {
  if (x.isEmpty) return 0;
  final ordenados = [...x]..sort();
  final mitad = ordenados.length ~/ 2;
  return ordenados.length.isOdd
      ? ordenados[mitad]
      : (ordenados[mitad - 1] + ordenados[mitad]) / 2;
}

double _percentil(List<double> x, double p) {
  if (x.isEmpty) return 0;
  final ordenados = [...x]..sort();
  final posicion = (ordenados.length - 1) * p;
  final abajo = posicion.floor();
  final arriba = posicion.ceil();
  if (abajo == arriba) return ordenados[abajo];
  return ordenados[abajo] +
      (ordenados[arriba] - ordenados[abajo]) * (posicion - abajo);
}

double _limitar(double x, [double minimo = 0, double maximo = 1]) =>
    x.isNaN ? minimo : x.clamp(minimo, maximo).toDouble();

/// De 0 (en [cero] o peor) a 1 (en [uno] o mejor), en línea recta. Sirve en
/// los dos sentidos: con [uno] < [cero], menos es mejor.
double _rampa(double x, double cero, double uno) =>
    _limitar((x - cero) / (uno - cero));

// ── 1. Remuestrear ─────────────────────────────────────────────────────

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
    final peso = tramo <= 0 ? 0.0 : _limitar((instante - t[j]) / tramo);
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

// ── 2. Quitar la tendencia ─────────────────────────────────────────────

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
    final m = _media(x);
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

// ── 3. Filtro pasa banda ───────────────────────────────────────────────

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

// ── 4. Artefactos ──────────────────────────────────────────────────────

/// Recorta lo que pasa de [veces] la desviación típica robusta (1,4826 ×
/// la mediana de las desviaciones absolutas): un movimiento brusco deja un
/// pico enorme que, sin recortar, se come el espectro entero.
Float64List recortarArtefactos(List<double> x, {double veces = 3.5}) {
  final mediana = _mediana(x);
  final mad = _mediana([for (final v in x) (v - mediana).abs()]);
  final limite = veces * 1.4826 * mad;
  if (limite <= 0) return Float64List.fromList(x);

  return Float64List.fromList([
    for (final v in x) mediana + (v - mediana).clamp(-limite, limite),
  ]);
}

// ── 5. Espectro ────────────────────────────────────────────────────────

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
    final m = _media(tramo);
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
    prominencia: _limitar(enPico / total),
    enElBorde:
        k <= desde ||
        k >= hasta ||
        f < desdeHz + margenBordeHz ||
        f > hastaHz - margenBordeHz,
  );
}

// ── 6. Conteo de picos ─────────────────────────────────────────────────

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

  final umbral = 0.3 * _percentil(prominencias, 0.9);
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

  final mediana = _mediana(intervalos);
  final media = _media(intervalos);
  return ConteoDePicos(
    fc: 60 / mediana,
    variacion: media <= 0 ? 1 : _desviacion(intervalos) / media,
    latidos: instantes.length,
  );
}

// ── 7. Calidad ─────────────────────────────────────────────────────────

/// Por qué la calidad salió baja, para darle a la persona un consejo útil.
enum MotivoCalidad {
  /// La señal no cambia: la cámara no ve el pulso (nada delante, o la yema
  /// apenas apoyada).
  senalPlana,

  /// En el modo dedo, la yema no cubre la cámara.
  sinCobertura,

  /// La imagen está quemada: se aprieta demasiado o hay demasiada luz.
  saturada,

  /// Hay pulso, pero el movimiento lo tapa.
  movimiento,

  /// La cámara entregó muy pocos cuadros por segundo.
  pocosCuadros,

  /// Muy pocos segundos para decir algo.
  pocosDatos,
}

/// Lo que se sabe de la calidad de una señal, de 0 a 1.
class CalidadSenal {
  final double valor;

  /// Prominencia del pico espectral (0–1).
  final double prominencia;

  /// Diferencia en lpm entre el espectro y el conteo de picos, o `null` si
  /// no hubo picos que contar.
  final double? desacuerdo;

  /// Variación de los intervalos entre latidos.
  final double? variacion;

  final MotivoCalidad? motivo;

  const CalidadSenal({
    required this.valor,
    this.prominencia = 0,
    this.desacuerdo,
    this.variacion,
    this.motivo,
  });

  static const CalidadSenal nula = CalidadSenal(
    valor: 0,
    motivo: MotivoCalidad.pocosDatos,
  );
}

/// Lo que se midió de la cámara, además de la señal, en el modo dedo.
class CondicionesDedo {
  /// Fracción media de la imagen cubierta por la yema (roja y brillante).
  final double cobertura;

  /// Fracción media de píxeles quemados en el canal usado.
  final double saturacion;

  const CondicionesDedo({required this.cobertura, required this.saturacion});
}

// ── El análisis ────────────────────────────────────────────────────────

/// El resultado del análisis de una señal PPG.
class AnalisisPpg {
  /// Frecuencia cardiaca en latidos por minuto, o `null` si no se pudo.
  final double? fc;

  /// Frecuencia respiratoria en respiraciones por minuto, o `null` si la
  /// calidad no alcanza ([calidadMinimaFr]) o no hay un pico claro.
  final double? fr;

  final CalidadSenal calidad;

  /// Las dos estimaciones, por separado.
  final double? fcEspectral;
  final double? fcPicos;

  /// La señal ya filtrada, para dibujar la onda.
  final Float64List senal;

  const AnalisisPpg({
    required this.calidad,
    required this.senal,
    this.fc,
    this.fr,
    this.fcEspectral,
    this.fcPicos,
  });
}

/// Analiza una señal PPG cualquiera, ya en una sola serie (el rojo del
/// dedo, con el signo cambiado, o la salida de [pos] del rostro).
///
/// [tiempos] en segundos. [dedo], si viene, entra en la calidad.
AnalisisPpg analizarSenal(
  List<double> tiempos,
  List<double> valores, {
  CondicionesDedo? dedo,
  double fs = frecuenciaAnalisis,
  bool conFr = true,
}) {
  final vacio = AnalisisPpg(calidad: CalidadSenal.nula, senal: Float64List(0));
  if (tiempos.length < 2) return vacio;

  final duracion = tiempos.last - tiempos.first;
  if (duracion < segundosMinimos) return vacio;

  if (cuadrosPorSegundo(tiempos) < 8) {
    return AnalisisPpg(
      calidad: const CalidadSenal(valor: 0, motivo: MotivoCalidad.pocosCuadros),
      senal: Float64List(0),
    );
  }

  final cruda = remuestrear(tiempos, valores, fs: fs);
  final sinTendencia = quitarTendencia(cruda, fs: fs, corteHz: 0.3);
  final filtrada = recortarArtefactos(
    filtrarIdaYVuelta(sinTendencia, pasaBanda(fcMinimaHz, fcMaximaHz, fs: fs)),
  );

  // Una señal plana: lo que queda en la banda es casi nada frente al nivel
  // de la luz (el pulso del dedo es del orden del 0,5 % del rojo).
  final nivel = _media(cruda.map((v) => v.abs()).toList());
  final amplitud = _desviacion(filtrada);
  final relativa = nivel > 0 ? amplitud / nivel : amplitud;
  if (amplitud <= 1e-9 || relativa < 1e-5) {
    return AnalisisPpg(
      calidad: const CalidadSenal(valor: 0, motivo: MotivoCalidad.senalPlana),
      senal: filtrada,
    );
  }

  final espectro = welch(filtrada, fs: fs);
  final pico = picoEnBanda(espectro, fcMinimaHz, fcMaximaHz);
  if (pico == null) {
    return AnalisisPpg(
      calidad: const CalidadSenal(valor: 0, motivo: MotivoCalidad.senalPlana),
      senal: filtrada,
    );
  }
  final fcEspectral = pico.frecuencia * 60;

  final conteo = fcPorPicos(detectarPicos(filtrada, fs: fs));
  final desacuerdo = conteo == null ? null : (conteo.fc - fcEspectral).abs();

  final calidad = calcularCalidad(
    prominencia: pico.prominencia,
    desacuerdo: desacuerdo,
    variacion: conteo?.variacion,
    dedo: dedo,
  );

  // La FC: la del espectro, que es la más estable; si el conteo coincide,
  // el promedio de las dos.
  final fc = desacuerdo != null && desacuerdo <= 3
      ? (fcEspectral + conteo!.fc) / 2
      : fcEspectral;

  final fr = conFr && calidad.valor >= calidadMinimaFr
      ? estimarFr(sinTendenciaLenta: cruda, filtrada: filtrada, fs: fs)
      : null;

  return AnalisisPpg(
    fc: fc,
    fr: fr,
    calidad: calidad,
    fcEspectral: fcEspectral,
    fcPicos: conteo?.fc,
    senal: filtrada,
  );
}

/// La calidad (SQI) a partir de sus partes. Pública para probarla.
///
/// - La **prominencia** pesa más: por debajo de 0,25 no hay pulso que se
///   distinga del ruido; desde 0,65 el pulso domina la banda.
/// - El **acuerdo** entre el espectro y el conteo de picos: hasta 3 lpm de
///   diferencia es pleno; desde 12, nulo.
/// - La **regularidad** de los intervalos (coeficiente de variación hasta
///   0,12 pleno; desde 0,4, nulo): el movimiento los desordena.
/// - En el modo dedo, la **cobertura** (desde 0,85 plena, por debajo de
///   0,5 nula) y la **saturación** (hasta 0,3 sin castigo, desde 0,85
///   nula).
CalidadSenal calcularCalidad({
  required double prominencia,
  double? desacuerdo,
  double? variacion,
  CondicionesDedo? dedo,
}) {
  final pProminencia = _rampa(prominencia, 0.25, 0.65);
  final pAcuerdo = desacuerdo == null ? 0.0 : _rampa(desacuerdo, 12, 3);
  final pRegular = variacion == null ? 0.0 : _rampa(variacion, 0.4, 0.12);

  var valor = pProminencia * (0.45 + 0.4 * pAcuerdo + 0.15 * pRegular);

  MotivoCalidad? motivo;
  if (pProminencia < 0.3) {
    motivo = MotivoCalidad.senalPlana;
  } else if (pAcuerdo < 0.5 || pRegular < 0.3) {
    motivo = MotivoCalidad.movimiento;
  }

  if (dedo != null) {
    final pCobertura = _rampa(dedo.cobertura, 0.5, 0.85);
    final pSaturacion = _rampa(dedo.saturacion, 0.85, 0.3);
    valor *= pCobertura * pSaturacion;
    if (pCobertura < 0.6) {
      motivo = MotivoCalidad.sinCobertura;
    } else if (pSaturacion < 0.6) {
      motivo = MotivoCalidad.saturada;
    }
  }

  valor = _limitar(valor);
  return CalidadSenal(
    valor: valor,
    prominencia: prominencia,
    desacuerdo: desacuerdo,
    variacion: variacion,
    motivo: valor >= 0.6 ? null : motivo,
  );
}

// ── 8. Frecuencia respiratoria ─────────────────────────────────────────

/// La frecuencia respiratoria aproximada, en respiraciones por minuto, o
/// `null` si no hay un pico claro.
///
/// La respiración modula la PPG de dos maneras: sube y baja la línea base
/// (RIIV) y cambia la amplitud de cada latido (RIAV). De cada una se
/// calcula el espectro en 0,1–0,5 Hz y entra en la cuenta solo si su
/// amplitud en la banda es apreciable (la línea base, al menos el
/// [riivMinima] de la amplitud del pulso; la amplitud de los latidos, al
/// menos un [riavMinima] de su media): así no se toma por respiración la
/// fuga mínima del pulso por el filtro. Si entran las dos, cada pico
/// tiene que ser claro por sí solo (prominencia ≥ 0,6) y coincidir con el
/// otro (±2,4 rpm). Los espectros se suman normalizados y
/// se busca el pico. Solo vale si es prominente (≥ 0,7) y
/// no cae en el borde de la banda: por debajo de 0,12 Hz suele ser la cola
/// de una deriva, no la respiración.
///
/// [sinTendenciaLenta] es la señal remuestreada (con su nivel), [filtrada]
/// la de la banda del pulso.
double? estimarFr({
  required List<double> sinTendenciaLenta,
  required List<double> filtrada,
  double fs = frecuenciaAnalisis,
  double riivMinima = 0.05,
  double riavMinima = 0.03,
}) {
  final n = sinTendenciaLenta.length;
  if (n / fs < 15) return null;

  Espectro espectroDe(List<double> x) =>
      welch(x, fs: fs, segundosSegmento: 60, puntos: 8192);

  final espectros = <Espectro>[];
  final pulso = _desviacion(filtrada);
  if (pulso <= 0) return null;

  // RIIV: la línea base, debajo de 0,6 Hz y sin la deriva más lenta.
  final base = espectroDe(
    quitarTendencia(
      filtrarIdaYVuelta(sinTendenciaLenta, pasaBajos(0.6, fs: fs), fs: fs),
      fs: fs,
      corteHz: 0.05,
    ),
  );
  if (math.sqrt(base.varianzaEntre(0.12, frMaximaHz)) / pulso >= riivMinima) {
    espectros.add(base);
  }

  // RIAV: la amplitud de cada latido (pico menos el valle anterior),
  // interpolada a la misma rejilla.
  final picos = detectarPicos(filtrada, fs: fs);
  if (picos.length >= 8) {
    final tiempos = <double>[];
    final valores = <double>[];
    for (var k = 1; k < picos.length; k++) {
      final desde = (picos[k - 1] * fs).round();
      final hasta = (picos[k] * fs).round().clamp(0, filtrada.length - 1);
      if (hasta <= desde) continue;
      var valle = filtrada[desde];
      for (var i = desde; i <= hasta; i++) {
        valle = math.min(valle, filtrada[i]);
      }
      tiempos.add(picos[k]);
      valores.add(filtrada[hasta] - valle);
    }
    final media = _media(valores);
    if (tiempos.length >= 6 && media > 0) {
      final rejilla = remuestrear(tiempos, valores, fs: fs);
      if (rejilla.length > fs * 15) {
        final amplitud = espectroDe(
          quitarTendencia(rejilla, fs: fs, corteHz: 0.05),
        );
        final relativa =
            math.sqrt(amplitud.varianzaEntre(0.12, frMaximaHz)) / media;
        if (relativa >= riavMinima) espectros.add(amplitud);
      }
    }
  }
  if (espectros.isEmpty) return null;

  PicoEspectral? picoDe(Espectro e) => picoEnBanda(
    e,
    frMinimaHz,
    frMaximaHz,
    anchoHz: 0.06,
    conArmonico: false,
    margenBordeHz: 0.02,
  );

  // Con las dos, tienen que coincidir: el ruido deja picos al azar, cada
  // uno por su lado; la respiración, el mismo en las dos.
  if (espectros.length == 2) {
    final a = picoDe(espectros[0]);
    final b = picoDe(espectros[1]);
    if (a == null || b == null) return null;
    if (a.prominencia < 0.6 || b.prominencia < 0.6) return null;
    if ((a.frecuencia - b.frecuencia).abs() > 0.04) return null;
  }

  // Se suman normalizados por su potencia en la banda, sobre la rejilla del
  // primero (todos tienen el mismo número de puntos).
  final suma = Float64List(espectros.first.potencia.length);
  for (final e in espectros) {
    final total = e.potenciaEntre(frMinimaHz, frMaximaHz);
    if (total <= 0) continue;
    for (var i = 0; i < suma.length && i < e.potencia.length; i++) {
      suma[i] += e.potencia[i] / total;
    }
  }

  final pico = picoDe(Espectro(suma, espectros.first.paso));
  if (pico == null || pico.enElBorde || pico.prominencia < 0.7) return null;

  return pico.frecuencia * 60;
}

// ── POS (modo rostro) ──────────────────────────────────────────────────

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
    final d1 = _desviacion(s1);
    final d2 = _desviacion(s2);
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

/// Analiza el modo rostro: remuestrea los tres canales, aplica [pos] y
/// sigue con [analizarSenal].
AnalisisPpg analizarRostro(
  List<double> tiempos,
  List<double> rojo,
  List<double> verde,
  List<double> azul, {
  double fs = frecuenciaAnalisis,
  bool conFr = true,
}) {
  if (tiempos.length < 2 || tiempos.last - tiempos.first < segundosMinimos) {
    return AnalisisPpg(calidad: CalidadSenal.nula, senal: Float64List(0));
  }
  if (cuadrosPorSegundo(tiempos) < 8) {
    return AnalisisPpg(
      calidad: const CalidadSenal(valor: 0, motivo: MotivoCalidad.pocosCuadros),
      senal: Float64List(0),
    );
  }

  final r = remuestrear(tiempos, rojo, fs: fs);
  final g = remuestrear(tiempos, verde, fs: fs);
  final b = remuestrear(tiempos, azul, fs: fs);
  final pulso = pos(r, g, b, fs: fs);

  // POS deja una señal sin nivel (media cero): para la comprobación de
  // señal plana se usa la amplitud relativa al verde.
  final nivel = _media(g);
  final escala = nivel > 0 ? nivel : 1.0;
  final tiemposRejilla = [for (var i = 0; i < pulso.length; i++) i / fs];

  return analizarSenal(
    tiemposRejilla,
    [for (final v in pulso) v * escala + escala],
    fs: fs,
    conFr: conFr,
  );
}
