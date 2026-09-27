import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../../../core/storage/credenciales_service.dart';
import '../data/almacen_de_sesion.dart';
import '../data/auth_service.dart';
import '../data/errores_de_acceso.dart';
import '../data/models/usuario.dart';
import 'auth_event.dart';
import 'auth_state.dart';

const String avisoSesionVencida =
    'Tu sesión venció. Vuelve a iniciar sesión para continuar.';

/// Lo que se dice cuando entra alguien del personal de la clínica. Debajo
/// va la dirección del panel, para copiarla (no se abre desde aquí).
const String avisoSoloPacientes =
    'Esta aplicación es para pacientes. El personal de la clínica usa el '
    'panel web desde una computadora, en esta dirección:';

/// La sesión: entrar, el segundo factor, restaurar, vencer y salir.
///
/// No hay token de renovación en la API. Cuando el token caduca no hay nada
/// que estirar: se borra todo lo de la sesión y se lleva a la persona al
/// acceso con un aviso claro, que es mejor que una pantalla llena de errores
/// «401».
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _servicio;
  final AlmacenDeSesion _almacen;
  final CredencialesService _credenciales;

  /// Pone o quita el token en el cliente HTTP compartido.
  final void Function(String? token) _fijarToken;

  /// Borra lo guardado en el teléfono que es de esta persona: citas,
  /// dependientes, recordatorios programados.
  final Future<void> Function() _limpiarDatosLocales;

  final DateTime Function() _reloj;

  StreamSubscription<void>? _escuchaDeVencimiento;

  /// Correo y contraseña mientras se espera el código del segundo factor.
  ///
  /// Se guardan en el llavero solo cuando el código se acepta: hasta ese
  /// momento el acceso no está concedido.
  ({String email, String password})? _pendiente;

  AuthBloc({
    required this._servicio,
    required this._almacen,
    required this._credenciales,
    required this._fijarToken,
    Stream<void>? sesionVencida,
    Future<void> Function()? limpiarDatosLocales,
    DateTime Function()? reloj,
    bool restaurarAlCrear = true,
  }) : _limpiarDatosLocales = limpiarDatosLocales ?? (() async {}),
       _reloj = reloj ?? DateTime.now,
       super(const AuthInicial()) {
    on<AuthSesionRestaurada>(_alRestaurar);
    on<AuthLoginSolicitado>(_alEntrar);
    on<AuthCodigoEnviado>(_alRecibirCodigo);
    on<AuthCodigoCancelado>(_alCancelarCodigo);
    on<AuthCierreSolicitado>(_alSalir);
    on<AuthSesionVencida>(_alVencer);
    on<AuthPerfilRefrescado>(_alRefrescarPerfil);
    on<AuthPerfilActualizado>(_alActualizarPerfil);

    _escuchaDeVencimiento = sesionVencida?.listen(
      (_) => add(const AuthSesionVencida()),
    );

    if (restaurarAlCrear) add(const AuthSesionRestaurada());
  }

  /// La persona con la sesión abierta, si la hay.
  Usuario? get usuario {
    final actual = state;
    return actual is AuthAutenticado ? actual.usuario : null;
  }

  // ── Restaurar ──────────────────────────────────────────────────────

  Future<void> _alRestaurar(
    AuthSesionRestaurada event,
    Emitter<AuthState> emit,
  ) async {
    final sesion = await _almacen.leer();

    if (sesion == null) {
      emit(const AuthNoAutenticado());
      return;
    }

    // Vencida según su propia fecha: ni se pregunta al servidor.
    if (sesion.vencida(_reloj())) {
      await _olvidarSesion();
      emit(const AuthNoAutenticado(aviso: avisoSesionVencida));
      return;
    }

    _fijarToken(sesion.token);

    /*
     * Se confirma con el servidor antes de abrir, con un plazo corto.
     *
     * No es desconfianza del token: es que la respuesta trae los documentos
     * legales pendientes, y si la clínica publicó una versión nueva desde la
     * última vez hay que pasar por la aceptación antes que por el inicio.
     * Sin red se abre igual con el perfil guardado: las citas guardadas se
     * tienen que poder ver en la sala de espera sin cobertura.
     */
    try {
      final usuario = await _servicio.yo().timeout(const Duration(seconds: 6));

      if (!usuario.esPaciente) {
        await _olvidarSesion();
        emit(const AuthCuentaDelPersonal());
        return;
      }

      await _almacen.actualizarUsuario(usuario);
      emit(AuthAutenticado(usuario, restaurada: true));
    } catch (error) {
      if (estadoDe(error) == 401) {
        await _olvidarSesion();
        emit(const AuthNoAutenticado(aviso: avisoSesionVencida));
        return;
      }

      if (!sesion.usuario.esPaciente) {
        await _olvidarSesion();
        emit(const AuthCuentaDelPersonal());
        return;
      }

      emit(
        AuthAutenticado(sesion.usuario, restaurada: true, sinConexion: true),
      );
    }
  }

  // ── Entrar ─────────────────────────────────────────────────────────

  Future<void> _alEntrar(
    AuthLoginSolicitado event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthCargando());

    final email = event.email.trim().toLowerCase();

    try {
      final resultado = await _servicio.iniciarSesion(
        email: email,
        password: event.password,
      );

      switch (resultado) {
        case AccesoConcedido():
          await _completarAcceso(resultado, email, event.password, emit);
        case SegundoFactorRequerido():
          _pendiente = (email: email, password: event.password);
          emit(
            AuthRequiere2fa(
              desafio: resultado.desafio,
              destino: resultado.destino,
            ),
          );
      }
    } catch (error) {
      final traducido = errorDeAcceso(error);
      emit(
        AuthError(
          traducido.mensaje,
          bloqueada: traducido.bloqueada,
          correoSinVerificar: traducido.correoSinVerificar,
          correo: traducido.correoSinVerificar ? email : null,
        ),
      );
    }
  }

  Future<void> _alRecibirCodigo(
    AuthCodigoEnviado event,
    Emitter<AuthState> emit,
  ) async {
    final actual = state;
    final pendiente = _pendiente;

    if (actual is! AuthRequiere2fa || pendiente == null || actual.enviando) {
      return;
    }

    emit(actual.copiarCon(enviando: true));

    try {
      final resultado = await _servicio.verificarCodigo(
        desafio: actual.desafio,
        codigo: event.codigo,
      );

      if (resultado is! AccesoConcedido) {
        emit(actual.copiarCon(enviando: false, error: mensajeCodigoIncorrecto));
        return;
      }

      await _completarAcceso(
        resultado,
        pendiente.email,
        pendiente.password,
        emit,
      );
    } catch (error) {
      final traducido = errorDeAcceso(error, esCodigo: true);

      if (traducido.bloqueada) {
        _pendiente = null;
        emit(AuthError(traducido.mensaje, bloqueada: true));
        return;
      }

      emit(actual.copiarCon(enviando: false, error: traducido.mensaje));
    }
  }

  void _alCancelarCodigo(AuthCodigoCancelado event, Emitter<AuthState> emit) {
    _pendiente = null;
    emit(const AuthNoAutenticado());
  }

  Future<void> _completarAcceso(
    AccesoConcedido acceso,
    String email,
    String password,
    Emitter<AuthState> emit,
  ) async {
    _pendiente = null;

    /*
     * Solo entran pacientes. Los permisos llegan con el acceso —el mismo
     * perfil de sesión que devuelve `GET /auth/me`— y sin «mis citas» la
     * aplicación no tiene nada que enseñar: se descarta el token sin
     * guardar la sesión ni las credenciales, y se explica a dónde ir.
     */
    if (!acceso.usuario.esPaciente) {
      _fijarToken(null);
      emit(const AuthCuentaDelPersonal());
      return;
    }

    final segundos = acceso.expiraEnSegundos;
    final venceEn = segundos == null || segundos <= 0
        ? null
        : _reloj().add(Duration(seconds: segundos));

    await _almacen.guardar(
      SesionGuardada(
        token: acceso.token,
        venceEn: venceEn,
        usuario: acceso.usuario,
      ),
    );

    _fijarToken(acceso.token);

    // Las credenciales se guardan solo ahora, con el acceso ya concedido, y
    // solo si la persona no apagó la huella en su perfil.
    if (await _credenciales.biometriaActiva()) {
      await _credenciales.guardar(email: email, password: password);
    }

    emit(AuthAutenticado(acceso.usuario));
  }

  // ── Salir ──────────────────────────────────────────────────────────

  Future<void> _alSalir(
    AuthCierreSolicitado event,
    Emitter<AuthState> emit,
  ) async {
    await _olvidarSesion();

    // Las credenciales del acceso con huella se quedan: quien cierra sesión
    // vuelve, y para eso existe el atajo. «Entrar con otra cuenta», en el
    // acceso, es lo que las olvida.
    emit(const AuthNoAutenticado());
  }

  Future<void> _alVencer(
    AuthSesionVencida event,
    Emitter<AuthState> emit,
  ) async {
    // Solo con la sesión abierta: durante el acceso un 401 es otra cosa, y
    // durante la restauración lo atiende la propia restauración.
    if (state is! AuthAutenticado) return;

    await _olvidarSesion();
    emit(const AuthNoAutenticado(aviso: avisoSesionVencida));
  }

  Future<void> _olvidarSesion() async {
    _fijarToken(null);
    _pendiente = null;

    await _almacen.borrar();

    try {
      await _limpiarDatosLocales();
    } catch (error) {
      // Salir no puede fallar por una limpieza a medias.
      debugPrint('Cliniq · limpieza al salir incompleta: $error');
    }
  }

  // ── Perfil ─────────────────────────────────────────────────────────

  Future<void> _alRefrescarPerfil(
    AuthPerfilRefrescado event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! AuthAutenticado) return;

    try {
      final usuario = await _servicio.yo();
      await _almacen.actualizarUsuario(usuario);

      if (state is AuthAutenticado) emit(AuthAutenticado(usuario));
    } catch (error) {
      // Sin red el perfil guardado sigue valiendo; un 401 ya lo atiende el
      // aviso de sesión vencida.
      final actual = state;
      if (actual is AuthAutenticado && esFaltaDeRed(error)) {
        emit(AuthAutenticado(actual.usuario, sinConexion: true));
      }
    }
  }

  Future<void> _alActualizarPerfil(
    AuthPerfilActualizado event,
    Emitter<AuthState> emit,
  ) async {
    if (state is! AuthAutenticado) return;

    await _almacen.actualizarUsuario(event.usuario);
    emit(AuthAutenticado(event.usuario));
  }

  @override
  Future<void> close() async {
    await _escuchaDeVencimiento?.cancel();
    return super.close();
  }
}
