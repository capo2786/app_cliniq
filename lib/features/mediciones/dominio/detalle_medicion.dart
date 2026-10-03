// lib/features/mediciones/dominio/detalle_medicion.dart

/// El «Detalle de la medición» del escáner: los datos y las gráficas que
/// salen de la misma serie, calculados **en el teléfono**.
///
/// Puro e inmutable. Reúne lo que el análisis ya calculó (la señal
/// filtrada, los latidos, el espectro, la señal remuestreada) sin volver a
/// calcularlo, y agrega lo que falta: la FC por segundo, los intervalos
/// limpios con sus medidas (pNN50, SD1, SD2) y la onda lenta de la
/// respiración. No se guarda en el servidor.
library;

import 'dart:math' as math;

import 'procesamiento_ppg.dart';
import 'reglas_mediciones.dart';

/// Un punto del espectro para dibujar: la frecuencia en lpm y la potencia
/// relativa (1 en el máximo de la banda).
typedef PuntoEspectro = ({double lpm, double potencia});

class DetalleMedicion {
  /// Los segundos medidos.
  final double duracion;

  /// De 0 a 1.
  final double calidad;

  /// La señal filtrada de los últimos [segundosOnda], entre −1 y 1.
  final List<double> onda;

  /// Dónde caen en [onda] los latidos detectados (índices).
  final List<int> latidosEnOnda;

  /// Muestras por segundo de [onda].
  final double fs;

  /// Cuántos latidos se detectaron en toda la medición.
  final int latidos;

  /// La FC estimada cada segundo.
  final List<PuntoFc> fcPorSegundo;

  /// Los intervalos entre latidos, ya limpios.
  final List<Intervalo> intervalos;

  /// Sus medidas, o `null` si hay muy pocos.
  final MetricasRr? metricas;

  /// La potencia de 42 a 210 lpm y dónde está el pico de la FC.
  final List<PuntoEspectro> espectro;
  final double? picoLpm;

  /// La onda lenta de la respiración (−1…1), con [fsRespiracion] muestras
  /// por segundo. Vacía si no se pudo calcular.
  final List<double> respiracion;
  final double fsRespiracion;

  static const double segundosOnda = 10;

  /// La variabilidad (pNN50, SD1, SD2, Poincaré) pide buena calidad, 30 s o
  /// más y al menos estos intervalos (como el análisis del servidor).
  static const int intervalosParaVfc = 20;
  static const double segundosParaVfc = 30;

  const DetalleMedicion({
    required this.duracion,
    required this.calidad,
    this.onda = const [],
    this.latidosEnOnda = const [],
    this.fs = frecuenciaAnalisis,
    this.latidos = 0,
    this.fcPorSegundo = const [],
    this.intervalos = const [],
    this.metricas,
    this.espectro = const [],
    this.picoLpm,
    this.respiracion = const [],
    this.fsRespiracion = 5,
  });

  /// Del análisis de la medición entera.
  factory DetalleMedicion.desde(AnalisisPpg a, {required double duracion}) {
    final senal = a.senal;
    final onda = _normalizada(
      senal.length > segundosOnda * a.fs
          ? senal.sublist(senal.length - (segundosOnda * a.fs).round())
          : senal,
    );
    final corte = senal.length - onda.length;
    final intervalos = intervalosLimpios(a.latidos);
    final remuestreada = a.remuestreada;

    return DetalleMedicion(
      duracion: duracion,
      calidad: a.calidad.valor,
      onda: onda,
      latidosEnOnda: [
        for (final t in a.latidos)
          if ((t * a.fs).round() - corte case final i
              when i >= 0 && i < onda.length)
            i,
      ],
      fs: a.fs,
      latidos: a.latidos.length,
      fcPorSegundo: fcPorVentana(senal, fs: a.fs),
      intervalos: intervalos,
      metricas: MetricasRr.de([for (final i in intervalos) i.ms]),
      espectro: _espectroParaDibujar(a.espectro),
      picoLpm: a.fcEspectral,
      respiracion: remuestreada == null || remuestreada.length < 15 * a.fs
          ? const []
          : _diezmada(lineaBaseRespiratoria(remuestreada, fs: a.fs), a.fs, 5),
    );
  }

  /// La calidad alcanza para los datos extra.
  bool get calidadSuficiente => calidad >= umbralCalidadRegular;

  /// La variabilidad es confiable: buena calidad, ≥ 30 s y suficientes
  /// intervalos.
  bool get vfcValida =>
      calidad >= umbralCalidadBuena &&
      duracion >= segundosParaVfc &&
      metricas != null &&
      intervalos.length >= intervalosParaVfc;

  double? get fcMinima => fcPorSegundo.isEmpty
      ? null
      : fcPorSegundo.map((p) => p.fc).reduce(math.min);

  double? get fcMaxima => fcPorSegundo.isEmpty
      ? null
      : fcPorSegundo.map((p) => p.fc).reduce(math.max);

  static List<double> _normalizada(List<double> x) {
    if (x.isEmpty) return const [];
    final maximo = x.map((v) => v.abs()).reduce(math.max);
    return maximo <= 0
        ? List.filled(x.length, 0)
        : [for (final v in x) v / maximo];
  }

  /// La banda del pulso en unos 128 puntos: el máximo de cada tramo, para
  /// no perder el pico.
  static List<PuntoEspectro> _espectroParaDibujar(Espectro? e) {
    if (e == null) return const [];
    final desde = e.indice(fcMinimaHz);
    final hasta = e.indice(fcMaximaHz);
    if (hasta <= desde) return const [];
    final tramo = math.max(1, ((hasta - desde) / 128).ceil());
    final puntos = <PuntoEspectro>[];
    for (var i = desde; i <= hasta; i += tramo) {
      var mejor = i;
      for (var k = i; k < math.min(i + tramo, hasta + 1); k++) {
        if (e.potencia[k] > e.potencia[mejor]) mejor = k;
      }
      puntos.add((lpm: e.frecuencia(mejor) * 60, potencia: e.potencia[mejor]));
    }
    final maximo = puntos.map((p) => p.potencia).reduce(math.max);
    if (maximo <= 0) return const [];
    return [
      for (final p in puntos) (lpm: p.lpm, potencia: p.potencia / maximo),
    ];
  }

  /// Normalizada y con [salida] muestras por segundo (para dibujar).
  static List<double> _diezmada(List<double> x, double fs, double salida) {
    final paso = math.max(1, (fs / salida).round());
    return _normalizada([for (var i = 0; i < x.length; i += paso) x[i]]);
  }
}
