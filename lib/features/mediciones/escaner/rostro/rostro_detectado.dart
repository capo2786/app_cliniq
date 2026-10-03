// lib/features/mediciones/escaner/rostro/rostro_detectado.dart

/// Lo que un detector dice del rostro en un cuadro, ya en las coordenadas
/// de la imagen **tal como la ve la persona**: derecha y, con la cámara
/// frontal, espejada (lo que la persona tiene a su izquierda queda a la
/// izquierda de la pantalla).
library;

import 'geometria.dart';

/// Los contornos del rostro, en el mismo orden que los da ML Kit. Juntos
/// son unos 130 puntos.
enum ContornoRostro {
  ovalo,
  cejaIzquierdaArriba,
  cejaIzquierdaAbajo,
  cejaDerechaArriba,
  cejaDerechaAbajo,
  ojoIzquierdo,
  ojoDerecho,
  labioSuperiorArriba,
  labioSuperiorAbajo,
  labioInferiorArriba,
  labioInferiorAbajo,
  puenteNariz,
  baseNariz,
  mejillaIzquierda,
  mejillaDerecha,
}

class RostroDetectado {
  /// La caja del rostro, en píxeles de la imagen como la ve la persona.
  final Caja caja;

  /// Los puntos de cada contorno, en las mismas coordenadas. Puede faltar
  /// alguno (o todos, con un detector que no los da).
  final Map<ContornoRostro, List<Punto>> contornos;

  /// El giro de la cabeza a los lados (Y) y su inclinación (Z), en grados,
  /// si el detector los da.
  final double? anguloY;
  final double? anguloZ;

  /// El tamaño de la imagen derecha (en píxeles).
  final double anchoImagen;
  final double altoImagen;

  /// El momento del cuadro en que se detectó, desde que se abrió la cámara.
  final Duration momento;

  const RostroDetectado({
    required this.caja,
    required this.anchoImagen,
    required this.altoImagen,
    required this.momento,
    this.contornos = const {},
    this.anguloY,
    this.anguloZ,
  });

  /// La caja en fracciones de la imagen (0–1).
  Caja get cajaNormalizada => caja.normalizada(anchoImagen, altoImagen);

  /// Todos los puntos de los contornos, en el orden de [ContornoRostro]:
  /// el orden no cambia entre detecciones con los mismos contornos.
  List<Punto> get puntos => [
    for (final tipo in ContornoRostro.values) ...?contornos[tipo],
  ];

  bool get tieneContornos => contornos.values.any((c) => c.isNotEmpty);

  @override
  String toString() => 'RostroDetectado($caja, ${puntos.length} puntos)';
}
