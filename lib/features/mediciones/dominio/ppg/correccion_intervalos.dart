// lib/features/mediciones/dominio/ppg/correccion_intervalos.dart

/// La corrección de los intervalos entre latidos antes de calcular la
/// variabilidad: la misma en el teléfono y en el servidor (`senales-ms`).
///
/// Un pico mal ubicado parte un latido normal en un intervalo corto y otro
/// largo (620 ms seguidos de 860 ms donde había dos de ~740): no cambia la
/// FC, pero infla SD1, RMSSD y pNN50. Un latido perdido deja un intervalo
/// doble y uno de más, dos cortos. Aquí se arreglan los tres, se cuenta
/// cuántos intervalos se tocaron y se descarta lo que sigue sin cuadrar.
///
/// Sobre los instantes de los picos, ya afinados (`refinarPicos`):
///
/// 1. `rr[i]` son los intervalos y `m` la mediana local de los vecinos
///    (ventana de 7, centrada, recortada en los bordes).
/// 2. **Pico mal ubicado:** si `rr[i] < 0,85·m` y `rr[i+1] > 1,15·m` (o al
///    revés) y `|rr[i] + rr[i+1] − 2m| ≤ 0,15·m`, el latido compartido se
///    mueve al punto medio y los dos valen el promedio. Cuenta 2.
/// 3. **Latido perdido:** si `|rr[i] − 2m| ≤ 0,15·m`, se parte en dos
///    intervalos iguales. Cuenta 1.
/// 4. **Latido de más:** si `rr[i]` y `rr[i+1]` son cortos (< 0,85·m) y
///    `|rr[i] + rr[i+1] − m| ≤ 0,15·m`, se juntan en uno. Cuenta 1.
/// 5. Después, los rangos posibles (42–210 lpm) y la exclusión de lo que
///    se aparta más del 20 % de la mediana de sus 5 vecinos. Lo excluido
///    también cuenta.
///
/// Puro y probado (`test/correccion_intervalos_test.dart`).
library;

import 'dart:math' as math;

import 'constantes.dart';
import 'estadistica.dart';

/// Un intervalo entre dos latidos: en qué segundo cae el segundo latido y
/// cuánto duró, en milisegundos.
typedef Intervalo = ({double segundo, double ms});

/// Los intervalos que quedan y cuántos se corrigieron o descartaron.
class IntervalosCorregidos {
  /// Los válidos, en orden. Donde se descartó alguno queda un hueco: dos
  /// seguidos en la lista no son consecutivos ([sonConsecutivos]).
  final List<Intervalo> intervalos;

  /// Los intervalos corregidos (reglas 2 a 4) más los descartados (5).
  final int corregidos;

  const IntervalosCorregidos(this.intervalos, this.corregidos);

  static const IntervalosCorregidos vacio = IntervalosCorregidos([], 0);
}

/// El margen de las reglas: «corto» es menos de `(1 − margen)·m`, «largo»
/// más de `(1 + margen)·m`, y una suma cuadra si se aparta menos de
/// `margen·m`.
const double _margen = 0.15;

/// La ventana de la mediana local de las reglas 2 a 4.
const int _ventanaReglas = 7;

/// Corrige los intervalos de los [latidos] (instantes en segundos). Con
/// menos de tres intervalos no hay vecinos con qué comparar: solo se
/// aplican los rangos.
IntervalosCorregidos corregirIntervalos(
  List<double> latidos, {
  double tolerancia = 0.2,
  int vecinos = 5,
}) {
  if (latidos.length < 2) return IntervalosCorregidos.vacio;

  final crudos = <Intervalo>[
    for (var i = 1; i < latidos.length; i++)
      (segundo: latidos[i], ms: (latidos[i] - latidos[i - 1]) * 1000),
  ];
  final reglas = crudos.length < 3
      ? (intervalos: crudos, corregidos: 0)
      : _aplicarReglas(latidos.first, crudos);

  final posibles = [
    for (final i in reglas.intervalos)
      if (i.ms >= 1000 / fcMaximaHz && i.ms <= 1000 / fcMinimaHz) i,
  ];
  final validos = posibles.length < 3
      ? posibles
      : [
          for (var i = 0; i < posibles.length; i++)
            if (_cercaDeSusVecinos(posibles, i, vecinos ~/ 2, tolerancia))
              posibles[i],
        ];

  return IntervalosCorregidos(
    validos,
    reglas.corregidos + reglas.intervalos.length - validos.length,
  );
}

/// Las reglas 2 a 4, de izquierda a derecha, sobre los intervalos crudos
/// (el primero empieza en [inicio]).
({List<Intervalo> intervalos, int corregidos}) _aplicarReglas(
  double inicio,
  List<Intervalo> rr,
) {
  final medianas = _medianasLocales([for (final i in rr) i.ms]);
  final salida = <Intervalo>[];
  var corregidos = 0;

  var i = 0;
  while (i < rr.length) {
    final m = medianas[i];
    final a = rr[i];
    final desde = i == 0 ? inicio : rr[i - 1].segundo;

    if (i + 1 < rr.length) {
      final b = rr[i + 1];
      if (esPicoMalUbicado(a.ms, b.ms, m)) {
        final mitad = (a.ms + b.ms) / 2;
        salida
          ..add((segundo: desde + mitad / 1000, ms: mitad))
          ..add((segundo: b.segundo, ms: mitad));
        corregidos += 2;
        i += 2;
        continue;
      }
      if (esLatidoDeMas(a.ms, b.ms, m)) {
        salida.add((segundo: b.segundo, ms: a.ms + b.ms));
        corregidos += 1;
        i += 2;
        continue;
      }
    }

    if (esLatidoPerdido(a.ms, m)) {
      final mitad = a.ms / 2;
      salida
        ..add((segundo: desde + mitad / 1000, ms: mitad))
        ..add((segundo: a.segundo, ms: mitad));
      corregidos += 1;
    } else {
      salida.add(a);
    }
    i += 1;
  }

  return (intervalos: salida, corregidos: corregidos);
}

/// La regla 2: uno corto y otro largo que juntos suman dos normales.
bool esPicoMalUbicado(double a, double b, double m) {
  final cortoYLargo =
      (a < (1 - _margen) * m && b > (1 + _margen) * m) ||
      (b < (1 - _margen) * m && a > (1 + _margen) * m);
  return cortoYLargo && (a + b - 2 * m).abs() <= _margen * m;
}

/// La regla 3: un intervalo que vale dos.
bool esLatidoPerdido(double a, double m) => (a - 2 * m).abs() <= _margen * m;

/// La regla 4: dos cortos que juntos suman uno normal.
bool esLatidoDeMas(double a, double b, double m) =>
    a < (1 - _margen) * m &&
    b < (1 - _margen) * m &&
    (a + b - m).abs() <= _margen * m;

/// La mediana de cada intervalo con sus vecinos (ventana de 7, centrada y
/// recortada en los bordes).
List<double> _medianasLocales(List<double> ms) {
  const mitad = _ventanaReglas ~/ 2;
  return [
    for (var i = 0; i < ms.length; i++)
      medianaDe(
        ms.sublist(math.max(0, i - mitad), math.min(ms.length, i + mitad + 1)),
      ),
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

/// [b] empieza donde termina [a]: no hay un intervalo descartado entre los
/// dos. Se mira con los instantes, así que también vale con los segundos
/// redondeados a una décima del detalle guardado (el hueco más chico, un
/// intervalo posible, pasa de 0,28 s).
bool sonConsecutivos(Intervalo a, Intervalo b, {double tolerancia = 0.12}) =>
    (b.segundo - b.ms / 1000 - a.segundo).abs() <= tolerancia;

/// Las diferencias sucesivas (ms), solo entre dos intervalos válidos y
/// consecutivos.
List<double> diferenciasSucesivas(List<Intervalo> intervalos) => [
  for (var i = 1; i < intervalos.length; i++)
    if (sonConsecutivos(intervalos[i - 1], intervalos[i]))
      intervalos[i].ms - intervalos[i - 1].ms,
];

/// Los pares (RRₙ, RRₙ₊₁) del diagrama de Poincaré, solo de intervalos
/// consecutivos.
List<(double, double)> paresSucesivos(List<Intervalo> intervalos) => [
  for (var i = 1; i < intervalos.length; i++)
    if (sonConsecutivos(intervalos[i - 1], intervalos[i]))
      (intervalos[i - 1].ms, intervalos[i].ms),
];
