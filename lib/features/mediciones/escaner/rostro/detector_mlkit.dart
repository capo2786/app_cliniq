// lib/features/mediciones/escaner/rostro/detector_mlkit.dart

import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../extractor_de_cuadros.dart';
import 'cuadro_de_camara.dart';
import 'detector_de_rostro.dart';
import 'geometria.dart';
import 'rostro_detectado.dart';

/// El rostro con ML Kit (`google_mlkit_face_detection`): gratis, con el
/// modelo empaquetado en la aplicación y **todo en el teléfono**. La imagen
/// pasa al código nativo de ML Kit en el mismo teléfono y se suelta; nunca
/// se guarda ni se envía. ML Kit puede mandar a Google métricas anónimas
/// de uso de la librería, nunca imágenes.
///
/// Pide los contornos (unos 130 puntos), en el modo rápido, sin
/// clasificación (ojos abiertos, sonrisa) ni seguimiento.
class DetectorMlKit implements DetectorDeRostro {
  final FaceDetector _detector;
  bool _cerrado = false;

  DetectorMlKit({FaceDetector? detector})
    : _detector = detector ?? FaceDetector(options: opciones());

  /// Las opciones del detector. El tamaño mínimo (la cara ocupa al menos
  /// el 15 % del ancho) deja ver una cara lejana para decir «Acércate».
  static FaceDetectorOptions opciones() => FaceDetectorOptions(
    enableContours: true,
    enableClassification: false,
    enableLandmarks: false,
    enableTracking: false,
    performanceMode: FaceDetectorMode.fast,
    minFaceSize: 0.15,
  );

  @override
  Future<RostroDetectado?> detectar(CuadroDeCamara cuadro) async {
    if (_cerrado) return null;
    final caras = await _detector.processImage(entradaParaMlKit(cuadro));
    return rostroDesdeMlKit(caras, cuadro);
  }

  @override
  Future<void> cerrar() async {
    if (_cerrado) return;
    _cerrado = true;
    await _detector.close();
  }
}

/// El cuadro como lo pide ML Kit: NV21 (Android) o BGRA8888 (iOS), de un
/// solo plano, con su giro. Otro formato no se puede analizar y lanza
/// [UnsupportedError] (el escáner sigue con el color de piel).
InputImage entradaParaMlKit(CuadroDeCamara cuadro) {
  final imagen = cuadro.imagen;
  final formato = switch (imagen.formato) {
    FormatoImagen.nv21 => InputImageFormat.nv21,
    FormatoImagen.bgra8888 => InputImageFormat.bgra8888,
    FormatoImagen.yuv420 => throw UnsupportedError(
      'ML Kit necesita NV21 o BGRA8888',
    ),
  };
  final plano = imagen.planos.first;
  return InputImage.fromBytes(
    bytes: plano.bytes,
    metadata: InputImageMetadata(
      size: Size(imagen.ancho.toDouble(), imagen.alto.toDouble()),
      rotation:
          InputImageRotationValue.fromRawValue(cuadro.rotacion) ??
          InputImageRotation.rotation0deg,
      format: formato,
      bytesPerRow: plano.bytesPorFila,
    ),
  );
}

/// El rostro más grande de [caras] en las coordenadas de la imagen como la
/// ve la persona: ML Kit las da sobre la imagen derecha; si el cuadro se
/// espeja, se espejan también (y el giro y la inclinación cambian de
/// signo).
RostroDetectado? rostroDesdeMlKit(List<Face> caras, CuadroDeCamara cuadro) {
  if (caras.isEmpty) return null;
  final cara = caras.reduce(
    (a, b) =>
        a.boundingBox.width * a.boundingBox.height >=
            b.boundingBox.width * b.boundingBox.height
        ? a
        : b,
  );

  final ancho = cuadro.anchoDerecho;
  final espejo = cuadro.espejar;
  double x(num valor) => espejo ? ancho - valor : valor.toDouble();
  Punto punto(math.Point<int> p) => Punto(x(p.x), p.y.toDouble());

  final caja = cara.boundingBox;
  final contornos = <ContornoRostro, List<Punto>>{};
  for (final MapEntry(key: tipo, value: contorno) in cara.contours.entries) {
    if (contorno == null || contorno.points.isEmpty) continue;
    contornos[contornoDe(tipo)] = [for (final p in contorno.points) punto(p)];
  }
  double? signo(double? angulo) =>
      angulo == null ? null : (espejo ? -angulo : angulo);

  return RostroDetectado(
    caja: Caja(
      math.min(x(caja.left), x(caja.right)),
      caja.top,
      math.max(x(caja.left), x(caja.right)),
      caja.bottom,
    ),
    contornos: contornos,
    anguloY: signo(cara.headEulerAngleY),
    anguloZ: signo(cara.headEulerAngleZ),
    anchoImagen: ancho,
    altoImagen: cuadro.altoDerecho,
    momento: cuadro.momento,
  );
}

/// El contorno de ML Kit con su nombre en la aplicación.
ContornoRostro contornoDe(FaceContourType tipo) => switch (tipo) {
  FaceContourType.face => ContornoRostro.ovalo,
  FaceContourType.leftEyebrowTop => ContornoRostro.cejaIzquierdaArriba,
  FaceContourType.leftEyebrowBottom => ContornoRostro.cejaIzquierdaAbajo,
  FaceContourType.rightEyebrowTop => ContornoRostro.cejaDerechaArriba,
  FaceContourType.rightEyebrowBottom => ContornoRostro.cejaDerechaAbajo,
  FaceContourType.leftEye => ContornoRostro.ojoIzquierdo,
  FaceContourType.rightEye => ContornoRostro.ojoDerecho,
  FaceContourType.upperLipTop => ContornoRostro.labioSuperiorArriba,
  FaceContourType.upperLipBottom => ContornoRostro.labioSuperiorAbajo,
  FaceContourType.lowerLipTop => ContornoRostro.labioInferiorArriba,
  FaceContourType.lowerLipBottom => ContornoRostro.labioInferiorAbajo,
  FaceContourType.noseBridge => ContornoRostro.puenteNariz,
  FaceContourType.noseBottom => ContornoRostro.baseNariz,
  FaceContourType.leftCheek => ContornoRostro.mejillaIzquierda,
  FaceContourType.rightCheek => ContornoRostro.mejillaDerecha,
};
