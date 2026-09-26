import 'dart:async';

import 'package:dio/dio.dart';

import '../config/entorno.dart';
import 'api_interceptor.dart';
import 'corte_rapido_sin_red.dart';

/// Cliente HTTP de toda la aplicación.
///
/// Es un singleton a propósito: el token de la sesión y el aviso de sesión
/// vencida viven aquí, y solo funcionan si todas las pantallas comparten el
/// mismo Dio. Un `Dio()` aparte no llevaría el token ni avisaría del 401.
/// `ApiClient()` puede llamarse donde sea: devuelve siempre la misma
/// instancia.
class ApiClient {
  factory ApiClient() => _instancia;

  ApiClient._()
    : dio = Dio(
        BaseOptions(
          baseUrl: Entorno.apiUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ) {
    // El portero va primero: si ya se sabe que no hay salida, la petición
    // se corta sin gastar el plazo. Ver `CorteRapidoSinRed`.
    dio.interceptors.add(CorteRapidoSinRed());
    dio.interceptors.add(
      ApiInterceptor(
        leerToken: () => token,
        alVencerLaSesion: () => _sesionVencida.add(null),
      ),
    );
  }

  static final ApiClient _instancia = ApiClient._();

  final Dio dio;

  final StreamController<void> _sesionVencida =
      StreamController<void>.broadcast();

  /// El token que se adjunta a cada petición. `null` al cerrar sesión.
  String? token;

  /// Avisa cada vez que una petición con sesión vuelve 401.
  Stream<void> get sesionVencida => _sesionVencida.stream;
}
