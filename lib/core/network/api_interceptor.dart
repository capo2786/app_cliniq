import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../red/estado_de_la_red.dart';

/// Adjunta el token de la sesión y detecta cuándo venció.
///
/// La API no tiene token de renovación: cuando el JWT caduca, cualquier
/// petición con sesión vuelve 401 y no hay forma de estirarla. Lo único que
/// se puede hacer bien es decirlo una vez, con claridad, y llevar a la
/// persona al acceso. Eso es lo que hace [alVencerLaSesion].
///
/// Un 401 **no** significa sesión vencida en las rutas del propio acceso:
/// ahí quiere decir «correo o contraseña incorrectos» o «código incorrecto»,
/// y lo atiende la pantalla de acceso.
class ApiInterceptor extends Interceptor {
  /// El token vigente, o `null` sin sesión.
  final String? Function() leerToken;

  /// Se llama cuando una petición con sesión vuelve 401.
  final void Function() alVencerLaSesion;

  SondeoDeRed? _sondeo;

  ApiInterceptor({
    required this.leerToken,
    required this.alVencerLaSesion,
    this._sondeo,
  });

  // Perezoso: ver el comentario de `SondeoDeRed._dio`.
  SondeoDeRed get _sondeoDeRed => _sondeo ??= SondeoDeRed();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = leerToken();

    if (token != null &&
        token.isNotEmpty &&
        !options.headers.containsKey('Authorization')) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Solo en depuración: en publicación esto escribiría en el registro del
    // teléfono cada dirección que se toca, identificadores incluidos.
    if (kDebugMode) {
      debugPrint('[API] ${options.method} ${options.path}');
    }

    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (response.requestOptions.extra[SondeoDeRed.marcaDeSondeo] != true) {
      _sondeoDeRed.anotarExito();
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _sondeoDeRed.anotarFallo(err);

    final llevabaSesion =
        err.requestOptions.headers['Authorization']?.toString().isNotEmpty ??
        false;

    if (err.response?.statusCode == 401 &&
        llevabaSesion &&
        !esRutaDeAcceso(err.requestOptions.path)) {
      alVencerLaSesion();
    }

    handler.next(err);
  }
}

/// Las rutas donde un 401 es una respuesta de la pantalla de acceso y no una
/// sesión vencida.
bool esRutaDeAcceso(String ruta) {
  return ruta.contains('/auth/login') || ruta.contains('/auth/password/');
}
