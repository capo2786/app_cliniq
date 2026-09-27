// lib/features/navegacion/data/menu_service.dart

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../core/storage/cache_local.dart';

/// Un enlace del menú que el administrador arma en el panel
/// (`MenuItem` de tipo `LINK` o `EXTERNO` marcado para la aplicación).
class EnlaceMenu extends Equatable {
  final String key;
  final String label;

  /// Nombre del icono en el juego del panel (`home`, `calendario-mas`…).
  final String icon;

  /// Ruta del panel (`/mis-citas`) o, si es `EXTERNO`, una dirección.
  final String route;

  /// `LINK` o `EXTERNO`.
  final String tipo;

  /// `#RRGGBB` o vacío.
  final String color;

  final int orden;

  const EnlaceMenu({
    required this.key,
    required this.label,
    required this.route,
    this.icon = '',
    this.tipo = 'LINK',
    this.color = '',
    this.orden = 0,
  });

  bool get externo => tipo == 'EXTERNO';

  static EnlaceMenu? desdeJson(Object? json) {
    if (json is! Map) return null;

    String texto(String campo) => json[campo]?.toString().trim() ?? '';

    final tipo = texto('tipo').toUpperCase();
    final label = texto('label');
    final route = texto('route');
    if ((tipo != 'LINK' && tipo != 'EXTERNO') || label.isEmpty) return null;
    if (route.isEmpty) return null;

    final orden = json['orden'];

    return EnlaceMenu(
      key: texto('key'),
      label: label,
      icon: texto('icon'),
      route: route,
      tipo: tipo,
      color: texto('color'),
      orden: orden is num ? orden.toInt() : int.tryParse('$orden') ?? 0,
    );
  }

  Map<String, dynamic> aJson() => {
    'key': key,
    'label': label,
    'icon': icon,
    'route': route,
    'tipo': tipo,
    'color': color,
    'orden': orden,
  };

  @override
  List<Object?> get props => [key, label, icon, route, tipo, color, orden];
}

/// Los enlaces de un menú en el orden en que se ven: los grupos por su
/// orden y, dentro de cada grupo, sus enlaces por el suyo (como los arma el
/// panel). Los grupos no son enlaces: se aplanan.
List<EnlaceMenu> enlacesDelMenu(Object? datos) {
  if (datos is! List) return const [];

  int ordenDe(Object? nodo) {
    final orden = nodo is Map ? nodo['orden'] : null;
    return orden is num ? orden.toInt() : 0;
  }

  List<Object?> ordenados(List<Object?> nodos) =>
      [...nodos]..sort((a, b) => ordenDe(a).compareTo(ordenDe(b)));

  final enlaces = <EnlaceMenu>[];

  for (final nodo in ordenados(datos)) {
    if (nodo is! Map) continue;

    if (nodo['tipo']?.toString().toUpperCase() == 'GRUPO') {
      final hijos = nodo['children'];
      if (hijos is! List) continue;

      for (final hijo in ordenados(hijos)) {
        final enlace = EnlaceMenu.desdeJson(hijo);
        if (enlace != null) enlaces.add(enlace);
      }
      continue;
    }

    final enlace = EnlaceMenu.desdeJson(nodo);
    if (enlace != null) enlaces.add(enlace);
  }

  return enlaces;
}

/// El menú ya cargado y de dónde salió.
class MenuCargado {
  final List<EnlaceMenu> enlaces;
  final bool desdeCache;

  const MenuCargado({required this.enlaces, required this.desdeCache});
}

/// No hay menú: ni respuesta del servidor ni copia guardada.
class MenuNoDisponible implements Exception {
  final Object? causa;

  const MenuNoDisponible([this.causa]);

  @override
  String toString() => 'MenuNoDisponible($causa)';
}

/// `GET /menus/mi-menu?plataforma=APP`: el menú de la aplicación, filtrado
/// por los permisos de quien entró.
///
/// Se guarda por persona (`menu:<uid>`): depende de sus permisos, así que se
/// borra al cerrar sesión. Sin red se usa la última copia; sin copia,
/// [MenuNoDisponible]. La aplicación no trae un menú de respaldo.
class MenuService {
  static const String ruta = '/menus/mi-menu';
  static const String plataforma = 'APP';

  final Dio _dio;
  final CacheLocal _cache;

  MenuService(this._dio, this._cache);

  static String claveCache(String uid) => 'menu:$uid';

  Future<MenuCargado> cargar(String uid) async {
    try {
      final respuesta = await _dio.get<dynamic>(
        ruta,
        queryParameters: {'plataforma': plataforma},
      );

      final datos = respuesta.data;
      if (datos is! List) {
        throw const FormatException('El menú no es una lista');
      }

      final enlaces = enlacesDelMenu(datos);
      await _cache.guardar(claveCache(uid), [
        for (final e in enlaces) e.aJson(),
      ]);

      return MenuCargado(enlaces: enlaces, desdeCache: false);
    } catch (error) {
      final copia = await _leer(uid);
      if (copia != null) return MenuCargado(enlaces: copia, desdeCache: true);

      throw MenuNoDisponible(error);
    }
  }

  Future<List<EnlaceMenu>?> _leer(String uid) async {
    try {
      final datos = await _cache.leer(claveCache(uid));
      if (datos is! List) return null;

      return [for (final d in datos) ?EnlaceMenu.desdeJson(d)];
    } catch (_) {
      return null;
    }
  }
}
