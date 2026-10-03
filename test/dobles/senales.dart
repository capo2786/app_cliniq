// test/dobles/senales.dart

/// Señales sintéticas para probar el procesamiento de la PPG sin cámara.
///
/// Una onda de pulso realista no es una sinusoide: sube rápido, baja más
/// despacio y tiene la muesca dícrota. Aquí es la fundamental con dos
/// armónicos, con una pequeña variabilidad latido a latido, sobre el nivel
/// del rojo de un dedo con el flash encendido (~180 de 255, con un pulso
/// del orden del 1 %). Los tiempos llegan como los da la cámara: unos 30
/// cuadros por segundo, con temblor y algún cuadro perdido.
library;

import 'dart:math' as math;

/// Una serie con sus tiempos (segundos) y valores.
class Serie {
  final List<double> tiempos;
  final List<double> valores;

  const Serie(this.tiempos, this.valores);
}

/// Los tres canales de un rostro, con sus tiempos.
class SerieRgb {
  final List<double> tiempos;
  final List<double> rojo;
  final List<double> verde;
  final List<double> azul;

  const SerieRgb(this.tiempos, this.rojo, this.verde, this.azul);
}

/// Un generador con semilla: la misma prueba da siempre lo mismo.
class Sintetizador {
  final math.Random _azar;

  Sintetizador(int semilla) : _azar = math.Random(semilla);

  /// Ruido normal (Box–Muller).
  double gauss() {
    final u1 = math.max(_azar.nextDouble(), 1e-12);
    final u2 = _azar.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  /// Los tiempos de los cuadros: [fps] por segundo durante [segundos], con
  /// temblor de ±[temblorMs] y un [perdidos] por uno de cuadros perdidos.
  List<double> tiempos({
    double segundos = 30,
    double fps = 30,
    double temblorMs = 4,
    double perdidos = 0.02,
  }) {
    final t = <double>[];
    for (var i = 0; i < segundos * fps; i++) {
      if (_azar.nextDouble() < perdidos) continue;
      final temblor = (_azar.nextDouble() * 2 - 1) * temblorMs / 1000;
      t.add(math.max(0, i / fps + temblor));
    }
    t.sort();
    return t;
  }

  /// La fase del pulso en cada instante, con variabilidad: la frecuencia
  /// instantánea se mueve un ±[variabilidad] alrededor de [lpm] con dos
  /// oscilaciones lentas (por debajo de la banda respiratoria) y, si hay
  /// [respiracionRpm], con la arritmia sinusal respiratoria.
  List<double> fases(
    List<double> tiempos,
    double lpm, {
    double variabilidad = 0.02,
    double? respiracionRpm,
  }) {
    final f0 = lpm / 60;
    final fase = <double>[];
    var acumulada = _azar.nextDouble() * 2 * math.pi;
    var anterior = tiempos.first;
    final fase1 = _azar.nextDouble() * 2 * math.pi;
    final fase2 = _azar.nextDouble() * 2 * math.pi;
    for (final t in tiempos) {
      var cambio =
          variabilidad *
          (0.6 * math.sin(2 * math.pi * 0.031 * t + fase1) +
              0.4 * math.sin(2 * math.pi * 0.067 * t + fase2));
      if (respiracionRpm != null) {
        cambio += 0.03 * math.sin(2 * math.pi * respiracionRpm / 60 * t);
      }
      acumulada += 2 * math.pi * f0 * (1 + cambio) * (t - anterior);
      anterior = t;
      fase.add(acumulada);
    }
    return fase;
  }

  /// La forma de un latido (media cero, amplitud ~1): fundamental, segundo
  /// armónico (la muesca dícrota) y tercero.
  static double onda(double fase) =>
      math.sin(fase) +
      0.45 * math.sin(2 * fase + 0.9) +
      0.15 * math.sin(3 * fase + 1.7);

  /// El modo dedo: el rojo medio de cada cuadro.
  ///
  /// - [ruido]: desviación del ruido blanco, en veces la amplitud del pulso.
  /// - [deriva]: amplitud de una deriva lenta (recta más una onda de 0,04
  ///   Hz), en veces la amplitud del pulso.
  /// - [artefactos]: cuántos movimientos bruscos (medio segundo con saltos
  ///   de hasta ±[fuerzaArtefactos] veces el pulso).
  /// - [respiracionRpm]: si viene, la respiración modula la línea base y la
  ///   amplitud.
  Serie dedo({
    required double lpm,
    double segundos = 30,
    double fps = 30,
    double ruido = 0,
    double deriva = 0,
    int artefactos = 0,
    double fuerzaArtefactos = 8,
    double? respiracionRpm,
    double nivel = 180,
    double pulso = 1.5,
  }) {
    final t = tiempos(segundos: segundos, fps: fps);
    final fase = fases(t, lpm, respiracionRpm: respiracionRpm);
    final inicios = [
      for (var k = 0; k < artefactos; k++)
        2 + _azar.nextDouble() * (segundos - 4),
    ];

    final valores = <double>[];
    for (var i = 0; i < t.length; i++) {
      var amplitud = pulso;
      var base = nivel;
      if (respiracionRpm != null) {
        final fr = 2 * math.pi * respiracionRpm / 60 * t[i];
        amplitud *= 1 + 0.25 * math.sin(fr);
        base += 0.6 * pulso * math.sin(fr + 0.5);
      }
      // El pulso resta luz: con más sangre llega menos rojo a la cámara.
      var v = base - amplitud * onda(fase[i]);
      v += deriva * pulso * (t[i] / segundos * 2 - 1);
      v += deriva * pulso * math.sin(2 * math.pi * 0.04 * t[i]);
      v += ruido * pulso * gauss();
      for (final inicio in inicios) {
        if (t[i] >= inicio && t[i] < inicio + 0.5) {
          v += fuerzaArtefactos * pulso * (_azar.nextDouble() * 2 - 1);
        }
      }
      valores.add(v);
    }
    return Serie(t, valores);
  }

  /// Una señal plana: el nivel con un ruido de cuantización mínimo.
  Serie plana({double segundos = 30, double nivel = 180}) {
    final t = tiempos(segundos: segundos);
    return Serie(t, [for (final _ in t) nivel + 0.002 * gauss()]);
  }

  /// Solo ruido, sin pulso: la cámara mirando a otra parte.
  Serie soloRuido({double segundos = 30, double nivel = 120}) {
    final t = tiempos(segundos: segundos);
    return Serie(t, [for (final _ in t) nivel + 1.5 * gauss()]);
  }

  /// El modo rostro: el pulso en la dirección del tono de la piel
  /// ([0,33; 0,77; 0,53], Wang et al.) y, encima, un cambio de brillo
  /// común a los tres canales de frecuencia [brilloHz] y amplitud [brillo]
  /// (en veces el pulso), como una luz que parpadea o una cabeza que se
  /// mueve.
  SerieRgb rostro({
    required double lpm,
    double segundos = 30,
    double ruido = 0.3,
    double brillo = 0,
    double brilloHz = 1.6,
  }) {
    final t = tiempos(segundos: segundos);
    final fase = fases(t, lpm);
    const nivel = [150.0, 110.0, 90.0];
    const piel = [0.33, 0.77, 0.53];
    const pulso = 0.004; // 0,4 % del nivel: el rPPG es débil

    final canales = [<double>[], <double>[], <double>[]];
    for (var i = 0; i < t.length; i++) {
      final luz = 1 + brillo * pulso * math.sin(2 * math.pi * brilloHz * t[i]);
      for (var c = 0; c < 3; c++) {
        final v =
            nivel[c] *
            luz *
            (1 + pulso * piel[c] * onda(fase[i]) + ruido * pulso * gauss());
        canales[c].add(v);
      }
    }
    return SerieRgb(t, canales[0], canales[1], canales[2]);
  }
}
