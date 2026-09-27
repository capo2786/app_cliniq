import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/auth_service.dart';

/// En qué va la confirmación del correo.
enum EtapaConfirmacion {
  /// Esperando al servidor.
  confirmando,

  /// La cuenta quedó activa.
  confirmada,

  /// El enlace venció, ya se usó o no existe (400): se puede pedir otro.
  enlaceInvalido,

  /// El enlace llegó sin su `token`.
  enlaceIncompleto,

  /// No se pudo hablar con el servidor, o respondió con un error suyo: se
  /// puede reintentar con el mismo enlace.
  fallo,
}

class ConfirmarCorreoState extends Equatable {
  final EtapaConfirmacion etapa;

  /// Lo que dijo el servidor (el éxito o el motivo), una sola vez.
  final String mensaje;

  final bool reenviando;

  /// El correo al que se pidió un enlace nuevo; `null` si no se pidió.
  final String? reenviadoA;

  final String? errorReenvio;

  const ConfirmarCorreoState({
    required this.etapa,
    this.mensaje = '',
    this.reenviando = false,
    this.reenviadoA,
    this.errorReenvio,
  });

  ConfirmarCorreoState copiarCon({
    EtapaConfirmacion? etapa,
    String? mensaje,
    bool? reenviando,
    String? reenviadoA,
    String? errorReenvio,
    bool limpiarErrorReenvio = false,
  }) {
    return ConfirmarCorreoState(
      etapa: etapa ?? this.etapa,
      mensaje: mensaje ?? this.mensaje,
      reenviando: reenviando ?? this.reenviando,
      reenviadoA: reenviadoA ?? this.reenviadoA,
      errorReenvio: limpiarErrorReenvio
          ? null
          : (errorReenvio ?? this.errorReenvio),
    );
  }

  @override
  List<Object?> get props => [
    etapa,
    mensaje,
    reenviando,
    reenviadoA,
    errorReenvio,
  ];
}

/// El enlace «Confirmar mi correo» abierto en la aplicación: confirma solo
/// al abrirse (`POST /auth/registro/confirmar`), como la página del panel.
/// Si el enlace ya no sirve, deja pedir otro sin volver a registrarse
/// (`POST /auth/registro/reenviar`).
class ConfirmarCorreoCubit extends Cubit<ConfirmarCorreoState> {
  final AuthService _servicio;
  final String _token;

  ConfirmarCorreoCubit(this._servicio, String token)
    : _token = token.trim(),
      super(
        ConfirmarCorreoState(
          etapa: token.trim().isEmpty
              ? EtapaConfirmacion.enlaceIncompleto
              : EtapaConfirmacion.confirmando,
        ),
      );

  Future<void> confirmar() async {
    if (_token.isEmpty) return;

    emit(const ConfirmarCorreoState(etapa: EtapaConfirmacion.confirmando));

    try {
      final mensaje = await _servicio.confirmarCorreo(_token);
      emit(
        ConfirmarCorreoState(
          etapa: EtapaConfirmacion.confirmada,
          mensaje: mensaje,
        ),
      );
    } catch (error) {
      final estado = estadoDe(error);
      final invalido = estado == 400 || estado == 404;

      emit(
        ConfirmarCorreoState(
          etapa: invalido
              ? EtapaConfirmacion.enlaceInvalido
              : EtapaConfirmacion.fallo,
          mensaje: invalido
              ? (mensajeDelServidor(error) ?? '')
              : mensajeDeError(
                  error,
                  generico: 'No pudimos confirmar tu correo. Intenta de nuevo.',
                ),
        ),
      );
    }
  }

  /// Pide otro enlace para [correo]. La respuesta es la misma exista o no la
  /// cuenta.
  Future<void> reenviar(String correo) async {
    if (state.reenviando) return;

    emit(state.copiarCon(reenviando: true, limpiarErrorReenvio: true));

    try {
      await _servicio.reenviarConfirmacion(correo);
      emit(
        state.copiarCon(
          reenviando: false,
          reenviadoA: correo.trim().toLowerCase(),
        ),
      );
    } catch (error) {
      emit(
        state.copiarCon(
          reenviando: false,
          errorReenvio: mensajeDeError(
            error,
            generico: 'No pudimos pedir el enlace. Intenta de nuevo.',
          ),
        ),
      );
    }
  }
}
