// lib/features/mediciones/dominio/ppg/respiracion.dart

/// La frecuencia respiratoria aproximada, por la modulación de la PPG.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'constantes.dart';
import 'espectro.dart';
import 'estadistica.dart';
import 'filtros.dart';
import 'picos.dart';
import 'tendencia.dart';

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
  final pulso = desviacionDe(filtrada);
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
    final media = mediaDe(valores);
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
