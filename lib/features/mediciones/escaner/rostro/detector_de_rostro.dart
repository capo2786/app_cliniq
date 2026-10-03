// lib/features/mediciones/escaner/rostro/detector_de_rostro.dart

import 'cuadro_de_camara.dart';
import 'rostro_detectado.dart';

/// Quien busca el rostro en un cuadro de la cámara.
///
/// El de la aplicación es `DetectorMlKit` (ML Kit de Google, en el
/// teléfono); las pruebas usan uno falso. Recibe el cuadro y devuelve el
/// rostro ya en las coordenadas de la imagen como la ve la persona, o
/// `null` si no hay ninguno. Si el detector mismo falla, lanza: quien lo
/// usa decide cuándo dejar de intentarlo.
abstract class DetectorDeRostro {
  Future<RostroDetectado?> detectar(CuadroDeCamara cuadro);

  /// Suelta lo que el detector tenga abierto. Se puede llamar más de una
  /// vez.
  Future<void> cerrar();
}

/// Cómo se crea un detector (puede lanzar si la plataforma no lo tiene).
typedef CrearDetector = DetectorDeRostro Function();
