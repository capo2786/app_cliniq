// lib/features/navegacion/providers/menu_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/menu_service.dart';

/// Lo que se dice cuando no hay menú ni copia guardada.
const String mensajeSinMenu =
    'No pudimos cargar el menú de la clínica. Revisa tu conexión e intenta '
    'de nuevo.';

class MenuState extends Equatable {
  /// `null` mientras no hay menú (ni del servidor ni guardado).
  final List<EnlaceMenu>? enlaces;
  final bool cargando;
  final bool desdeCache;

  /// Solo cuando no hay menú.
  final String? error;

  const MenuState({
    this.enlaces,
    this.cargando = false,
    this.desdeCache = false,
    this.error,
  });

  @override
  List<Object?> get props => [enlaces, cargando, desdeCache, error];
}

/// El menú de la aplicación de quien entró: la barra de abajo y los accesos
/// rápidos. Se pide al entrar y al volver al frente; se olvida al salir.
class MenuCubit extends Cubit<MenuState> {
  final MenuService _servicio;

  String? _uid;

  MenuCubit(this._servicio) : super(const MenuState());

  Future<void> cargar(String uid) async {
    if (_uid != uid) {
      _uid = uid;
      emit(const MenuState());
    }

    emit(
      MenuState(
        enlaces: state.enlaces,
        cargando: true,
        desdeCache: state.desdeCache,
      ),
    );

    try {
      final menu = await _servicio.cargar(uid);
      if (isClosed || _uid != uid) return;

      emit(MenuState(enlaces: menu.enlaces, desdeCache: menu.desdeCache));
    } catch (_) {
      if (isClosed || _uid != uid) return;

      emit(
        MenuState(
          enlaces: state.enlaces,
          desdeCache: state.enlaces != null,
          error: state.enlaces == null ? mensajeSinMenu : null,
        ),
      );
    }
  }

  /// Se cerró la sesión.
  void vaciar() {
    _uid = null;
    emit(const MenuState());
  }
}
