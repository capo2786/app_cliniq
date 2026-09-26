import 'package:equatable/equatable.dart';

import '../data/models/usuario.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Al abrir la aplicación: ¿quedó una sesión guardada en este teléfono?
class AuthSesionRestaurada extends AuthEvent {
  const AuthSesionRestaurada();
}

/// La persona envió correo y contraseña (a mano o con la huella).
class AuthLoginSolicitado extends AuthEvent {
  final String email;
  final String password;

  const AuthLoginSolicitado({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

/// El código de verificación en dos pasos que llegó al correo.
class AuthCodigoEnviado extends AuthEvent {
  final String codigo;

  const AuthCodigoEnviado(this.codigo);

  @override
  List<Object?> get props => [codigo];
}

/// Volver del paso del código al formulario.
class AuthCodigoCancelado extends AuthEvent {
  const AuthCodigoCancelado();
}

/// Cerrar sesión, ya confirmado por la persona.
class AuthCierreSolicitado extends AuthEvent {
  const AuthCierreSolicitado();
}

/// Una petición con sesión volvió 401: el token venció.
class AuthSesionVencida extends AuthEvent {
  const AuthSesionVencida();
}

/// Releer el perfil de la API (`GET /auth/me`).
class AuthPerfilRefrescado extends AuthEvent {
  const AuthPerfilRefrescado();
}

/// El perfil cambió por otra vía (edición, legales) y ya se tiene el nuevo.
class AuthPerfilActualizado extends AuthEvent {
  final Usuario usuario;

  const AuthPerfilActualizado(this.usuario);

  @override
  List<Object?> get props => [usuario];
}
