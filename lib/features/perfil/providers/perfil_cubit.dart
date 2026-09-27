import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../../../core/service/biometria_service.dart';
import '../../../core/storage/credenciales_service.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/data/models/usuario.dart';

/// Cómo terminó la última operación del perfil.
class OperacionPerfil extends Equatable {
  final bool exito;
  final String mensaje;

  /// El perfil nuevo, cuando la operación lo cambió.
  final Usuario? usuario;

  final int secuencia;

  const OperacionPerfil({
    required this.exito,
    required this.mensaje,
    required this.secuencia,
    this.usuario,
  });

  @override
  List<Object?> get props => [exito, mensaje, usuario, secuencia];
}

class PerfilState extends Equatable {
  final bool guardando;
  final OperacionPerfil? operacion;
  final bool biometriaDisponible;
  final bool biometriaActiva;

  const PerfilState({
    this.guardando = false,
    this.operacion,
    this.biometriaDisponible = false,
    this.biometriaActiva = false,
  });

  PerfilState copiarCon({
    bool? guardando,
    OperacionPerfil? operacion,
    bool? biometriaDisponible,
    bool? biometriaActiva,
  }) {
    return PerfilState(
      guardando: guardando ?? this.guardando,
      operacion: operacion ?? this.operacion,
      biometriaDisponible: biometriaDisponible ?? this.biometriaDisponible,
      biometriaActiva: biometriaActiva ?? this.biometriaActiva,
    );
  }

  @override
  List<Object?> get props => [
    guardando,
    operacion,
    biometriaDisponible,
    biometriaActiva,
  ];
}

/// Lo que se hace desde el perfil: editar datos, cambiar la contraseña,
/// la verificación en dos pasos y el acceso con huella.
class PerfilCubit extends Cubit<PerfilState> {
  final AuthService _auth;
  final CredencialesService _credenciales;
  final BiometriaService _biometria;

  int _secuencia = 0;

  PerfilCubit({
    required this._auth,
    required this._credenciales,
    required this._biometria,
  }) : super(const PerfilState());

  Future<void> cargarBiometria() async {
    final disponible = await _biometria.disponible();
    final activa = await _credenciales.biometriaActiva();

    if (!isClosed) {
      emit(
        state.copiarCon(
          biometriaDisponible: disponible,
          biometriaActiva: disponible && activa,
        ),
      );
    }
  }

  void _terminar(bool exito, String mensaje, {Usuario? usuario}) {
    emit(
      state.copiarCon(
        guardando: false,
        operacion: OperacionPerfil(
          exito: exito,
          mensaje: mensaje,
          usuario: usuario,
          secuencia: ++_secuencia,
        ),
      ),
    );
  }

  /// Guarda los datos propios que la API deja cambiar.
  Future<void> guardarPerfil(String uid, Map<String, dynamic> campos) async {
    if (state.guardando) return;
    emit(state.copiarCon(guardando: true));

    try {
      final usuario = await _auth.actualizarPerfil(
        uid,
        CamposEditables.filtrar(campos),
      );
      _terminar(true, 'Tus datos quedaron guardados.', usuario: usuario);
    } catch (error) {
      _terminar(
        false,
        mensajeDeError(error, generico: 'No se pudieron guardar tus datos.'),
      );
    }
  }

  Future<void> cambiarContrasena({
    required String actual,
    required String nueva,
  }) async {
    if (state.guardando) return;
    emit(state.copiarCon(guardando: true));

    try {
      await _auth.cambiarContrasena(actual: actual, nueva: nueva);

      // La contraseña guardada para la huella ya no sirve: se reemplaza por
      // la nueva, para que el atajo siga funcionando.
      final guardadas = await _credenciales.leer();
      if (guardadas != null) {
        await _credenciales.guardar(email: guardadas.email, password: nueva);
      }

      _terminar(true, 'Listo, tu contraseña cambió.');
    } catch (error) {
      _terminar(
        false,
        mensajeDeError(error, generico: 'No se pudo cambiar la contraseña.'),
      );
    }
  }

  Future<void> cambiarDosFactores({
    required bool activo,
    required String password,
  }) async {
    if (state.guardando) return;
    emit(state.copiarCon(guardando: true));

    try {
      await _auth.cambiarDosFactores(activo: activo, password: password);
      final usuario = await _auth.yo();

      _terminar(
        true,
        activo
            ? 'Verificación en dos pasos activada: te pediremos un código al '
                  'entrar.'
            : 'Verificación en dos pasos desactivada.',
        usuario: usuario,
      );
    } catch (error) {
      _terminar(
        false,
        mensajeDeError(error, generico: 'No se pudo cambiar la verificación.'),
      );
    }
  }

  /// Enciende o apaga el acceso con huella.
  ///
  /// Apagarlo borra la contraseña guardada: si la persona dijo que no, no
  /// hay motivo para conservarla. Encenderlo pide la huella una vez, para
  /// comprobar que el teléfono puede; la contraseña se guarda la próxima vez
  /// que entre escribiéndola.
  Future<void> cambiarBiometria(bool activa) async {
    if (!activa) {
      await _credenciales.fijarBiometriaActiva(false);
      await _credenciales.borrar();
      emit(state.copiarCon(biometriaActiva: false));
      _terminar(true, 'Listo, ya no se entrará con huella en este teléfono.');
      return;
    }

    final verificado = await _biometria.verificar(
      'Confirma que quieres entrar con tu huella',
    );
    if (!verificado) return;

    await _credenciales.fijarBiometriaActiva(true);
    emit(state.copiarCon(biometriaActiva: true));

    final guardadas = await _credenciales.leer();
    _terminar(
      true,
      guardadas == null
          ? 'Activado. La próxima vez que entres con tu contraseña quedará '
                'lista la huella.'
          : 'Activado. Ya puedes entrar con tu huella.',
    );
  }
}
