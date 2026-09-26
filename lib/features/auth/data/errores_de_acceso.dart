import 'package:dio/dio.dart';

import '../../../core/network/errores.dart';

/// Por qué no se pudo entrar, en palabras de la persona.
class ErrorDeAcceso {
  final String mensaje;

  /// La cuenta quedó bloqueada 15 minutos por varios intentos fallidos.
  final bool bloqueada;

  const ErrorDeAcceso(this.mensaje, {this.bloqueada = false});
}

const String mensajeCredencialesIncorrectas =
    'Correo o contraseña incorrectos.';

const String mensajeCodigoIncorrecto =
    'El código no es correcto o ya venció. Revisa tu correo o vuelve a '
    'iniciar sesión para recibir uno nuevo.';

const String mensajeCuentaBloqueada =
    'Tu cuenta quedó bloqueada 15 minutos por varios intentos fallidos. '
    'Espera y vuelve a intentarlo, o recupera tu contraseña.';

/// Traduce el error de un intento de acceso.
///
/// El acceso atiende sus propios casos antes de caer en los genéricos:
///
/// - **401** es la respuesta a unas credenciales equivocadas (o a un código
///   de verificación que no vale), no una sesión vencida.
/// - **423** es la cuenta bloqueada: cinco intentos fallidos en quince
///   minutos la cierran otros quince. El servidor dice cuántos minutos
///   faltan y ese texto se respeta; si no llega, se explica igual.
ErrorDeAcceso errorDeAcceso(Object error, {bool esCodigo = false}) {
  if (error is DioException && error.response != null) {
    final estado = error.response?.statusCode;
    final delServidor = mensajeDelServidor(error);

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
