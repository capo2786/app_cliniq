import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/auth_service.dart';

class RestablecerState extends Equatable {
  final bool guardando;

  /// La contraseña quedó cambiada.
  final bool listo;

  /// Por qué el servidor no la cambió (un enlace vencido, una contraseña
  /// que no cumple), una sola vez, hasta el siguiente intento.
  final String? error;

  const RestablecerState({
    this.guardando = false,
    this.listo = false,
    this.error,
  });

  @override
  List<Object?> get props => [guardando, listo, error];
}

/// El enlace «Restablecer contraseña» abierto en la aplicación: la
/// contraseña nueva va a `POST /auth/password/restablecer` con el `token`
/// del enlace, como en la página del panel.
class RestablecerCubit extends Cubit<RestablecerState> {
  final AuthService _servicio;
  final String _token;

  RestablecerCubit(this._servicio, String token)
    : _token = token.trim(),
      super(const RestablecerState());

  Future<void> guardar(String nueva) async {
    if (state.guardando || state.listo || _token.isEmpty) return;

    emit(const RestablecerState(guardando: true));

    try {
      await _servicio.restablecerContrasena(token: _token, nueva: nueva);
      emit(const RestablecerState(listo: true));
    } catch (error) {
      emit(
        RestablecerState(
          error: mensajeDeError(
            error,
            generico: 'No pudimos guardar tu contraseña. Intenta de nuevo.',
          ),
        ),
      );
    }
  }
}
