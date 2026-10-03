// lib/features/mediciones/escaner/fuente_camara.dart

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'extractor_de_cuadros.dart';
import 'fuente_de_cuadros.dart';
import 'rostro/cuadro_de_camara.dart';
import 'rostro/detector_de_rostro.dart';
import 'rostro/detector_mlkit.dart';
import 'rostro/procesador_de_rostro.dart';
import 'serie_senal.dart';

/// Los cuadros de la cámara del teléfono, con el paquete `camera`.
///
/// - **Dedo:** la cámara trasera, con el flash encendido como linterna
///   (`FlashMode.torch`) y la exposición y el enfoque fijos una vez
///   encendido, para que el automático no persiga el pulso.
/// - **Rostro:** la cámara frontal, con su vista previa a pantalla
///   completa. El rostro lo busca ML Kit ([ProcesadorDeRostro]); si no
///   está, el color de la piel dentro del marco.
///
/// El dedo pide la resolución más baja (la señal es un promedio: más
/// píxeles no ayudan y cuestan batería); el rostro, la media, porque ML Kit
/// necesita caras de unos 200 píxeles para dar los contornos. Siempre a 30
/// cuadros por segundo. Cada imagen se reduce en el momento a un
/// [CuadroPpg] y se suelta: **ningún cuadro se guarda**, ni en memoria ni
/// en disco, y nada sale del teléfono. Si llega una imagen mientras la
/// anterior todavía se procesa, se descarta.
///
/// En Android pide YUV420 (dedo) o NV21 (rostro); en iOS, BGRA8888.
class FuenteCamara implements FuenteDeCuadros {
  /// Cómo se crea el detector del rostro: ML Kit, salvo en las pruebas.
  final CrearDetector crearDetector;

  CameraController? _camara;
  StreamController<CuadroPpg>? _salida;
  ProcesadorDeRostro? _rostro;
  bool _frontal = false;
  int _orientacionSensor = 0;
  final Stopwatch _reloj = Stopwatch();
  bool _ocupada = false;
  ModoEscaner _modo = ModoEscaner.dedo;

  FuenteCamara({CrearDetector? crearDetector})
    : crearDetector = crearDetector ?? DetectorMlKit.new;

  @override
  Stream<CuadroPpg> get cuadros =>
      (_salida ??= StreamController<CuadroPpg>.broadcast()).stream;

  @override
  Future<void> abrir(ModoEscaner modo) async {
    await cerrar();
    _modo = modo;
    _salida ??= StreamController<CuadroPpg>.broadcast();

    final permiso = await Permission.camera.request();
    if (permiso.isPermanentlyDenied || permiso.isRestricted) {
      throw const ErrorDeCamara(MotivoErrorCamara.permisoBloqueado);
    }
    if (!permiso.isGranted) {
      throw const ErrorDeCamara(MotivoErrorCamara.permisoNegado);
    }

    final List<CameraDescription> camaras;
    try {
      camaras = await availableCameras();
    } on CameraException {
      throw const ErrorDeCamara(MotivoErrorCamara.otro);
    }

    final lente = modo == ModoEscaner.dedo
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final descripcion = camaras
        .where((c) => c.lensDirection == lente)
        .firstOrNull;
    if (descripcion == null) {
      throw const ErrorDeCamara(MotivoErrorCamara.sinCamara);
    }

    final android = defaultTargetPlatform == TargetPlatform.android;
    final camara = CameraController(
      descripcion,
      modo == ModoEscaner.dedo ? ResolutionPreset.low : ResolutionPreset.medium,
      enableAudio: false,
      fps: 30,
      imageFormatGroup: !android
          ? ImageFormatGroup.bgra8888
          : modo == ModoEscaner.rostro
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.yuv420,
    );
    _camara = camara;

    try {
      await camara.initialize();
      if (modo == ModoEscaner.dedo) {
        try {
          await camara.setFlashMode(FlashMode.torch);
        } on CameraException {
          throw const ErrorDeCamara(MotivoErrorCamara.sinLinterna);
        }
      }
    } on CameraException catch (error) {
      await cerrar();
      throw ErrorDeCamara(
        error.code == 'CameraAccessDenied'
            ? MotivoErrorCamara.permisoNegado
            : MotivoErrorCamara.otro,
      );
    } on ErrorDeCamara {
      await cerrar();
      rethrow;
    }

    _rostro = modo == ModoEscaner.rostro
        ? ProcesadorDeRostro(crearDetector: crearDetector)
        : null;
    _frontal = lente == CameraLensDirection.front;
    _orientacionSensor = descripcion.sensorOrientation;
    _reloj
      ..reset()
      ..start();

    await camara.startImageStream(_alLlegar);

    // Con la linterna ya encendida, se fijan la exposición y el enfoque:
    // el automático compensaría justo la variación que se quiere medir.
    if (modo == ModoEscaner.dedo) {
      unawaited(_fijarDespues(camara));
    }
  }

  Future<void> _fijarDespues(CameraController camara) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (_camara != camara) return;
    try {
      await camara.setExposureMode(ExposureMode.locked);
      await camara.setFocusMode(FocusMode.locked);
    } on CameraException {
      // No todos los teléfonos lo permiten; se mide igual.
    }
  }

  void _alLlegar(CameraImage imagen) {
    final salida = _salida;
    if (_ocupada || salida == null || salida.isClosed) return;
    _ocupada = true;
    try {
      final cruda = _aCruda(imagen);
      if (cruda == null) return;
      final momento = _reloj.elapsed;
      final rostro = _rostro;
      final cuadro = _modo == ModoEscaner.dedo || rostro == null
          ? reducirDedo(cruda, momento)
          : rostro.procesar(_cuadroDeCamara(cruda, momento));
      salida.add(cuadro);
    } catch (error) {
      debugPrint('Cliniq · escáner: cuadro ilegible: $error');
    } finally {
      _ocupada = false;
    }
  }

  /// La imagen con su giro y su espejo, según la plataforma y cómo se
  /// sostiene el teléfono.
  CuadroDeCamara _cuadroDeCamara(ImagenCruda imagen, Duration momento) {
    final orientacion = orientacionDelCuadro(
      ios: defaultTargetPlatform == TargetPlatform.iOS,
      frontal: _frontal,
      orientacionSensor: _orientacionSensor,
      giroDispositivo: switch (_camara?.value.deviceOrientation) {
        DeviceOrientation.landscapeLeft => 90,
        DeviceOrientation.portraitDown => 180,
        DeviceOrientation.landscapeRight => 270,
        _ => 0,
      },
    );
    return CuadroDeCamara(
      imagen: imagen,
      momento: momento,
      rotacion: orientacion.rotacion,
      espejar: orientacion.espejar,
    );
  }

  /// La imagen del paquete `camera` como la entiende el extractor (sin
  /// copiar los bytes).
  static ImagenCruda? _aCruda(CameraImage imagen) {
    final formato = switch (imagen.format.group) {
      ImageFormatGroup.yuv420 when imagen.planes.length >= 3 =>
        FormatoImagen.yuv420,
      ImageFormatGroup.nv21 => FormatoImagen.nv21,
      ImageFormatGroup.bgra8888 => FormatoImagen.bgra8888,
      _ => null,
    };
    if (formato == null) return null;

    return ImagenCruda(
      formato: formato,
      ancho: imagen.width,
      alto: imagen.height,
      planos: [
        for (final p in imagen.planes)
          PlanoCrudo(
            p.bytes,
            bytesPorFila: p.bytesPerRow,
            bytesPorPixel: p.bytesPerPixel ?? 1,
          ),
      ],
    );
  }

  /// La vista de la cámara frontal **cubriendo** todo el espacio, sin
  /// deformarse (lo que sobra a los lados queda fuera). El paquete la
  /// muestra espejada, como un espejo.
  @override
  Widget vistaPrevia(BuildContext context) {
    final camara = _camara;
    if (camara == null || !camara.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final tamano = camara.value.previewSize;
    if (tamano == null) return CameraPreview(camara);
    // previewSize viene apaisado: en vertical se cambian ancho y alto.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: tamano.shortestSide,
          height: tamano.longestSide,
          child: CameraPreview(camara),
        ),
      ),
    );
  }

  @override
  Future<void> cerrar() async {
    final camara = _camara;
    _camara = null;
    final rostro = _rostro;
    _rostro = null;
    unawaited(rostro?.cerrar());
    _reloj.stop();
    if (camara == null) return;

    try {
      if (camara.value.isStreamingImages) await camara.stopImageStream();
      if (camara.value.flashMode == FlashMode.torch) {
        await camara.setFlashMode(FlashMode.off);
      }
    } on CameraException {
      // Se suelta igual.
    } finally {
      await camara.dispose();
    }
  }

  @override
  Future<bool> abrirAjustes() => openAppSettings();
}
