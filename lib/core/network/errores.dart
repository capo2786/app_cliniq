import 'package:dio/dio.dart';

/// Traducción genérica de errores de red a mensajes para la persona.
///
/// Es el punto único para los casos genéricos; los módulos con errores
/// propios (las credenciales y la cuenta bloqueada en el acceso, por ejemplo)
/// atienden primero los suyos y caen aquí para el resto.
String mensajeDeError(
  Object error, {
  String generico = 'Ocurrió un error inesperado. Intenta de nuevo.',
}) {
  if (error is! DioException) return generico;

  // Con `default` a propósito: dio agrega valores al enum entre versiones
  // y un switch exhaustivo dejaría de compilar con cada actualización.
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'El servidor tardó demasiado en responder. '
          'Revisa tu conexión e intenta de nuevo.';

    case DioExceptionType.badResponse:
      return _porEstado(error) ?? generico;

    case DioExceptionType.cancel:
      return 'La operación se canceló.';

    // connectionError, badCertificate, unknown y lo que traiga el futuro:
    // para la persona todos significan que no se pudo hablar con el servidor.
    default:
      return 'Sin conexión con el servidor. Revisa tu Internet.';
  }
}

String? _porEstado(DioException error) {
  final estado = error.response?.statusCode ?? 0;

  // El servidor casi siempre explica el motivo; ese texto es mejor que
  // cualquier genérico, porque está escrito para esta operación concreta.
  final delServidor = mensajeDelServidor(error);

  if (delServidor != null) return delServidor;

  if (estado == 401) return 'Tu sesión venció. Vuelve a iniciar sesión.';
  if (estado == 403) return 'Tu cuenta no tiene permiso para hacer esto.';
  if (estado == 404) return 'No se encontró lo que buscabas.';
  if (estado == 409) return 'La operación choca con un registro existente.';
  if (estado == 423) {
    return 'La cuenta está bloqueada temporalmente. Intenta en 15 minutos.';
  }
  if (estado >= 500) {
    return 'El servidor tuvo un problema. Intenta en unos minutos.';
  }

  return null;
}

/// El campo `message` que envía la API en sus errores, si viene y es legible.
///
/// La API responde siempre `{status, message}`, y `message` llega como texto
/// o como lista de textos (las validaciones de NestJS); ambos se aceptan y
/// cualquier otra forma se descarta.
String? mensajeDelServidor(Object error) {
  if (error is! DioException) return null;

  final datos = error.response?.data;
  if (datos is! Map) return null;

  final mensaje = datos['message'];

  if (mensaje is String && mensaje.trim().isNotEmpty) return mensaje.trim();

  if (mensaje is List && mensaje.isNotEmpty) {
    final lineas = mensaje
        .map((linea) => linea.toString().trim())
        .where((linea) => linea.isNotEmpty)
        .toList();

    return lineas.isEmpty ? null : lineas.join('\n');
  }

  return null;
}

/// El código HTTP de un error, si lo hubo.
int? estadoDe(Object error) =>
    error is DioException ? error.response?.statusCode : null;

/// Si el error fue no poder hablar con el servidor (y no una respuesta mala).
bool esFaltaDeRed(Object error) {
  if (error is! DioException) return false;

  return switch (error.type) {
    DioExceptionType.connectionError => true,
    DioExceptionType.connectionTimeout => true,
    DioExceptionType.sendTimeout => true,
    DioExceptionType.receiveTimeout => true,
    DioExceptionType.unknown => error.response == null,
    _ => false,
  };
}
