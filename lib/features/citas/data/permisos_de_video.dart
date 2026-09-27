// lib/features/citas/data/permisos_de_video.dart

import 'package:permission_handler/permission_handler.dart';

/// Cómo quedó un permiso del sistema.
enum EstadoDePermiso {
  concedido,

  /// Dijo que no, pero se puede volver a preguntar.
  denegado,

  /// Ya no se puede preguntar desde la aplicación (lo negó para siempre, o
  /// lo impide el control parental o la empresa): solo desde los ajustes
  /// del teléfono.
  bloqueado,
}

/// Cómo quedaron la cámara y el micrófono, juntos.
enum ResultadoDePermisos {
  /// Los dos: se abre la sala.
  concedidos,

  /// Falta alguno y se puede volver a pedir («Reintentar»).
  denegados,

  /// Falta alguno y solo se arregla en los ajustes del teléfono.
  bloqueados,
}

/// La videoconsulta necesita los dos: sin cámara el médico no ve y sin
/// micrófono no escucha. Si falta uno que ya no se puede pedir, manda ese:
/// «Reintentar» no serviría.
ResultadoDePermisos resumirPermisos(
  EstadoDePermiso camara,
  EstadoDePermiso microfono,
) {
  if (camara == EstadoDePermiso.concedido &&
      microfono == EstadoDePermiso.concedido) {
    return ResultadoDePermisos.concedidos;
  }

  if (camara == EstadoDePermiso.bloqueado ||
      microfono == EstadoDePermiso.bloqueado) {
    return ResultadoDePermisos.bloqueados;
  }

  return ResultadoDePermisos.denegados;
}

/// La cámara y el micrófono del teléfono, tras una interfaz: el de verdad es
/// [PermisosDelSistema]; las pruebas lo cambian por un doble.
abstract class PermisosDeVideo {
  /// Pide los dos (el sistema pregunta solo lo que falte) y dice cómo
  /// quedaron.
  Future<ResultadoDePermisos> pedir();

  /// Abre los ajustes de la aplicación en el teléfono, para conceder lo que
  /// quedó bloqueado. Devuelve si se abrieron.
  Future<bool> abrirAjustes();
}

/// Los permisos del sistema, con `permission_handler`: es el único archivo
/// que lo conoce.
///
/// Se piden antes de abrir la sala. En Android el WebView solo puede usar la
/// cámara y el micrófono si la aplicación ya los tiene; en iOS, la página
/// los usa sin volver a preguntar (`SalaJitsi` se los concede solo al
/// servidor de video).
class PermisosDelSistema implements PermisosDeVideo {
  const PermisosDelSistema();

  @override
  Future<ResultadoDePermisos> pedir() async {
    final estados = await [Permission.camera, Permission.microphone].request();

    return resumirPermisos(
      estadoDePermiso(estados[Permission.camera]),
      estadoDePermiso(estados[Permission.microphone]),
    );
  }

  @override
  Future<bool> abrirAjustes() => openAppSettings();
}

/// Lo que dice el sistema, en las tres respuestas que le importan a la
/// pantalla.
EstadoDePermiso estadoDePermiso(PermissionStatus? estado) => switch (estado) {
  PermissionStatus.granted ||
  PermissionStatus.limited => EstadoDePermiso.concedido,
  PermissionStatus.permanentlyDenied ||
  PermissionStatus.restricted => EstadoDePermiso.bloqueado,
  _ => EstadoDePermiso.denegado,
};
