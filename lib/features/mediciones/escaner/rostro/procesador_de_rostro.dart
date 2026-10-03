// lib/features/mediciones/escaner/rostro/procesador_de_rostro.dart

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../extractor_de_cuadros.dart';
import '../serie_senal.dart';
import 'cuadro_de_camara.dart';
import 'detector_de_rostro.dart';
import 'region_de_interes.dart';
import 'rostro_detectado.dart';

/// Cada cuadro del modo rostro, de la imagen a un [CuadroPpg].
///
/// - **Detección:** el [DetectorDeRostro] corre como máximo una vez cada
///   [intervalo]: con la cámara a 30 cuadros por segundo, uno de cada tres
///   (10 por segundo; 8 si la cámara va a 24). Nunca bloquea: si hay una en
///   curso, el cuadro sigue sin esperar.
/// - **Promedio:** en **cada** cuadro, con la última región conocida: la
///   frente y las mejillas de la última detección, y de ahí solo la piel.
///   Qué píxeles se miran (la máscara) se rehace cuando el rostro se mueve
///   o cada [cuadrosPorMascara], para que el conjunto no cambie de un
///   cuadro a otro.
/// - **Respaldo:** si el detector no se puede crear, o falla
///   [fallosParaRespaldo] veces seguidas, se sigue con el [ExtractorDeRostro]
///   (color de piel dentro del marco) el resto de la medición, sin cortarla.
///
/// Nada de la imagen queda guardado: solo la lista de píxeles que se miran.
class ProcesadorDeRostro {
  final Duration intervalo;
  final int cuadrosPorMascara;
  final int fallosParaRespaldo;

  /// Cuántos puntos de la rejilla, como mucho, por zona (tres zonas): el
  /// costo por cuadro está acotado.
  final int puntosPorZona;

  /// Una detección más vieja que esto ya no dice dónde está el rostro.
  final Duration vigencia;

  final ExtractorDeRostro _respaldo;
  DetectorDeRostro? _detector;
  bool _porColor = false;
  bool _ocupado = false;
  int _fallos = 0;
  Duration? _ultimoIntento;

  RostroDetectado? _rostro;
  RostroDetectado? _rostroDeLaMascara;
  List<({int x, int y})> _mascara = const [];
  int _muestras = 0;
  int _cuadrosConMascara = 0;

  ProcesadorDeRostro({
    CrearDetector? crearDetector,
    ExtractorDeRostro? respaldo,
    this.intervalo = const Duration(milliseconds: 95),
    this.cuadrosPorMascara = 15,
    this.fallosParaRespaldo = 2,
    this.puntosPorZona = 300,
    this.vigencia = const Duration(milliseconds: 1200),
  }) : _respaldo = respaldo ?? ExtractorDeRostro() {
    if (crearDetector == null) {
      _porColor = true;
      return;
    }
    try {
      _detector = crearDetector();
    } catch (error) {
      debugPrint('Cliniq · escáner: sin detector de rostro: $error');
      _porColor = true;
    }
  }

  /// ML Kit no está: el rostro se busca por el color de la piel.
  bool get porColorDePiel => _porColor;

  /// Cuántos píxeles se leen por cuadro ahora mismo.
  int get pixelesPorCuadro => _mascara.length;

  CuadroPpg procesar(CuadroDeCamara cuadro) {
    if (_porColor) {
      return _respaldo
          .reducir(cuadro.imagen, cuadro.momento, rotacion: cuadro.rotacion)
          .conRostro(null, porColorDePiel: true);
    }

    _quizaDetectar(cuadro);
    final rostro = _vigente(cuadro.momento);
    if (rostro != null && _hayQueRehacer(rostro)) _rehacer(cuadro, rostro);
    _cuadrosConMascara++;

    // Sin rostro ahora, se sigue con la última región conocida: quien mide
    // decide si esos cuadros cuentan.
    return promediarPixeles(
      cuadro.imagen,
      _mascara,
      cuadro.momento,
      cobertura: _muestras == 0 ? 0.0 : _mascara.length / _muestras,
    ).conRostro(rostro);
  }

  void _quizaDetectar(CuadroDeCamara cuadro) {
    final detector = _detector;
    if (detector == null || _ocupado) return;
    final ultimo = _ultimoIntento;
    if (ultimo != null && cuadro.momento - ultimo < intervalo) return;

    _ocupado = true;
    _ultimoIntento = cuadro.momento;
    try {
      detector.detectar(cuadro).then(_alDetectar, onError: _alFallar);
    } catch (error) {
      _alFallar(error);
    }
  }

  void _alDetectar(RostroDetectado? rostro) {
    _ocupado = false;
    _fallos = 0;
    _rostro = rostro;
  }

  void _alFallar(Object error) {
    _ocupado = false;
    _fallos++;
    debugPrint('Cliniq · escáner: el detector de rostro falló: $error');
    if (_fallos >= fallosParaRespaldo) unawaited(_pasarAlColorDePiel());
  }

  Future<void> _pasarAlColorDePiel() async {
    _porColor = true;
    _rostro = null;
    _mascara = const [];
    final detector = _detector;
    _detector = null;
    try {
      await detector?.cerrar();
    } catch (_) {
      // Ya falló: no hay nada más que soltar.
    }
  }

  RostroDetectado? _vigente(Duration momento) {
    final rostro = _rostro;
    if (rostro == null) return null;
    return momento - rostro.momento > vigencia ? null : rostro;
  }

  /// La máscara se rehace con una detección nueva si el rostro se movió o
  /// cambió de tamaño, o si ya pasaron [cuadrosPorMascara].
  bool _hayQueRehacer(RostroDetectado rostro) {
    final anterior = _rostroDeLaMascara;
    if (anterior == null || _mascara.isEmpty) return true;
    if (identical(anterior, rostro)) return false;
    if (_cuadrosConMascara >= cuadrosPorMascara) return true;
    final ancho = anterior.caja.ancho;
    if (ancho <= 0) return true;
    final movido = anterior.caja.centro.distanciaA(rostro.caja.centro) / ancho;
    final escala = (rostro.caja.ancho - ancho).abs() / ancho;
    return movido > 0.04 || escala > 0.06;
  }

  void _rehacer(CuadroDeCamara cuadro, RostroDetectado rostro) {
    final region = regionDesdeRostro(rostro);
    final candidatos = [
      for (final p in region.muestras(porZona: puntosPorZona))
        cuadro.pixelDe(p),
    ];
    _muestras = candidatos.length;
    _mascara = soloPiel(cuadro.imagen, candidatos);
    _rostroDeLaMascara = rostro;
    _cuadrosConMascara = 0;
  }

  Future<void> cerrar() async {
    final detector = _detector;
    _detector = null;
    _rostro = null;
    _mascara = const [];
    await detector?.cerrar();
  }
}
