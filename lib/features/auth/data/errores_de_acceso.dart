import 'package:dio/dio.dart';

import '../../../core/network/errores.dart';

/// Por qué no se pudo entrar, en palabras de la persona.
class ErrorDeAcceso {
  final String mensaje;

  /// La cuenta quedó bloqueada por varios intentos fallidos (los minutos
  /// los dice la configuración, `seguridad.bloqueoMinutos`).
  final bool bloqueada;

  /// La cuenta se creó desde el autorregistro y todavía no confirmó el
  /// correo: la contraseña era correcta, pero falta abrir el enlace.
  final bool correoSinVerificar;

  const ErrorDeAcceso(
    this.mensaje, {
    this.bloqueada = false,
    this.correoSinVerificar = false,
  });
}

/// El `codigo` con que la API marca un correo sin confirmar (HTTP 403).
const String codigoCorreoNoVerificado = 'CORREO_NO_VERIFICADO';

const String mensajeCorreoNoVerificado =
    'Te enviamos un enlace a tu correo cuando creaste la cuenta. Ábrelo para '
    'activarla; si no lo encuentras, revisa el correo no deseado o pide uno '
    'nuevo.';

const String mensajeCredencialesIncorrectas =
    'Correo o contraseña incorrectos.';

const String mensajeCodigoIncorrecto =
    'El código no es correcto o ya venció. Revisa tu correo o vuelve a '
    'iniciar sesión para recibir uno nuevo.';

/// Si el servidor no explica el bloqueo. Sin minutos: los dice la pantalla,
/// con los de la configuración de la clínica.
const String mensajeCuentaBloqueada =
    'Tu cuenta quedó bloqueada por varios intentos fallidos. Espera y vuelve '
    'a intentarlo, o recupera tu contraseña.';

/// Traduce el error de un intento de acceso.
///
/// El acceso atiende sus propios casos antes de caer en los genéricos:
///
/// - **401** es la respuesta a unas credenciales equivocadas (o a un código
///   de verificación que no vale), no una sesión vencida.
/// - **423** es la cuenta bloqueada tras varios intentos fallidos (cuántos y
///   por cuánto tiempo lo configura la clínica). El servidor dice cuántos
///   minutos faltan y ese texto se respeta; si no llega, se explica igual.
/// - **403 con `codigo: CORREO_NO_VERIFICADO`** es una cuenta del
///   autorregistro que todavía no abrió el enlace de su correo.
ErrorDeAcceso errorDeAcceso(Object error, {bool esCodigo = false}) {
  if (error is DioException && error.response != null) {
    final estado = error.response?.statusCode;
    final delServidor = mensajeDelServidor(error);
    final datos = error.response?.data;
    final codigo = datos is Map ? datos['codigo']?.toString() : null;

    if (estado == 403 && codigo == codigoCorreoNoVerificado) {
      return ErrorDeAcceso(
        delServidor ?? mensajeCorreoNoVerificado,
        correoSinVerificar: true,
      );
    }

    if (estado == 423) {
      return ErrorDeAcceso(
        delServidor ?? mensajeCuentaBloqueada,
        bloqueada: true,
      );
    }

    if (estado == 401) {
      return ErrorDeAcceso(
        esCodigo ? mensajeCodigoIncorrecto : mensajeCredencialesIncorrectas,
      );
    }
  }

  return ErrorDeAcceso(
    mensajeDeError(
      error,
      generico: 'No fue posible iniciar sesión. Intenta nuevamente.',
    ),
  );
}
