// lib/features/navegacion/dominio/enlaces_entrantes.dart

/// Los enlaces de los correos de la clínica que abren la aplicación (App
/// Links en Android, Universal Links en iOS).
///
/// El API los arma con la dirección del panel (`general.frontendUrl`, o
/// `FRONTEND_URL`): `https://<panel>/confirmar-correo?token=…` al crear la
/// cuenta y `https://<panel>/restablecer?token=…` al pedir una contraseña
/// nueva (`auth-ms/src/auth/notifications/auth-mailer.service.ts`). Son las
/// mismas rutas del panel (`app.routes.ts`): sin la aplicación instalada, el
/// enlace se abre en el navegador y el panel hace lo mismo.
library;

import '../../../core/config/entorno.dart';

/// La ruta del panel que confirma el correo de una cuenta nueva.
const String rutaConfirmarCorreo = '/confirmar-correo';

/// La ruta del panel donde se crea la contraseña nueva.
const String rutaRestablecer = '/restablecer';

/// A qué pantalla lleva un enlace de un correo.
sealed class EnlaceEntrante {
  /// El `token` del enlace; vacío si llegó incompleto (la pantalla lo dice).
  final String token;

  const EnlaceEntrante(this.token);
}

/// «Confirmar mi correo»: `/confirmar-correo?token=…`.
class EnlaceConfirmarCorreo extends EnlaceEntrante {
  const EnlaceConfirmarCorreo(super.token);

  @override
  bool operator ==(Object other) =>
      other is EnlaceConfirmarCorreo && other.token == token;

  @override
  int get hashCode => Object.hash(EnlaceConfirmarCorreo, token);

  @override
  String toString() => 'EnlaceConfirmarCorreo($token)';
}

/// «Restablecer contraseña»: `/restablecer?token=…`.
class EnlaceRestablecer extends EnlaceEntrante {
  const EnlaceRestablecer(super.token);

  @override
  bool operator ==(Object other) =>
      other is EnlaceRestablecer && other.token == token;

  @override
  int get hashCode => Object.hash(EnlaceRestablecer, token);

  @override
  String toString() => 'EnlaceRestablecer($token)';
}

/// Lee un enlace que abrió la aplicación, o `null` si no es de los suyos.
///
/// Tiene que ser `https`, del servidor del panel ([panel], `WEB_URL`) y de
/// una de las dos rutas (con la ruta base del panel, si tiene una, y sin
/// importar la barra final ni las mayúsculas). El `token` se toma de la
/// consulta; el resto se ignora.
EnlaceEntrante? leerEnlaceEntrante(
  Uri enlace, {
  String panel = Entorno.webUrl,
}) {
  final servidor = Uri.tryParse(panel);
  if (servidor == null || servidor.host.isEmpty) return null;

  // Los enlaces van siempre por https: sin puerto en el panel, el 443.
  final puerto = servidor.hasPort ? servidor.port : 443;

  if (enlace.scheme.toLowerCase() != 'https' ||
      enlace.host.toLowerCase() != servidor.host.toLowerCase() ||
      enlace.port != puerto) {
    return null;
  }

  final base = _sinBarraFinal(servidor.path.toLowerCase());
  var ruta = _sinBarraFinal(enlace.path.toLowerCase());

  if (base.isNotEmpty) {
    if (!ruta.startsWith('$base/')) return null;
    ruta = ruta.substring(base.length);
  }

  final token = _token(enlace);

  return switch (ruta) {
    rutaConfirmarCorreo => EnlaceConfirmarCorreo(token),
    rutaRestablecer => EnlaceRestablecer(token),
    _ => null,
  };
}

String _sinBarraFinal(String ruta) => ruta.replaceAll(RegExp(r'/+$'), '');

String _token(Uri enlace) => enlace.queryParameters['token']?.trim() ?? '';
