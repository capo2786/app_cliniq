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
/// Cada paso vive en su archivo de `ppg/` (tendencia, filtros, espectro,
/// picos, calidad, respiración y POS); este los junta y los reexporta.
///
/// Nada de esto es un dispositivo médico: los valores son referenciales
/// (ver «Escáner experimental» en el README).
library;

import 'dart:typed_data';

import 'ppg/calidad.dart';
import 'ppg/constantes.dart';
import 'ppg/espectro.dart';
import 'ppg/estadistica.dart';
import 'ppg/filtros.dart';
import 'ppg/picos.dart';
import 'ppg/pos.dart';
import 'ppg/respiracion.dart';
import 'ppg/tendencia.dart';

export 'ppg/calidad.dart';
export 'ppg/constantes.dart';
export 'ppg/espectro.dart';
export 'ppg/fc_por_ventana.dart';
export 'ppg/filtros.dart';
export 'ppg/picos.dart';
export 'ppg/pos.dart';
export 'ppg/respiracion.dart';
export 'ppg/tendencia.dart';

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

  /// Los instantes de los latidos detectados en [senal], en segundos desde
  /// su primera muestra.
  final List<double> latidos;

  /// El espectro de [senal] (Welch), si se llegó a calcular.
  final Espectro? espectro;

  /// La señal remuestreada, antes de filtrar (con su nivel): de ella sale
  /// la onda lenta de la respiración.
  final Float64List? remuestreada;

  /// La frecuencia de muestreo de [senal] y [remuestreada].
  final double fs;

  const AnalisisPpg({
    required this.calidad,
    required this.senal,
    this.fc,
    this.fr,
    this.fcEspectral,
    this.fcPicos,
    this.latidos = const [],
    this.espectro,
    this.remuestreada,
    this.fs = frecuenciaAnalisis,
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
  final nivel = mediaDe(cruda.map((v) => v.abs()).toList());
  final amplitud = desviacionDe(filtrada);
  final relativa = nivel > 0 ? amplitud / nivel : amplitud;
  if (amplitud <= 1e-9 || relativa < 1e-5) {
    return AnalisisPpg(
      calidad: const CalidadSenal(valor: 0, motivo: MotivoCalidad.senalPlana),
      senal: filtrada,
      fs: fs,
    );
  }

  final espectro = welch(filtrada, fs: fs);
  final pico = picoEnBanda(espectro, fcMinimaHz, fcMaximaHz);
  if (pico == null) {
    return AnalisisPpg(
      calidad: const CalidadSenal(valor: 0, motivo: MotivoCalidad.senalPlana),
      senal: filtrada,
      fs: fs,
    );
  }
  final fcEspectral = pico.frecuencia * 60;

  final latidos = detectarPicos(filtrada, fs: fs);
  final conteo = fcPorPicos(latidos);
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
    latidos: latidos,
    espectro: espectro,
    remuestreada: cruda,
    fs: fs,
  );
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
  final nivel = mediaDe(g);
  final escala = nivel > 0 ? nivel : 1.0;
  final tiemposRejilla = [for (var i = 0; i < pulso.length; i++) i / fs];

  return analizarSenal(
    tiemposRejilla,
    [for (final v in pulso) v * escala + escala],
    fs: fs,
    conFr: conFr,
  );
}
