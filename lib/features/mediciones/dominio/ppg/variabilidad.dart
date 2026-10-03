// lib/features/mediciones/dominio/ppg/variabilidad.dart

/// Lo que se calcula de los intervalos entre latidos (ya corregidos en
/// `correccion_intervalos.dart`): el intervalo medio, SDNN, RMSSD, pNN50 y
/// el diagrama de Poincaré (SD1 y SD2).
///
/// Puro y probado con series de intervalos conocidas. Con 30 s de cámara
/// estos números son **referenciales**: solo se enseñan con buena calidad y
/// pocas correcciones.
library;

import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'correccion_intervalos.dart';
import 'estadistica.dart';

/// Las medidas de una serie de intervalos (en ms).
class MetricasRr extends Equatable {
  final int intervalos;

  /// El intervalo medio, el más corto y el más largo.
  final double medio;
  final double minimo;
  final double maximo;

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

  /// Los intervalos corregidos o descartados antes de medir.
  final int corregidos;

  const MetricasRr({
    required this.intervalos,
    required this.medio,
    required this.minimo,
    required this.maximo,
    required this.sdnn,
    required this.rmssd,
    required this.pnn50,
    required this.sd1,
    required this.sd2,
    this.corregidos = 0,
  });

  /// Las medidas de [rr] (ms), o `null` con menos de tres intervalos. Las
  /// [diferencias] sucesivas, si no vienen, son las de cada par de [rr]
  /// seguidos. Las desviaciones son muestrales (n − 1).
  static MetricasRr? de(
    List<double> rr, {
    List<double>? diferencias,
    int corregidos = 0,
  }) {
    final sucesivas =
        diferencias ?? [for (var i = 1; i < rr.length; i++) rr[i] - rr[i - 1]];
    if (rr.length < 3 || sucesivas.isEmpty) return null;
    final sdnn = _desviacionMuestral(rr);
    final sdDif = _desviacionMuestral(sucesivas);
    final sd1 = math.sqrt(0.5) * sdDif;
    final sd2Cuadrado = 2 * sdnn * sdnn - 0.5 * sdDif * sdDif;
    return MetricasRr(
      intervalos: rr.length,
      medio: mediaDe(rr),
      minimo: rr.reduce(math.min),
      maximo: rr.reduce(math.max),
      sdnn: sdnn,
      rmssd: math.sqrt(mediaDe([for (final d in sucesivas) d * d])),
      pnn50:
          100 * sucesivas.where((d) => d.abs() > 50).length / sucesivas.length,
      sd1: sd1,
      sd2: sd2Cuadrado <= 0 ? 0 : math.sqrt(sd2Cuadrado),
      corregidos: corregidos,
    );
  }

  /// Las medidas de unos intervalos ya corregidos: las diferencias solo
  /// entre dos consecutivos.
  static MetricasRr? deCorregidos(IntervalosCorregidos c) => de(
    [for (final i in c.intervalos) i.ms],
    diferencias: diferenciasSucesivas(c.intervalos),
    corregidos: c.corregidos,
  );

  /// Pocas correcciones: como mucho el 10 % de los intervalos.
  bool get pocasCorrecciones => corregidos <= 0.1 * intervalos;

  @override
  List<Object?> get props => [
    intervalos,
    medio,
    minimo,
    maximo,
    sdnn,
    rmssd,
    pnn50,
    sd1,
    sd2,
    corregidos,
  ];

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
