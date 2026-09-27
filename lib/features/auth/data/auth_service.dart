import 'package:dio/dio.dart';

import 'models/usuario.dart';

/// Lo que puede pasar al enviar correo y contraseña (o el código).
sealed class ResultadoDeAcceso {
  const ResultadoDeAcceso();
}

/// Entró: hay token y perfil.
class AccesoConcedido extends ResultadoDeAcceso {
  final String token;

  /// Segundos de vida del token, si la API los informó.
  final int? expiraEnSegundos;

  final Usuario usuario;

  const AccesoConcedido({
    required this.token,
    required this.usuario,
    this.expiraEnSegundos,
  });
}

/// La cuenta tiene verificación en dos pasos: se mandó un código al correo.
class SegundoFactorRequerido extends ResultadoDeAcceso {
  /// Identifica este intento; va de vuelta junto con el código.
  final String desafio;

  /// El correo enmascarado al que llegó el código («a***@correo.com»).
  final String destino;

  const SegundoFactorRequerido({required this.desafio, required this.destino});
}

/// La respuesta llegó, pero no tiene la forma de la API.
///
/// Es lo que devuelve un wifi con portal cautivo: una página web con un 200.
class RespuestaInesperada implements Exception {
  const RespuestaInesperada();

  @override
  String toString() =>
      'La respuesta no parece venir del servidor de la clínica. Revisa tu '
      'conexión.';
}

/// Todo lo que la aplicación le pide a `/auth` de la API.
class AuthService {
  final Dio _dio;

  AuthService(this._dio);

  /// `POST /auth/login`: 200 con token, o 200 pidiendo el segundo factor.
  /// 401 son credenciales equivocadas y 423 una cuenta bloqueada.
  Future<ResultadoDeAcceso> iniciarSesion({
    required String email,
    required String password,
  }) async {
    final respuesta = await _dio.post<dynamic>(
      '/auth/login',
      data: {'email': email.trim().toLowerCase(), 'password': password},
    );

    return interpretarAcceso(respuesta.data);
  }

  /// `POST /auth/login/2fa`: el segundo paso, con el código del correo.
  Future<ResultadoDeAcceso> verificarCodigo({
    required String desafio,
    required String codigo,
  }) async {
    final respuesta = await _dio.post<dynamic>(
      '/auth/login/2fa',
      data: {'desafio': desafio, 'codigo': codigo.trim()},
    );

    return interpretarAcceso(respuesta.data);
  }

  /// `POST /auth/password/olvido`: siempre responde lo mismo, exista o no el
  /// correo, para no revelar quién tiene cuenta. Devuelve ese mensaje.
  Future<String> pedirRecuperacion(String email) async {
    final respuesta = await _dio.post<dynamic>(
      '/auth/password/olvido',
      data: {'email': email.trim().toLowerCase()},
    );

    final datos = respuesta.data;
    final mensaje = datos is Map ? datos['message']?.toString() : null;

    return mensaje?.trim().isNotEmpty == true
        ? mensaje!.trim()
        : 'Si el correo está registrado, te enviamos un enlace para '
              'restablecer tu contraseña.';
  }

  /// `POST /auth/registro/reenviar`: otro enlace para confirmar el correo de
  /// una cuenta del autorregistro. Como la recuperación, responde siempre lo
  /// mismo —exista o no el correo, esté o no confirmado— y el servidor
  /// ignora en silencio los pedidos de más. Devuelve ese mensaje.
  Future<String> reenviarConfirmacion(String email) async {
    final respuesta = await _dio.post<dynamic>(
      '/auth/registro/reenviar',
      data: {'email': email.trim().toLowerCase()},
    );

    final datos = respuesta.data;
    final mensaje = datos is Map ? datos['message']?.toString() : null;

    return mensaje?.trim().isNotEmpty == true
        ? mensaje!.trim()
        : mensajeReenvioNeutral;
  }

  /// `GET /auth/me`: el perfil vigente, con permisos y legales pendientes.
  Future<Usuario> yo() async {
    final respuesta = await _dio.get<dynamic>('/auth/me');
    final datos = respuesta.data;
    final usuario = datos is Map && datos['user'] is Map
        ? datos['user']
        : datos;

    if (usuario is! Map) throw const RespuestaInesperada();

    return Usuario.desdeJson(usuario);
  }

  /// `PATCH /auth/me/password`. Una contraseña actual equivocada es un 400.
  Future<void> cambiarContrasena({
    required String actual,
    required String nueva,
  }) async {
    await _dio.patch<dynamic>(
      '/auth/me/password',
      data: {'currentPassword': actual, 'newPassword': nueva},
    );
  }

  /// `PATCH /auth/me/2fa`. Exige la contraseña actual.
  Future<void> cambiarDosFactores({
    required bool activo,
    required String password,
  }) async {
    await _dio.patch<dynamic>(
      '/auth/me/2fa',
      data: {'activo': activo, 'password': password},
    );
  }

  /// `PATCH /auth/:id` sobre el propio perfil, y el perfil vigente después.
  ///
  /// La API solo acepta de uno mismo el nombre, el teléfono, los datos
  /// demográficos y el perfil clínico: el correo y la cédula se cambian en la
  /// clínica. Lo demás lo descarta en silencio, así que aquí tampoco se
  /// manda (ver `CamposEditables`).
  ///
  /// Después se relee `/auth/me` en vez de usar la respuesta del PATCH: esa
  /// no trae permisos ni legales pendientes, y guardarla tal cual dejaría la
  /// sesión sin ellos.
  Future<Usuario> actualizarPerfil(
    String uid,
    Map<String, dynamic> campos,
  ) async {
    await _dio.patch<dynamic>('/auth/$uid', data: campos);

    return yo();
  }
}

/// Lo que se dice tras pedir otro enlace de confirmación, llegue o no.
const String mensajeReenvioNeutral =
    'Si el correo tiene una cuenta pendiente de confirmar, te enviamos un '
    'enlace nuevo. Revisa tu bandeja y el correo no deseado.';

/// Lee la respuesta del acceso. Fuera de la clase para poder probarla.
ResultadoDeAcceso interpretarAcceso(Object? datos) {
  if (datos is! Map) throw const RespuestaInesperada();

  if (datos['requiere2fa'] == true) {
    final desafio = datos['desafio']?.toString() ?? '';
    if (desafio.isEmpty) throw const RespuestaInesperada();

    return SegundoFactorRequerido(
      desafio: desafio,
      destino: datos['destino']?.toString() ?? 'tu correo',
    );
  }

  final token = datos['access_token']?.toString() ?? '';
  final usuario = datos['user'];

  if (token.isEmpty || usuario is! Map) throw const RespuestaInesperada();

  final expira = datos['expires_in'];

  return AccesoConcedido(
    token: token,
    usuario: Usuario.desdeJson(usuario),
    expiraEnSegundos: expira is num ? expira.toInt() : null,
  );
}

/// Los campos del propio perfil que la API deja cambiar (`SELF_FIELDS` del
/// gateway). La pantalla de edición solo arma estos.
class CamposEditables {
  const CamposEditables._();

  static const List<String> todos = [
    'nombre',
    'telefono',
    'tipoDocumento',
    'fechaNacimiento',
    'sexo',
    'direccion',
    'tipoSangre',
    'alergias',
    'contactoEmergencia',
    'antecedentesPersonales',
    'antecedentesFamiliares',
    'habitos',
    'medicacionHabitual',
    'embarazo',
    'antecedentesObstetricos',
    'representante',
  ];

  /// Deja solo lo permitido: lo demás la API lo ignoraría sin avisar.
  static Map<String, dynamic> filtrar(Map<String, dynamic> campos) => {
    for (final entrada in campos.entries)
      if (todos.contains(entrada.key)) entrada.key: entrada.value,
  };
}
