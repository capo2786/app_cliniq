import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'catalogo_service.dart';

/// Los catálogos ya cargados, para cualquier pantalla que los necesite.
class CatalogosState extends Equatable {
  final Map<String, List<String>> listas;
  final bool cargados;

  const CatalogosState({this.listas = const {}, this.cargados = false});

  List<String> _de(String clave) =>
      listas[clave] ?? catalogosDePartida[clave] ?? const [];

  List<String> get motivosCancelacion => _de(Catalogos.motivoCancelacion);

  List<String> get especialidades => _de(Catalogos.especialidad);

  List<String> get parentescos => _de(Catalogos.parentesco);

  @override
  List<Object?> get props => [listas, cargados];
}

/// Carga los tres catálogos de una vez al entrar.
///
/// Nunca falla: sin red devuelve lo guardado o los valores de partida, así
/// que una pantalla que los pide siempre tiene opciones que ofrecer.
class CatalogosCubit extends Cubit<CatalogosState> {
  final CatalogoService _servicio;

  CatalogosCubit(this._servicio) : super(const CatalogosState());

  Future<void> cargar() async {
    final listas = await _servicio.cargar();

    if (!isClosed) emit(CatalogosState(listas: listas, cargados: true));
  }
}
