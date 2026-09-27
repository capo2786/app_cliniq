// lib/core/configuracion/en_contexto.dart

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../catalogos/catalogos_cubit.dart';
import 'config_publica.dart';
import 'config_publica_cubit.dart';

/// La configuración y los catálogos de la clínica desde cualquier pantalla.
///
/// La aplicación no enseña ninguna pantalla con datos antes de tener las dos
/// cosas (ver `EsperaDatosDeLaClinica`), así que dentro de una pantalla
/// siempre están. [config] y [catalogos] escuchan los cambios —úsalos en
/// `build`—; en un botón, `context.read<ConfigPublicaCubit>().config`.
extension DatosDeLaClinicaEnContexto on BuildContext {
  /// La configuración vigente. Reconstruye el widget si cambia.
  ConfigPublica get config => watch<ConfigPublicaCubit>().config;

  /// Los catálogos. Reconstruye el widget si cambian.
  CatalogosState get catalogos => watch<CatalogosCubit>().state;

  /// La configuración si ya se cargó y si hay quien la dé, sin escuchar.
  /// Para lo que se pinta también fuera de la aplicación normal (la pantalla
  /// de fallo) o antes de tener configuración (el arranque).
  ConfigPublica? get configSiHay {
    try {
      return read<ConfigPublicaCubit>().state.config;
    } catch (_) {
      return null;
    }
  }
}
