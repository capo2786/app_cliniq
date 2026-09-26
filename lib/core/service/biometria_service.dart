import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Huella o rostro del teléfono.
///
/// Envuelve un complemento que lanza excepciones distintas en cada
/// plataforma: aquí se resuelven una vez, y quien lo llama recibe un sí o un
/// no.
class BiometriaService {
  final LocalAuthentication _auth;

  BiometriaService([LocalAuthentication? auth])
    : _auth = auth ?? LocalAuthentication();

  /// El equipo puede pedir huella, rostro o el PIN de desbloqueo.
  Future<bool> disponible() async {
    if (kIsWeb) return false;

    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('No se pudo consultar la biometría: $e');
      return false;
    }
  }

  /// Pide la verificación. Devuelve `false` si se cancela o falla.
  ///
  /// `biometricOnly: false` acepta también el PIN o el patrón del teléfono:
  /// hay equipos sin lector y personas que no configuran la huella.
  Future<bool> verificar(String motivo) async {
    if (kIsWeb) return false;

    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        biometricOnly: false,
      );
    } catch (e) {
      debugPrint('Falló la verificación biométrica: $e');
      return false;
    }
  }
}
