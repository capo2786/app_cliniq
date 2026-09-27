import 'package:equatable/equatable.dart';

import '../data/models/usuario.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Recién abierta: se está mirando si hay una sesión guardada.
class AuthInicial extends AuthState {
  const AuthInicial();
}

/// Sin sesión: se enseña el acceso.
class AuthNoAutenticado extends AuthState {
  /// Algo que decir al llegar al acceso, como que la sesión venció.
  final String? aviso;

  const AuthNoAutenticado({this.aviso});

  @override
  List<Object?> get props => [aviso];
}

/// Se están comprobando las credenciales.
class AuthCargando extends AuthState {
  const AuthCargando();
}

/// La cuenta tiene verificación en dos pasos: falta el código del correo.
class AuthRequiere2fa extends AuthState {
  final String desafio;

  /// El correo enmascarado al que llegó el código.
  final String destino;

  final bool enviando;
  final String? error;

  const AuthRequiere2fa({
    required this.desafio,
    required this.destino,
    this.enviando = false,
    this.error,
  });

  AuthRequiere2fa copiarCon({bool? enviando, String? error}) => AuthRequiere2fa(
    desafio: desafio,
    destino: destino,
    enviando: enviando ?? this.enviando,
    error: error,
  );

  @override
  List<Object?> get props => [desafio, destino, enviando, error];
}

/// Dentro.
class AuthAutenticado extends AuthState {
  final Usuario usuario;

  /// Se restauró la sesión guardada sin poder confirmarla con el servidor.
  final bool sinConexion;

  /// Venía de una sesión guardada, no de escribir la contraseña.
  final bool restaurada;

  const AuthAutenticado(
    this.usuario, {
    this.sinConexion = false,
    this.restaurada = false,
  });

  @override
  List<Object?> get props => [usuario, sinConexion, restaurada];
}

/// No se pudo entrar.
class AuthError extends AuthState {
  final String mensaje;

  /// La cuenta quedó bloqueada 15 minutos (HTTP 423).
  final bool bloqueada;

  /// Falta confirmar el correo (HTTP 403, `CORREO_NO_VERIFICADO`).
  final bool correoSinVerificar;

  /// El correo con que se intentó entrar, para pedir otro enlace de
  /// confirmación sin volver a escribirlo. Solo con [correoSinVerificar].
  final String? correo;

  const AuthError(
    this.mensaje, {
    this.bloqueada = false,
    this.correoSinVerificar = false,
    this.correo,
  });

  @override
  List<Object?> get props => [mensaje, bloqueada, correoSinVerificar, correo];
}

/// Las credenciales eran buenas, pero la cuenta no es de un paciente: es del
/// personal de la clínica, que trabaja en el panel web. No se abre la sesión.
class AuthCuentaDelPersonal extends AuthState {
  const AuthCuentaDelPersonal();
}
