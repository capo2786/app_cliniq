// test/dobles/rostro.dart

/// Dobles del rostro del escáner: un rostro sintético con los ~130 puntos
/// de los contornos de ML Kit, imágenes sintéticas (BGRA, como en iOS) con
/// una cara de piel, cejas y pelo negros y fondo azul, y un detector falso
/// que responde lo que la prueba decide.
library;

import 'dart:math' as math;

import 'package:app_cliniq/features/mediciones/escaner/extractor_de_cuadros.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/cuadro_de_camara.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/detector_de_rostro.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/geometria.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/rostro_detectado.dart';
import 'package:flutter/foundation.dart';

/// Un rostro de frente, con la caja de [ancho] píxeles centrada en
/// ([cx], [cy]) y alta 1,25 veces el ancho. Los puntos van redondeados a
/// píxeles enteros, como los da ML Kit.
RostroDetectado rostroSintetico({
  double cx = 240,
  double cy = 280,
  double ancho = 260,
  double anguloY = 0,
  double anguloZ = 0,
  Duration momento = Duration.zero,
  double anchoImagen = 480,
  double altoImagen = 640,
}) {
  final w = ancho;
  final h = 1.25 * ancho;
  Punto p(double dx, double dy) =>
      Punto((cx + dx * w).roundToDouble(), (cy + dy * h).roundToDouble());

  List<Punto> elipse(double dx, double dy, double rx, double ry, int n) => [
    for (var i = 0; i < n; i++)
      p(
        dx + rx * math.sin(2 * math.pi * i / n),
        dy - ry * math.cos(2 * math.pi * i / n),
      ),
  ];

  List<Punto> arco(double x0, double x1, double y, double curva, int n) => [
    for (var i = 0; i < n; i++)
      p(
        x0 + (x1 - x0) * i / (n - 1),
        y - curva * math.sin(math.pi * i / (n - 1)),
      ),
  ];

  return RostroDetectado(
    caja: Caja(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2),
    anchoImagen: anchoImagen,
    altoImagen: altoImagen,
    momento: momento,
    anguloY: anguloY,
    anguloZ: anguloZ,
    contornos: {
      ContornoRostro.ovalo: elipse(0, 0, 0.48, 0.52, 36),
      ContornoRostro.cejaIzquierdaArriba: arco(-0.38, -0.08, -0.22, 0.03, 5),
      ContornoRostro.cejaIzquierdaAbajo: arco(-0.36, -0.08, -0.19, 0.02, 5),
      ContornoRostro.cejaDerechaArriba: arco(0.08, 0.38, -0.22, 0.03, 5),
      ContornoRostro.cejaDerechaAbajo: arco(0.08, 0.36, -0.19, 0.02, 5),
      ContornoRostro.ojoIzquierdo: elipse(-0.2, -0.1, 0.1, 0.035, 16),
      ContornoRostro.ojoDerecho: elipse(0.2, -0.1, 0.1, 0.035, 16),
      ContornoRostro.labioSuperiorArriba: arco(-0.18, 0.18, 0.25, 0.02, 11),
      ContornoRostro.labioSuperiorAbajo: arco(-0.16, 0.16, 0.27, 0, 9),
      ContornoRostro.labioInferiorArriba: arco(-0.16, 0.16, 0.28, 0, 9),
      ContornoRostro.labioInferiorAbajo: arco(-0.16, 0.16, 0.33, -0.02, 9),
      ContornoRostro.puenteNariz: [p(0, -0.1), p(0, 0.05)],
      ContornoRostro.baseNariz: [p(-0.08, 0.1), p(0, 0.12), p(0.08, 0.1)],
      ContornoRostro.mejillaIzquierda: [p(-0.28, 0.08)],
      ContornoRostro.mejillaDerecha: [p(0.28, 0.08)],
    },
  );
}

/// Los colores de las imágenes sintéticas.
const Rgb pielSintetica = (r: 150, g: 110, b: 90);
const Rgb pelo = (r: 20, g: 20, b: 20);
const Rgb fondoAzul = (r: 30, g: 60, b: 200);

/// Una imagen BGRA de [ancho] × [alto] pintada por [color] en cada píxel.
ImagenCruda imagenBgra(int ancho, int alto, Rgb Function(int x, int y) color) {
  final bytes = Uint8List(ancho * alto * 4);
  for (var y = 0; y < alto; y++) {
    for (var x = 0; x < ancho; x++) {
      final c = color(x, y);
      final i = (y * ancho + x) * 4;
      bytes[i] = c.b.round().clamp(0, 255);
      bytes[i + 1] = c.g.round().clamp(0, 255);
      bytes[i + 2] = c.r.round().clamp(0, 255);
      bytes[i + 3] = 255;
    }
  }
  return ImagenCruda(
    formato: FormatoImagen.bgra8888,
    ancho: ancho,
    alto: alto,
    planos: [PlanoCrudo(bytes, bytesPorFila: ancho * 4, bytesPorPixel: 4)],
  );
}

/// La cara de [rostro] pintada: piel dentro del óvalo, cejas y pelo
/// negros (encima de la frente) y fondo azul. [piel] da el color de la
/// piel (para modular el pulso).
ImagenCruda imagenDeRostro(
  RostroDetectado rostro, {
  Rgb piel = pielSintetica,
  Float64List? temblor,
}) {
  final ancho = rostro.anchoImagen.round();
  final alto = rostro.altoImagen.round();
  final ovalo = rostro.contornos[ContornoRostro.ovalo]!;
  final cejas = [
    ContornoRostro.cejaIzquierdaArriba,
    ContornoRostro.cejaDerechaArriba,
  ].map((c) => Caja.de(rostro.contornos[c]!)!).toList();
  final techoCejas = cejas.map((c) => c.arriba).reduce(math.min);
  final limitePelo = techoCejas - 0.12 * rostro.caja.alto;

  return imagenBgra(ancho, alto, (x, y) {
    final punto = Punto(x.toDouble(), y.toDouble());
    if (!puntoEnPoligono(punto, ovalo)) return fondoAzul;
    if (y < limitePelo) return pelo;
    for (final c in cejas) {
      final enX = x >= c.izquierda && x <= c.derecha;
      if (enX && y >= c.arriba - 2 && y <= c.abajo + 6) return pelo;
    }
    final d = temblor == null ? 0.0 : temblor[(y * ancho + x) % temblor.length];
    return (r: piel.r + d, g: piel.g + d, b: piel.b + d);
  });
}

/// Un detector falso: responde [respuesta] (de cada cuadro) al instante
/// (con un `SynchronousFuture`) o lanza si [fallar] lo dice.
class DetectorFalso implements DetectorDeRostro {
  RostroDetectado? Function(CuadroDeCamara cuadro) respuesta;
  bool Function(CuadroDeCamara cuadro) fallar;
  final List<Duration> llamadas = [];
  int cierres = 0;

  DetectorFalso({
    RostroDetectado? Function(CuadroDeCamara cuadro)? respuesta,
    bool Function(CuadroDeCamara cuadro)? fallar,
  }) : respuesta = respuesta ?? ((_) => null),
       fallar = fallar ?? ((_) => false);

  @override
  Future<RostroDetectado?> detectar(CuadroDeCamara cuadro) {
    llamadas.add(cuadro.momento);
    if (fallar(cuadro)) return Future.error(StateError('ML Kit falló'));
    return SynchronousFuture(respuesta(cuadro));
  }

  @override
  Future<void> cerrar() async => cierres++;
}
