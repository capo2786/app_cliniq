import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'catalogo_service.dart';

/// Lo que se dice cuando falta un catálogo y no hay copia guardada.
const String mensajeSinCatalogos =
    'No pudimos cargar las listas de la clínica. Revisa tu conexión e '
    'intenta de nuevo.';

/// Los catálogos ya cargados, para cualquier pantalla que los necesite.
class CatalogosState extends Equatable {
  final Map<String, List<ItemCatalogo>> listas;

  /// Ya terminó al menos una carga (buena o mala).
  final bool cargados;

  final bool cargando;

  /// Los catálogos que no se pudieron cargar ni tenían copia guardada.
  final Set<String> faltantes;

  const CatalogosState({
    this.listas = const {},
    this.cargados = false,
    this.cargando = false,
    this.faltantes = const {},
  });

  /// Están todos los que la aplicación usa, del servidor o de la copia.
  bool get completos =>
      cargados && Catalogos.todos.every((c) => listas.containsKey(c));

  /// El mensaje para la pantalla cuando falta alguno.
  String? get error => cargados && !completos ? mensajeSinCatalogos : null;

  /// Si se tiene este catálogo (aunque esté vacío).
  bool tiene(String clave) => listas.containsKey(clave);

  /// Los elementos de un catálogo, en el orden del panel.
  List<ItemCatalogo> items(String clave) => listas[clave] ?? const [];

  List<String> nombres(String clave) => [
    for (final i in items(clave)) i.nombre,
  ];

  /// El elemento con ese código, o `null`.
  ItemCatalogo? porCodigo(String clave, String? codigo) {
    final buscado = codigo?.trim().toUpperCase();
    if (buscado == null || buscado.isEmpty) return null;

    for (final item in items(clave)) {
      if (item.codigo.toUpperCase() == buscado) return item;
    }
    return null;
  }

  /// La etiqueta de un código (`F` → «Femenino»), o `null` si el catálogo no
  /// lo tiene.
  String? nombreDe(String clave, String? codigo) =>
      porCodigo(clave, codigo)?.nombre;

  /// Los códigos del sistema que se ofrecen como opción en un formulario: los
  /// que el catálogo trae activos, en su orden. Si el catálogo no trae
  /// ninguno de ellos, todos los del sistema, en el orden de [delSistema]:
  /// el formulario sigue funcionando (y se enseña el código tal cual), como
  /// hace el panel.
  List<String> codigosOfrecidos(String clave, List<String> delSistema) {
    final activos = <String>[];

    for (final item in items(clave)) {
      final codigo = item.codigo.toUpperCase();
      if (delSistema.contains(codigo) && !activos.contains(codigo)) {
        activos.add(codigo);
      }
    }

    return activos.isEmpty ? [...delSistema] : activos;
  }

  /// El elemento marcado como predeterminado por el administrador.
  ItemCatalogo? porDefecto(String clave) {
    for (final item in items(clave)) {
      if (item.esPorDefecto) return item;
    }
    return null;
  }

  List<String> get motivosCancelacion =>
      nombres(Catalogos.motivoCancelacionPaciente);

  List<String> get especialidades => nombres(Catalogos.especialidad);

  List<String> get parentescosDependiente =>
      nombres(Catalogos.parentescoDependiente);

  List<String> get parentescos => nombres(Catalogos.parentesco);

  List<String> get ciudades => nombres(Catalogos.ciudad);

  @override
  List<Object?> get props => [listas, cargados, cargando, faltantes];
}

/// Carga todos los catálogos de una vez: al abrir la aplicación —antes de
/// entrar, porque son públicos— y cada vez que vuelve al frente.
///
/// Lo que el servidor responde reemplaza lo anterior; lo que no se pudo
/// traer se queda como estaba (en memoria o en la copia guardada). Si falta
/// alguno sin copia, [CatalogosState.error] lo dice y la pantalla ofrece
/// «Reintentar»: no hay listas de respaldo.
class CatalogosCubit extends Cubit<CatalogosState> {
  final CatalogoService _servicio;

  Future<void>? _enCurso;

  /// Con [inicial] arranca ya con catálogos (las pruebas de una pantalla
  /// suelta, que no pasan por la carga).
  CatalogosCubit(this._servicio, {CatalogosState? inicial})
    : super(inicial ?? const CatalogosState());

  Future<void> cargar() => _enCurso ??= _cargar().whenComplete(() {
    _enCurso = null;
  });

  Future<void> _cargar() async {
    emit(
      CatalogosState(
        listas: state.listas,
        cargados: state.cargados,
        cargando: true,
        faltantes: state.faltantes,
      ),
    );

    final cargados = await _servicio.cargar();
    if (isClosed) return;

    final listas = {...state.listas, ...cargados.listas};

    emit(
      CatalogosState(
        listas: listas,
        cargados: true,
        faltantes: {
          for (final clave in cargados.faltantes)
            if (!listas.containsKey(clave)) clave,
        },
      ),
    );
  }
}
