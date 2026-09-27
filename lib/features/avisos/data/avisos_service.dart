// lib/features/avisos/data/avisos_service.dart

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../core/fechas/instante.dart';
import '../../../core/storage/cache_local.dart';

/// Un aviso de la campana (`Notificacion` de la API): «tu cita fue
/// reprogramada», «soporte respondió», «recibimos tu solicitud ARCO».
class Aviso extends Equatable {
  final String id;

  /// `CITA_CREADA`, `ARCO`, `ENCUESTA`…: decide el icono.
  final String tipo;

  final String titulo;
  final String mensaje;

  /// Ruta interna a la que lleva (`/mis-citas`), o `null`. La API solo guarda
  /// rutas que empiezan con `/`; puede ser una que la aplicación no abre
  /// (`/admin/...`).
  final String? enlace;

  final bool leida;

  /// Un instante real (UTC).
  final DateTime creadaEn;

  const Aviso({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.mensaje,
    required this.leida,
    required this.creadaEn,
    this.enlace,
  });

  static Aviso? desdeJson(Object? json) {
    if (json is! Map) return null;

    String texto(String campo) => json[campo]?.toString().trim() ?? '';

    final id = texto('_id');
    final creadaEn = leerInstante(json['creadaEn']);
    if (id.isEmpty || creadaEn == null) return null;

    final enlace = texto('enlace');

    return Aviso(
      id: id,
      tipo: texto('tipo').toUpperCase(),
      titulo: texto('titulo'),
      mensaje: texto('mensaje'),
      enlace: enlace.isEmpty ? null : enlace,
      leida: json['leida'] == true,
      creadaEn: creadaEn,
    );
  }

  Map<String, dynamic> aJson() => {
    '_id': id,
    'tipo': tipo,
    'titulo': titulo,
    'mensaje': mensaje,
    'enlace': ?enlace,
    'leida': leida,
    'creadaEn': aTextoInstante(creadaEn),
  };

  Aviso leido() => Aviso(
    id: id,
    tipo: tipo,
    titulo: titulo,
    mensaje: mensaje,
    enlace: enlace,
    leida: true,
    creadaEn: creadaEn,
  );

  @override
  List<Object?> get props => [
    id,
    tipo,
    titulo,
    mensaje,
    enlace,
    leida,
    creadaEn,
  ];
}

/// Una página de la lista, y de dónde salió.
class PaginaDeAvisos {
  final List<Aviso> avisos;
  final bool hayMas;

  /// Salió de la copia del teléfono: el servidor no respondió.
  final bool desdeCache;

  const PaginaDeAvisos({
    required this.avisos,
    required this.hayMas,
    this.desdeCache = false,
  });
}

/// El centro de avisos de la API (`/notificaciones`), siempre sobre los de
/// quien entró: el servidor toma la persona de la sesión.
///
/// La primera página se guarda por persona (`avisos:<uid>`, se borra al
/// cerrar sesión) para verla sin red; sin red y sin copia, el error.
class AvisosService {
  static const String ruta = '/notificaciones';

  /// Los mismos que pide el panel en cada página.
  static const int porPagina = 20;

  final Dio _dio;
  final CacheLocal _cache;

  AvisosService(this._dio, this._cache);

  static String claveCache(String uid) => 'avisos:$uid';

  /// `GET /notificaciones?limite=20[&antesDe=…]` → `{items, hayMas}`, los
  /// más nuevos primero. Con [antesDe] (el `creadaEn` del último que se
  /// tiene), la página siguiente.
  Future<PaginaDeAvisos> listar(String uid, {DateTime? antesDe}) async {
    try {
      final respuesta = await _dio.get<dynamic>(
        ruta,
        queryParameters: {
          'limite': porPagina,
          if (antesDe != null) 'antesDe': aTextoInstante(antesDe),
        },
      );

      final datos = respuesta.data;
      if (datos is! Map || datos['items'] is! List) {
        throw const FormatException('La lista de avisos no tiene su forma');
      }

      final pagina = PaginaDeAvisos(
        avisos: [for (final a in datos['items'] as List) ?Aviso.desdeJson(a)],
        hayMas: datos['hayMas'] == true,
      );

      if (antesDe == null) await guardarCopia(uid, pagina.avisos);

      return pagina;
    } catch (_) {
      if (antesDe != null) rethrow;

      final copia = await _leer(uid);
      if (copia != null) {
        return PaginaDeAvisos(avisos: copia, hayMas: false, desdeCache: true);
      }

      rethrow;
    }
  }

  /// `GET /notificaciones/no-leidas/contador` → `{total}`.
  Future<int> contarNoLeidas() async {
    final respuesta = await _dio.get<dynamic>('$ruta/no-leidas/contador');
    final total = respuesta.data is Map ? respuesta.data['total'] : null;

    if (total is! num) {
      throw const FormatException('El contador de avisos no es un número');
    }

    return total < 0 ? 0 : total.floor();
  }

  /// `PATCH /notificaciones/:id/leida`.
  Future<void> marcarLeido(String id) =>
      _dio.patch<dynamic>('$ruta/${Uri.encodeComponent(id)}/leida');

  /// `PATCH /notificaciones/leer-todas`.
  Future<void> leerTodos() => _dio.patch<dynamic>('$ruta/leer-todas');

  /// `DELETE /notificaciones/:id`.
  Future<void> eliminar(String id) =>
      _dio.delete<dynamic>('$ruta/${Uri.encodeComponent(id)}');

  /// Deja la copia como se ve la lista ahora (tras marcar o borrar).
  Future<void> guardarCopia(String uid, List<Aviso> avisos) => _cache.guardar(
    claveCache(uid),
    [for (final a in avisos.take(porPagina)) a.aJson()],
  );

  Future<List<Aviso>?> _leer(String uid) async {
    try {
      final datos = await _cache.leer(claveCache(uid));
      if (datos is! List) return null;

      return [for (final d in datos) ?Aviso.desdeJson(d)];
    } catch (_) {
      return null;
    }
  }
}
