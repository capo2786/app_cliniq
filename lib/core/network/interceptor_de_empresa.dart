// lib/core/network/interceptor_de_empresa.dart

import 'dart:async';

import 'package:dio/dio.dart';

/// La cabecera con que se dice a la API de qué clínica es una petición.
const String cabeceraEmpresa = 'X-Empresa';

/// Marca (en `RequestOptions.extra`) de una petición que no es de ninguna
/// clínica: la búsqueda de un código (`/empresas/publica/:codigo`). No lleva
/// `X-Empresa`, y su 403 es de la clínica buscada, no de la guardada.
const String sinEmpresa = 'cliniq.sinEmpresa';

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

  /// Se llama cuando la clínica que iba en `X-Empresa` respondió que no
  /// está disponible (ver [clinicaNoDisponibleDe]), con su código. Lo pone
  /// `ClinicaCubit`, que la olvida y sigue con la predeterminada; la
  /// petición termina con su error después de eso.
  static Future<void> Function(String codigo)? alNoEstarDisponible;
}

/// El código de la clínica que no está disponible según [error], o `null`
/// si es otro error.
///
/// Una clínica SUSPENDIDA responde 403 «Esta clínica no está disponible»
/// (`codigo: EMPRESA_NO_DISPONIBLE`) a todo lo que lleva su `X-Empresa`: la
/// configuración pública, los catálogos, el acceso… Solo cuenta sin sesión
/// y con ese mensaje: con el token, un 403 es de permisos (y la clínica la
/// dice el token, no la cabecera); y el acceso tiene otros 403 que no son
/// de la clínica.
String? clinicaNoDisponibleDe(DioException error) {
  final respuesta = error.response;
  if (respuesta?.statusCode != 403) return null;

  final cabeceras = error.requestOptions.headers;
  if (_cabecera(cabeceras, 'Authorization')?.isNotEmpty ?? false) return null;

  final codigo = _cabecera(cabeceras, cabeceraEmpresa) ?? '';
  if (codigo.isEmpty) return null;

  final datos = respuesta?.data;
  if (datos is! Map) return null;

  final mensaje = datos['message']?.toString().toLowerCase() ?? '';
  final esLaClinica =
      datos['codigo'] == 'EMPRESA_NO_DISPONIBLE' ||
      mensaje.contains('clínica no está disponible');

  return esLaClinica ? codigo : null;
}

/// El valor de una cabecera sin mirar mayúsculas, o `null` si no va.
String? _cabecera(Map<String, dynamic> cabeceras, String nombre) {
  for (final MapEntry(:key, :value) in cabeceras.entries) {
    if (key.toLowerCase() == nombre.toLowerCase()) {
      return value?.toString().trim();
    }
  }
  return null;
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
///
/// Y si la clínica de la cabecera ya no está disponible (suspendida), lo
/// avisa con [EmpresaDeLasPeticiones.alNoEstarDisponible] antes de dejar
/// pasar el error: así quien la pidió (la configuración, los catálogos)
/// recibe el error ya sin la clínica guardada, y lo que vuelva a pedir sale
/// a la predeterminada en vez de quedarse en «no pudimos cargar» para
/// siempre.
class InterceptorDeEmpresa extends Interceptor {
  final String? Function() _leerCodigo;
  final Future<void> Function(String codigo) _alNoEstarDisponible;

  InterceptorDeEmpresa({
    String? Function()? leerCodigo,
    Future<void> Function(String codigo)? alNoEstarDisponible,
  }) : _leerCodigo = leerCodigo ?? (() => EmpresaDeLasPeticiones.codigo),
       _alNoEstarDisponible =
           alNoEstarDisponible ??
           ((codigo) async =>
               EmpresaDeLasPeticiones.alNoEstarDisponible?.call(codigo));

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final codigo = options.extra[sinEmpresa] == true
        ? null
        : empresaParaLaPeticion(
            cabeceras: options.headers,
            guardada: _leerCodigo(),
          );

    if (codigo != null) options.headers[cabeceraEmpresa] = codigo;

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final codigo = clinicaNoDisponibleDe(err);
    if (codigo == null) {
      handler.next(err);
      return;
    }

    unawaited(
      _alNoEstarDisponible(codigo)
          .catchError((Object _) {})
          .whenComplete(() => handler.next(err)),
    );
  }
}
