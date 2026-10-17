// lib/core/network/interceptor_de_empresa.dart

import 'package:dio/dio.dart';

/// La cabecera con que se dice a la API de qué clínica es una petición.
const String cabeceraEmpresa = 'X-Empresa';

/// El código de la clínica que la aplicación tiene guardada, para las
/// peticiones sin sesión.
///
/// Vive aquí, como el token en `ApiClient`, porque lo tiene que leer cada
/// petición y todas comparten el mismo Dio. Lo mantiene al día
/// `ClinicaCubit`; `null` es «ninguna»: la API usa entonces su clínica
/// predeterminada, como antes de haber varias.
class EmpresaDeLasPeticiones {
  const EmpresaDeLasPeticiones._();

  static String? codigo;
}

/// La clínica que va en `X-Empresa`, o `null` si no va ninguna.
///
/// - **Con sesión** (la petición lleva `Authorization`) no va: el token ya
///   dice de qué clínica es, y la API no deja que una cabecera la cambie.
/// - **Si la petición ya trae la cabecera** (el acceso tras elegir la
///   clínica), se respeta la suya.
/// - **Sin sesión**, la clínica guardada, si hay una.
String? empresaParaLaPeticion({
  required Map<String, dynamic> cabeceras,
  required String? guardada,
}) {
  bool tiene(String nombre) => cabeceras.keys.any(
    (clave) => clave.toLowerCase() == nombre.toLowerCase(),
  );

  if (tiene('Authorization') || tiene(cabeceraEmpresa)) return null;

  final codigo = guardada?.trim() ?? '';
  return codigo.isEmpty ? null : codigo;
}

/// Agrega `X-Empresa` a las peticiones sin sesión (ver
/// [empresaParaLaPeticion]). Va después de `ApiInterceptor`, que es quien
/// pone el token.
class InterceptorDeEmpresa extends Interceptor {
  final String? Function() _leerCodigo;

  InterceptorDeEmpresa({String? Function()? leerCodigo})
    : _leerCodigo = leerCodigo ?? (() => EmpresaDeLasPeticiones.codigo);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final codigo = empresaParaLaPeticion(
      cabeceras: options.headers,
      guardada: _leerCodigo(),
    );

    if (codigo != null) options.headers[cabeceraEmpresa] = codigo;

    handler.next(options);
  }
}
