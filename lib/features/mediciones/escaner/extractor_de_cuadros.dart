// lib/features/mediciones/escaner/extractor_de_cuadros.dart

/// De una imagen de la cámara a un [CuadroPpg]: unos pocos promedios.
///
/// Es puro (no conoce el paquete `camera`) para probarlo con imágenes
/// sintéticas. Lee los tres formatos que entrega la cámara: YUV420 de tres
/// planos y NV21 de un plano (Android) y BGRA8888 (iOS). No copia la
/// imagen: recorre una rejilla de puntos y suma. Al terminar, la imagen no
/// queda referenciada en ninguna parte.
///
/// - **Dedo:** el centro de la imagen. El promedio del rojo (y de la
///   luminancia Y), la **cobertura** (la fracción de puntos rojos y
///   brillantes, como se ve la yema con el flash detrás) y la
///   **saturación** (la fracción de rojos quemados).
/// - **Rostro:** la frente y las dos mejillas dentro del óvalo que la
///   persona ve en pantalla, y de ahí solo los puntos de **piel** (por su
///   color en YCbCr). Qué puntos son piel se decide cada
///   [ExtractorDeRostro.cuadrosPorMascara] cuadros y se mantiene entre medio,
///   para que el conjunto de píxeles no cambie de un cuadro a otro.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'serie_senal.dart';

/// Los formatos de imagen que se saben leer.
enum FormatoImagen { yuv420, nv21, bgra8888 }

/// Un plano de una imagen de la cámara.
class PlanoCrudo {
  final Uint8List bytes;
  final int bytesPorFila;

  /// Distancia entre dos píxeles seguidos (1 o 2 en los planos U y V).
  final int bytesPorPixel;

  const PlanoCrudo(
    this.bytes, {
    required this.bytesPorFila,
    this.bytesPorPixel = 1,
  });
}

/// Una imagen de la cámara, tal como llega (sin girar).
class ImagenCruda {
  final FormatoImagen formato;
  final int ancho;
  final int alto;
  final List<PlanoCrudo> planos;

  const ImagenCruda({
    required this.formato,
    required this.ancho,
    required this.alto,
    required this.planos,
  });
}

/// Un color leído de la imagen.
typedef Rgb = ({double r, double g, double b});

int _limitar255(double v) => v < 0 ? 0 : (v > 255 ? 255 : v.round());

/// Lee el color del píxel (x, y) de la imagen, en RGB 0–255.
Rgb leerPixel(ImagenCruda imagen, int x, int y) {
  switch (imagen.formato) {
    case FormatoImagen.bgra8888:
      final p = imagen.planos.first;
      final i = y * p.bytesPorFila + x * 4;
      return (
        r: p.bytes[i + 2].toDouble(),
        g: p.bytes[i + 1].toDouble(),
        b: p.bytes[i].toDouble(),
      );

    case FormatoImagen.nv21:
      final p = imagen.planos.first;
      final fila = p.bytesPorFila;
      final yy = p.bytes[y * fila + x];
      final iVu = imagen.alto * fila + (y >> 1) * fila + (x >> 1) * 2;
      return yuvARgb(yy, p.bytes[iVu + 1], p.bytes[iVu]);

    case FormatoImagen.yuv420:
      final py = imagen.planos[0];
      final pu = imagen.planos[1];
      final pv = imagen.planos[2];
      final yy = py.bytes[y * py.bytesPorFila + x];
      final u =
          pu.bytes[(y >> 1) * pu.bytesPorFila + (x >> 1) * pu.bytesPorPixel];
      final v =
          pv.bytes[(y >> 1) * pv.bytesPorFila + (x >> 1) * pv.bytesPorPixel];
      return yuvARgb(yy, u, v);
  }
}

/// YUV (BT.601, rango completo, como lo entrega la cámara) a RGB.
Rgb yuvARgb(int y, int u, int v) {
  final du = u - 128;
  final dv = v - 128;
  return (
    r: _limitar255(y + 1.402 * dv).toDouble(),
    g: _limitar255(y - 0.344136 * du - 0.714136 * dv).toDouble(),
    b: _limitar255(y + 1.772 * du).toDouble(),
  );
}

double _luminancia(Rgb c) => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;

/// Un punto de la yema con el flash detrás: rojo, brillante y con poco
/// verde y azul.
bool esYema(Rgb c) => c.r >= 80 && c.r >= 1.8 * c.g && c.r >= 1.8 * c.b;

/// Un punto de piel, por su color en YCbCr (Chai y Ngan, 1999): Cb entre
/// 77 y 127, Cr entre 133 y 173, y con algo de luz.
bool esPiel(Rgb c) {
  final y = _luminancia(c);
  final cb = 128 - 0.168736 * c.r - 0.331264 * c.g + 0.5 * c.b;
  final cr = 128 + 0.5 * c.r - 0.418688 * c.g - 0.081312 * c.b;
  return y >= 40 && cb >= 77 && cb <= 127 && cr >= 133 && cr <= 173;
}

/// El paso de la rejilla para recorrer unos [puntos] de un rectángulo.
int _paso(int ancho, int alto, int puntos) =>
    math.max(1, math.sqrt(ancho * alto / puntos).floor());

/// Reduce una imagen del modo dedo: el centro (la mitad del ancho y del
/// alto), con unos 2500 puntos.
CuadroPpg reducirDedo(ImagenCruda imagen, Duration momento) {
  final x0 = imagen.ancho ~/ 4;
  final y0 = imagen.alto ~/ 4;
  final x1 = imagen.ancho - x0;
  final y1 = imagen.alto - y0;
  final paso = _paso(x1 - x0, y1 - y0, 2500);

  var n = 0, yema = 0, quemados = 0;
  var sr = 0.0, sg = 0.0, sb = 0.0, sy = 0.0;
  for (var y = y0; y < y1; y += paso) {
    for (var x = x0; x < x1; x += paso) {
      final c = leerPixel(imagen, x, y);
      sr += c.r;
      sg += c.g;
      sb += c.b;
      sy += _luminancia(c);
      if (esYema(c)) yema++;
      if (c.r >= 250) quemados++;
      n++;
    }
  }
  if (n == 0) {
    return CuadroPpg(
      momento: momento,
      rojo: 0,
      verde: 0,
      azul: 0,
      luminancia: 0,
      cobertura: 0,
    );
  }

  return CuadroPpg(
    momento: momento,
    rojo: sr / n,
    verde: sg / n,
    azul: sb / n,
    luminancia: sy / n,
    cobertura: yema / n,
    saturacion: quemados / n,
  );
}

/// Un rectángulo en coordenadas normalizadas (0–1) de la imagen derecha,
/// como la ve la persona.
typedef Region = ({double x0, double y0, double x1, double y1});

/// El óvalo de la pantalla del rostro, en coordenadas normalizadas de la
/// imagen derecha: centro y semiejes.
class Ovalo {
  final double cx;
  final double cy;
  final double rx;
  final double ry;

  const Ovalo({this.cx = 0.5, this.cy = 0.44, this.rx = 0.30, this.ry = 0.25});

  /// La frente y las dos mejillas, dentro del óvalo.
  List<Region> get regiones => [
    (
      x0: cx - 0.45 * rx,
      y0: cy - 0.78 * ry,
      x1: cx + 0.45 * rx,
      y1: cy - 0.45 * ry,
    ),
    (
      x0: cx - 0.70 * rx,
      y0: cy + 0.05 * ry,
      x1: cx - 0.25 * rx,
      y1: cy + 0.42 * ry,
    ),
    (
      x0: cx + 0.25 * rx,
      y0: cy + 0.05 * ry,
      x1: cx + 0.70 * rx,
      y1: cy + 0.42 * ry,
    ),
  ];
}

/// Pasa un punto (u, v) normalizado de la imagen derecha a píxeles de la
/// imagen tal como llega del sensor, girada [rotacion] grados en el
/// sentido de las agujas del reloj respecto de la derecha (la orientación
/// del sensor: 90 en la trasera y 270 en la frontal de casi todos los
/// Android).
({int x, int y}) aPixelDelSensor(
  double u,
  double v,
  int rotacion,
  int ancho,
  int alto,
) {
  // Las dimensiones de la imagen derecha.
  final girada = rotacion == 90 || rotacion == 270;
  final anchoDerecha = girada ? alto : ancho;
  final altoDerecha = girada ? ancho : alto;
  final xd = (u * anchoDerecha).clamp(0, anchoDerecha - 1).toInt();
  final yd = (v * altoDerecha).clamp(0, altoDerecha - 1).toInt();

  return switch (rotacion) {
    90 => (x: yd, y: alto - 1 - xd),
    180 => (x: ancho - 1 - xd, y: alto - 1 - yd),
    270 => (x: ancho - 1 - yd, y: xd),
    _ => (x: xd, y: yd),
  };
}

/// Reduce las imágenes del modo rostro. Guarda la máscara de piel (qué
/// puntos de la rejilla son piel) y la renueva cada [cuadrosPorMascara].
class ExtractorDeRostro {
  final Ovalo ovalo;
  final int cuadrosPorMascara;

  /// Puntos por región.
  final int puntosPorRegion;

  List<({int x, int y})> _mascara = const [];
  int _total = 0;
  int _cuadros = 0;

  ExtractorDeRostro({
    this.ovalo = const Ovalo(),
    this.cuadrosPorMascara = 15,
    this.puntosPorRegion = 400,
  });

  /// Los puntos de la rejilla de las tres regiones, en píxeles del sensor.
  List<({int x, int y})> _rejilla(ImagenCruda imagen, int rotacion) {
    final puntos = <({int x, int y})>[];
    final lado = math.sqrt(puntosPorRegion).ceil();
    for (final r in ovalo.regiones) {
      for (var i = 0; i < lado; i++) {
        for (var j = 0; j < lado; j++) {
          final u = r.x0 + (r.x1 - r.x0) * (i + 0.5) / lado;
          final v = r.y0 + (r.y1 - r.y0) * (j + 0.5) / lado;
          puntos.add(
            aPixelDelSensor(u, v, rotacion, imagen.ancho, imagen.alto),
          );
        }
      }
    }
    return puntos;
  }

  CuadroPpg reducir(ImagenCruda imagen, Duration momento, {int rotacion = 0}) {
    if (_cuadros % cuadrosPorMascara == 0 || _mascara.isEmpty) {
      final rejilla = _rejilla(imagen, rotacion);
      _total = rejilla.length;
      _mascara = [
        for (final p in rejilla)
          if (esPiel(leerPixel(imagen, p.x, p.y))) p,
      ];
    }
    _cuadros++;

    var sr = 0.0, sg = 0.0, sb = 0.0, sy = 0.0;
    for (final p in _mascara) {
      final c = leerPixel(imagen, p.x, p.y);
      sr += c.r;
      sg += c.g;
      sb += c.b;
      sy += _luminancia(c);
    }
    final n = _mascara.length;
    final piel = _total == 0 ? 0.0 : n / _total;
    if (n == 0) {
      return CuadroPpg(
        momento: momento,
        rojo: 0,
        verde: 0,
        azul: 0,
        luminancia: 0,
        cobertura: 0,
      );
    }

    return CuadroPpg(
      momento: momento,
      rojo: sr / n,
      verde: sg / n,
      azul: sb / n,
      luminancia: sy / n,
      cobertura: piel,
    );
  }
}
