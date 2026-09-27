// lib/core/configuracion/config_publica_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'config_publica.dart';
import 'config_publica_service.dart';

/// Lo que se dice cuando no hay configuración ni copia guardada.
const String mensajeSinConfiguracion =
    'No pudimos cargar los datos de la clínica. Revisa tu conexión e intenta '
    'de nuevo.';

/// La configuración de la clínica para toda la aplicación.
class ConfigPublicaState extends Equatable {
  /// La configuración vigente, o `null` si todavía no hay ninguna.
  final ConfigPublica? config;

  final bool cargando;

  /// Se usa la copia del teléfono porque el servidor no respondió.
  final bool desdeCache;

  /// Por qué no hay configuración. Solo cuando [config] es `null`: con una
  /// copia guardada no hay nada que decir.
  final String? error;

  const ConfigPublicaState({
    this.config,
    this.cargando = false,
    this.desdeCache = false,
    this.error,
  });

  bool get lista => config != null;

  @override
  List<Object?> get props => [config, cargando, desdeCache, error];
}

/// Carga la configuración pública al abrir la aplicación y la refresca cada
/// vez que la aplicación vuelve al frente: si el administrador cambió las
/// horas para reprogramar, la aplicación lo sabe la próxima vez que se abre.
///
/// Primero enseña la copia guardada —abrir con la configuración de ayer es
/// mejor que abrir con una rueda— y luego la reemplaza por la del servidor.
/// Sin red y sin copia queda en error, con su mensaje, para que la pantalla
/// ofrezca «Reintentar»: nunca se arranca con valores inventados.
class ConfigPublicaCubit extends Cubit<ConfigPublicaState> {
  final ConfigPublicaService _servicio;

  /// Se llama con cada configuración que entra en uso (la zona horaria, por
  /// ejemplo, se aplica aquí).
  final void Function(ConfigPublica config)? _alAplicar;

  Future<void>? _enCurso;

  /// Con [inicial] arranca ya con una configuración (las pruebas de una
  /// pantalla suelta, que no pasan por la carga).
  ConfigPublicaCubit(this._servicio, {this._alAplicar, ConfigPublica? inicial})
    : super(ConfigPublicaState(config: inicial)) {
    if (inicial != null) _alAplicar?.call(inicial);
  }

  /// La configuración vigente. Solo se puede pedir con la configuración ya
  /// cargada (la aplicación espera a tenerla antes de enseñar nada).
  ConfigPublica get config {
    final config = state.config;
    if (config == null) {
      throw StateError('La configuración pública todavía no se cargó');
    }
    return config;
  }

  /// Carga (o refresca) la configuración. Dos llamadas seguidas comparten la
  /// misma petición.
  Future<void> cargar() => _enCurso ??= _cargar().whenComplete(() {
    _enCurso = null;
  });

  Future<void> _cargar() async {
    if (state.config == null) {
      final guardada = await _servicio.guardada();
      if (guardada != null) _emitirConfig(guardada);
    }

    if (isClosed) return;
    emit(
      ConfigPublicaState(
        config: state.config,
        cargando: true,
        desdeCache: state.desdeCache,
      ),
    );

    try {
      _emitirConfig(await _servicio.descargar());
    } catch (_) {
      if (isClosed) return;

      emit(
        ConfigPublicaState(
          config: state.config,
          desdeCache: state.config != null,
          error: state.config != null ? null : mensajeSinConfiguracion,
        ),
      );
    }
  }

  void _emitirConfig(ConfigPublicaCargada cargada) {
    if (isClosed) return;

    _alAplicar?.call(cargada.config);
    emit(
      ConfigPublicaState(
        config: cargada.config,
        desdeCache: cargada.desdeCache,
      ),
    );
  }
}
