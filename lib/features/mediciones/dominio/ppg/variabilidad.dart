// lib/features/mediciones/dominio/ppg/variabilidad.dart

/// Los intervalos entre latidos y lo que se calcula de ellos: el intervalo
/// medio, SDNN, RMSSD, pNN50 y el diagrama de Poincaré (SD1 y SD2).
///
/// Puro y probado con series de intervalos conocidas. Con 30 s de cámara
/// estos números son **referenciales**: solo se enseñan con buena calidad.
library;

import 'dart:math' as math;

import 'constantes.dart';
import 'estadistica.dart';

/// Un intervalo entre dos latidos: en qué segundo cae el segundo latido y
/// cuánto duró, en milisegundos.
typedef Intervalo = ({double segundo, double ms});

/// Los intervalos entre los [latidos] (instantes en segundos), sin los que
/// no pueden ser un latido (fuera de 42–210 lpm) ni los que se apartan más
/// de [tolerancia] de la mediana de sus [vecinos] (un latido perdido o uno
/// de más, que partirían o juntarían intervalos).
List<Intervalo> intervalosLimpios(
  List<double> latidos, {
  double tolerancia = 0.2,
  int vecinos = 5,
}) {
  final crudos = <Intervalo>[
    for (var i = 1; i < latidos.length; i++)
      if (latidos[i] - latidos[i - 1] case final d
          when d >= 1 / fcMaximaHz && d <= 1 / fcMinimaHz)
        (segundo: latidos[i], ms: d * 1000),
  ];
  if (crudos.length < 3) return crudos;

  final mitad = vecinos ~/ 2;
  return [
    for (var i = 0; i < crudos.length; i++)
      if (_cercaDeSusVecinos(crudos, i, mitad, tolerancia)) crudos[i],
  ];
}

bool _cercaDeSusVecinos(
  List<Intervalo> intervalos,
  int i,
  int mitad,
  double tolerancia,
) {
  final desde = math.max(0, i - mitad);
  final hasta = math.min(intervalos.length, i + mitad + 1);
  final mediana = medianaDe([
    for (var k = desde; k < hasta; k++) intervalos[k].ms,
  ]);
  return (intervalos[i].ms - mediana).abs() <= tolerancia * mediana;
}

/// Las medidas de una serie de intervalos (en ms).
class MetricasRr {
  final int intervalos;

  /// El intervalo medio.
  final double medio;

  /// La desviación típica de los intervalos.
  final double sdnn;

  /// La raíz del promedio de las diferencias sucesivas al cuadrado.
  final double rmssd;

  /// El porcentaje de diferencias sucesivas mayores de 50 ms.
  final double pnn50;

  /// Poincaré: la dispersión a lo ancho de la diagonal (variación de
  /// latido a latido) y a lo largo (variación lenta).
  final double sd1;
  final double sd2;

  const MetricasRr({
    required this.intervalos,
    required this.medio,
    required this.sdnn,
    required this.rmssd,
    required this.pnn50,
    required this.sd1,
    required this.sd2,
  });

  /// Las medidas de [rr] (ms), o `null` con menos de tres intervalos.
  /// Las desviaciones son muestrales (n − 1).
  static MetricasRr? de(List<double> rr) {
    if (rr.length < 3) return null;
    final diferencias = [for (var i = 1; i < rr.length; i++) rr[i] - rr[i - 1]];
    final sdnn = _desviacionMuestral(rr);
    final sdDif = _desviacionMuestral(diferencias);
    final sd1 = math.sqrt(0.5) * sdDif;
    final sd2Cuadrado = 2 * sdnn * sdnn - 0.5 * sdDif * sdDif;
    return MetricasRr(
      intervalos: rr.length,
      medio: mediaDe(rr),
      sdnn: sdnn,
      rmssd: math.sqrt(mediaDe([for (final d in diferencias) d * d])),
      pnn50:
          100 *
          diferencias.where((d) => d.abs() > 50).length /
          diferencias.length,
      sd1: sd1,
      sd2: sd2Cuadrado <= 0 ? 0 : math.sqrt(sd2Cuadrado),
    );
  }

  static double _desviacionMuestral(List<double> x) {
    if (x.length < 2) return 0;
    final m = mediaDe(x);
    var suma = 0.0;
    for (final v in x) {
      suma += (v - m) * (v - m);
    }
    return math.sqrt(suma / (x.length - 1));
  }
}
