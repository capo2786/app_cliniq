// lib/features/ayuda/providers/ayuda_cubit.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/errores.dart';
import '../data/ayuda_service.dart';
import '../data/models/articulo_ayuda.dart';
import '../dominio/busqueda_ayuda.dart';

enum CargaAyuda { inicial, cargando, lista, error }

class AyudaState extends Equatable {
  final CargaAyuda carga;
  final List<ArticuloAyuda> articulos;

  /// Lo que se buscó (ya sin espacios de más); vacío, todo.
  final String busqueda;

  /// La categoría elegida; vacía, todas.
  final String categoria;

  final bool desdeCache;
  final DateTime? guardadaEn;
  final String? error;

  const AyudaState({
    this.carga = CargaAyuda.inicial,
    this.articulos = const [],
    this.busqueda = '',
    this.categoria = '',
    this.desdeCache = false,
    this.guardadaEn,
    this.error,
  });

  /// Todos los artículos, por categoría.
  List<GrupoDeArticulos> get grupos => agruparArticulos(articulos);

  /// Los de la categoría elegida (o todos).
  List<GrupoDeArticulos> get visibles => categoria.isEmpty
      ? grupos
      : grupos.where((g) => g.categoria == categoria).toList();

  AyudaState copiarCon({
    CargaAyuda? carga,
    List<ArticuloAyuda>? articulos,
    String? busqueda,
    String? categoria,
    bool? desdeCache,
    DateTime? guardadaEn,
    String? error,
    bool limpiarError = false,
  }) {
    return AyudaState(
      carga: carga ?? this.carga,
      articulos: articulos ?? this.articulos,
      busqueda: busqueda ?? this.busqueda,
      categoria: categoria ?? this.categoria,
      desdeCache: desdeCache ?? this.desdeCache,
      guardadaEn: guardadaEn ?? this.guardadaEn,
      error: limpiarError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    carga,
    articulos,
    busqueda,
    categoria,
    desdeCache,
    guardadaEn,
    error,
  ];
}

/// El centro de ayuda: buscar y elegir una categoría.
///
/// Cada búsqueda la hace el servidor; si se escribe rápido, la respuesta de
/// una búsqueda vieja que llega tarde se descarta. Si la categoría elegida
/// no tiene resultados en la búsqueda nueva, se vuelve a «Todas».
class AyudaCubit extends Cubit<AyudaState> {
  final AyudaService _servicio;
  final String _uid;

  int _secuencia = 0;

  AyudaCubit({required this._servicio, required this._uid})
    : super(const AyudaState());

  Future<void> buscar([String q = '']) async {
    final secuencia = ++_secuencia;
    final texto = q.trim();

    emit(
      state.copiarCon(
        carga: CargaAyuda.cargando,
        busqueda: texto,
        limpiarError: true,
      ),
    );

    try {
      final resultado = await _servicio.buscar(_uid, q: texto);
      if (secuencia != _secuencia || isClosed) return;

      final sigue = resultado.articulos.any((a) => a.grupo == state.categoria);

      emit(
        state.copiarCon(
          carga: CargaAyuda.lista,
          articulos: resultado.articulos,
          categoria: sigue ? state.categoria : '',
          desdeCache: resultado.desdeCache,
          guardadaEn: resultado.guardadaEn,
        ),
      );
    } catch (error) {
      if (secuencia != _secuencia || isClosed) return;

      emit(
        state.copiarCon(
          carga: CargaAyuda.error,
          articulos: const [],
          error: mensajeDeError(
            error,
            generico: 'No pudimos cargar la ayuda. Intenta de nuevo.',
          ),
        ),
      );
    }
  }

  /// Vuelve a pedir lo último que se buscó.
  Future<void> reintentar() => buscar(state.busqueda);

  void elegirCategoria(String categoria) =>
      emit(state.copiarCon(categoria: categoria));
}
