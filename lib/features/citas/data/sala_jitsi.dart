// lib/features/citas/data/sala_jitsi.dart

import 'package:flutter/foundation.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

import 'videollamada_service.dart';

/// La sala de video con el SDK oficial de Jitsi para Flutter
/// (`jitsi_meet_flutter_sdk`): la misma experiencia de la aplicación de
/// Jitsi, dentro de Cliniq. Es el único archivo que conoce el SDK.
///
/// Funciona en Android (API 24+) e iOS (15.1+); en la web no hay SDK y la
/// videoconsulta usa el navegador (ver `VideollamadaEnLaApp`).
class SalaJitsi implements SalaDeVideo {
  final JitsiMeet _jitsi;

  SalaJitsi([JitsiMeet? jitsi]) : _jitsi = jitsi ?? JitsiMeet();

  @override
  bool get disponible =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> entrar(DatosDeSala datos) async {
    final respuesta = await _jitsi.join(
      JitsiMeetConferenceOptions(
        serverURL: datos.servidor,
        room: datos.sala,
        token: datos.token,
        configOverrides: {
          'subject': ?(datos.asunto.isEmpty ? null : datos.asunto),
          'defaultLanguage': 'es',
          'startWithAudioMuted': false,
          'startWithVideoMuted': false,
        },
        featureFlags: {
          // La sala va con token: el aviso de «sala sin contraseña» confunde.
          'unsaferoomwarning.enabled': false,
          // Es una consulta médica: no se invita a nadie más desde la sala.
          'invite.enabled': false,
          'add-people.enabled': false,
        },
        userInfo: JitsiMeetUserInfo(displayName: datos.nombreVisible),
      ),
    );

    return respuesta.isSuccess;
  }
}
