// lib/features/avisos/providers/avisos_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/avisos_service.dart';
import 'campana_cubit.dart';

class AvisosState extends Equatable {
  final List<Aviso> avisos;
  final bool cargando;
  final bool cargandoMas;
  final bool hayMas;

  /// Lo que se ve es la copia del teléfono.
  final bool desdeCache;

  /// Solo cuando no hay nada que enseñar.
  final String? error;

  const AvisosState({
    this.avisos = const [],
    this.cargando = true,
    this.cargandoMas = false,
    this.hayMas = false,
    this.desdeCache = false,
    this.error,
  });

  bool get hayNoLeidos => avisos.any((a) => !a.leida);

  AvisosState copiarCon({
    List<Aviso>? avisos,
    bool? cargando,
    bool? cargandoMas,
    bool? hayMas,
    bool? desdeCache,
    String? error,
    bool limpiarError = false,
  }) => AvisosState(
    avisos: avisos ?? this.avisos,
    cargando: cargando ?? this.cargando,
    cargandoMas: cargandoMas ?? this.cargandoMas,
    hayMas: hayMas ?? this.hayMas,
    desdeCache: desdeCache ?? this.desdeCache,
    error: limpiarError ? null : (error ?? this.error),
  );

  @override
  List<Object?> get props => [
    avisos,
    cargando,
    cargandoMas,
    hayMas,
    desdeCache,
    error,
  ];
}

/// La lista de avisos: leer, marcar, borrar.
///
/// Los cambios se ven al instante y se mandan después; si el servidor dice
/// que no, se deshacen y el contador de la [campana] se vuelve a pedir.
class AvisosCubit extends Cubit<AvisosState> {
  final AvisosService _servicio;
  final String uid;
  final CampanaCubit? campana;

  AvisosCubit(this._servicio, {required this.uid, this.campana})
    : super(const AvisosState());

  Future<void> cargar() async {
    emit(state.copiarCon(cargando: true, limpiarError: true));

    try {
      final pagina = await _servicio.listar(uid);
      if (isClosed) return;

      emit(
        AvisosState(
          avisos: pagina.avisos,
          cargando: false,
          hayMas: pagina.hayMas,
          desdeCache: pagina.desdeCache,
        ),
      );
    } catch (error) {
      if (isClosed) return;

      emit(
        state.copiarCon(
          cargando: false,
          error: state.avisos.isEmpty
              ? mensajeDeError(
                  error,
                  generico: 'No pudimos cargar tus avisos. Intenta de nuevo.',
                )
              : null,
        ),
      );
    }

    // Lo que se ve y la insignia, al día.
    await campana?.refrescar();
  }

  /// La página siguiente, desde el último que se ve.
  Future<void> cargarMas() async {
    if (state.cargandoMas || !state.hayMas || state.avisos.isEmpty) return;

    emit(state.copiarCon(cargandoMas: true));

    try {
      final pagina = await _servicio.listar(
        uid,
        antesDe: state.avisos.last.creadaEn,
      );
      if (isClosed) return;

      final vistos = {for (final a in state.avisos) a.id};

      emit(
        state.copiarCon(
          cargandoMas: false,
          hayMas: pagina.hayMas,
          avisos: [
            ...state.avisos,
            for (final a in pagina.avisos)
              if (!vistos.contains(a.id)) a,
          ],
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(state.copiarCon(cargandoMas: false, hayMas: false));
    }
  }

  /// Se abrió un aviso: queda leído.
  Future<void> marcarLeido(Aviso aviso) async {
    if (aviso.leida) return;

    _reemplazar([
      for (final a in state.avisos) a.id == aviso.id ? a.leido() : a,
    ]);
    campana?.descontar();

    try {
      await _servicio.marcarLeido(aviso.id);
    } catch (_) {
      await campana?.refrescar();
    }
  }

  /// «Marcar todas como leídas».
  Future<void> leerTodos() async {
    if (!state.hayNoLeidos) return;

    final antes = state.avisos;
    _reemplazar([for (final a in antes) a.leido()]);
    campana?.ponerEnCero();

    try {
      await _servicio.leerTodos();
    } catch (_) {
      if (!isClosed) _reemplazar(antes);
      await campana?.refrescar();
    }
  }

  /// Borra un aviso (deslizándolo). Si el servidor no lo borra, vuelve a su
  /// lugar y devuelve `false`.
  Future<bool> eliminar(Aviso aviso) async {
    final antes = state.avisos;
    _reemplazar([
      for (final a in antes)
        if (a.id != aviso.id) a,
    ]);
    if (!aviso.leida) campana?.descontar();

    try {
      await _servicio.eliminar(aviso.id);
      return true;
    } catch (_) {
      if (!isClosed) _reemplazar(antes);
      await campana?.refrescar();
      return false;
    }
  }

  void _reemplazar(List<Aviso> avisos) {
    if (isClosed) return;

    emit(state.copiarCon(avisos: avisos));
    _servicio.guardarCopia(uid, avisos).ignore();
  }
}
