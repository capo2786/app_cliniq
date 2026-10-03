// lib/features/mediciones/escaner/rostro/cuadro_de_camara.dart

/// Un cuadro de la cámara con lo necesario para entenderlo: la imagen tal
/// como llega, cuánto hay que girarla para que quede derecha y si hay que
/// espejarla para verla como la persona se ve en pantalla.
///
/// Es la entrada del [DetectorDeRostro] y del procesador del rostro. Vive
/// solo mientras se procesa: nadie lo guarda.
library;

import '../extractor_de_cuadros.dart';
import 'geometria.dart';

/// Cómo se pone derecha la imagen de la cámara.
typedef OrientacionCuadro = ({int rotacion, bool espejar});

/// Cuánto girar y si espejar los cuadros, según la plataforma.
///
/// - **iOS:** el paquete `camera` ya entrega los cuadros derechos (gira la
///   conexión de video con el teléfono) y, en la frontal, espejados. No hay
///   que hacer nada.
/// - **Android:** llegan como los da el sensor: se giran
///   `sensor ± giro del teléfono` grados en el sentido de las agujas del
///   reloj (sumando en la frontal, restando en la trasera, como indica ML
///   Kit) y la frontal se espeja.
///
/// [giroDispositivo] en grados: 0 vertical, 90 apaisado a la izquierda, 180
/// cabeza abajo y 270 apaisado a la derecha.
OrientacionCuadro orientacionDelCuadro({
  required bool ios,
  required bool frontal,
  required int orientacionSensor,
  int giroDispositivo = 0,
}) {
  if (ios) return (rotacion: 0, espejar: false);
  final rotacion = frontal
      ? (orientacionSensor + giroDispositivo) % 360
      : (orientacionSensor - giroDispositivo + 360) % 360;
  return (rotacion: rotacion, espejar: frontal);
}

class CuadroDeCamara {
  final ImagenCruda imagen;

  /// Grados (0, 90, 180 o 270) que hay que girar la imagen, en el sentido
  /// de las agujas del reloj, para que quede derecha.
  final int rotacion;

  /// Si, ya derecha, hay que espejarla para verla como la persona.
  final bool espejar;

  /// Desde que se abrió la cámara.
  final Duration momento;

  const CuadroDeCamara({
    required this.imagen,
    required this.momento,
    this.rotacion = 0,
    this.espejar = false,
  });

  bool get _girada => rotacion == 90 || rotacion == 270;

  /// El tamaño de la imagen derecha.
  double get anchoDerecho => (_girada ? imagen.alto : imagen.ancho).toDouble();
  double get altoDerecho => (_girada ? imagen.ancho : imagen.alto).toDouble();

  /// El píxel de la imagen cruda que corresponde a [p], un punto de la
  /// imagen como la ve la persona (en píxeles).
  ({int x, int y}) pixelDe(Punto p) {
    var u = p.x / anchoDerecho;
    if (espejar) u = 1 - u;
    return aPixelDelSensor(
      u,
      p.y / altoDerecho,
      rotacion,
      imagen.ancho,
      imagen.alto,
    );
  }
}
