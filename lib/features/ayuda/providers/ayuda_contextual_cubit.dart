// lib/features/ayuda/providers/ayuda_contextual_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/ayuda_contextual_service.dart';
import '../data/models/ayuda_de_accion.dart';

class AyudaContextualState extends Equatable {
  /// De quién son los textos (el servidor los filtra por sus roles).
  final String uid;

  /// Clave → texto. Sin una clave, su botón no se enseña.
  final Map<String, AyudaDeAccion> mapa;

  /// Ya respondió el servidor en esta sesión (si no, es la copia guardada o
  /// nada).
  final bool alDia;

  const AyudaContextualState({
    this.uid = '',
    this.mapa = const {},
    this.alDia = false,
  });

  /// El texto de [clave], o `null`.
  AyudaDeAccion? de(String clave) => mapa[clave];

  @override
  List<Object?> get props => [uid, mapa, alDia];
}

/// Los textos de los botones de ayuda de quien entró, cargados **una vez**
/// por sesión: primero la copia guardada (los «?» aparecen desde el primer
/// cuadro, también sin red) y después la del servidor, que la reemplaza.
///
/// Si el servidor no responde, se queda la copia y se vuelve a intentar la
/// próxima vez que se pida (al volver a la aplicación). Al cerrar sesión se
/// vacía: los textos dependen de los roles de cada persona.
class AyudaContextualCubit extends Cubit<AyudaContextualState> {
  final AyudaContextualService _servicio;

  Future<void>? _carga;
  String? _uidDeLaCarga;

  AyudaContextualCubit(
    this._servicio, {
    AyudaContextualState inicial = const AyudaContextualState(),
  }) : super(inicial);

  /// Carga los textos de [uid], si no se cargaron ya en esta sesión.
  Future<void> cargar(String uid) {
    if (uid.isEmpty) return Future.value();
    if (_uidDeLaCarga == uid && _carga != null) return _carga!;

    _uidDeLaCarga = uid;
    return _carga = _cargar(uid);
  }

  Future<void> _cargar(String uid) async {
    if (state.uid != uid) emit(AyudaContextualState(uid: uid));

    final copia = await _servicio.guardada(uid);
    if (!_sigue(uid)) return;
    if (copia != null && !state.alDia) {
      emit(AyudaContextualState(uid: uid, mapa: copia));
    }

    try {
      final mapa = await _servicio.pedir(uid);
      if (!_sigue(uid)) return;

      emit(AyudaContextualState(uid: uid, mapa: mapa, alDia: true));
    } catch (error) {
      debugPrint('Cliniq · no se pudo cargar la ayuda contextual: $error');
      // Se queda la copia; la próxima vez que se pida, se reintenta.
      if (_sigue(uid)) _carga = null;
    }
  }

  bool _sigue(String uid) => !isClosed && _uidDeLaCarga == uid;

  /// Al cerrar sesión: los textos de la persona anterior no se enseñan.
  void vaciar() {
    _carga = null;
    _uidDeLaCarga = null;
    emit(const AyudaContextualState());
  }
}
