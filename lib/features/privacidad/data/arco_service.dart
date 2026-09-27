// lib/features/privacidad/data/arco_service.dart

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../core/fechas/instante.dart';
import '../../../core/storage/cache_local.dart';

/// Un paso del historial de una solicitud: quién la movió, a qué estado y con
/// qué nota.
class PasoArco extends Equatable {
  final DateTime fecha;
  final String estado;
  final String porNombre;
  final String? nota;

  const PasoArco({
    required this.fecha,
    required this.estado,
    this.porNombre = '',
    this.nota,
  });

  static PasoArco? desdeJson(Object? json) {
    if (json is! Map) return null;

    final fecha = leerInstante(json['fecha']);
    final estado = json['estado']?.toString().trim().toUpperCase() ?? '';
    if (fecha == null || estado.isEmpty) return null;

    final nota = json['nota']?.toString().trim() ?? '';

    return PasoArco(
      fecha: fecha,
      estado: estado,
      porNombre: json['porNombre']?.toString().trim() ?? '',
      nota: nota.isEmpty ? null : nota,
    );
  }

  Map<String, dynamic> aJson() => {
    'fecha': aTextoInstante(fecha),
    'estado': estado,
    'porNombre': porNombre,
    'nota': ?nota,
  };

  @override
  List<Object?> get props => [fecha, estado, porNombre, nota];
}

/// Una solicitud de derechos ARCO (LOPDP) de quien entró.
class SolicitudArco extends Equatable {
  final String id;

  /// `ACCESO`, `RECTIFICACION`…: el nombre sale del catálogo `TIPO_ARCO`.
  final String tipo;

  final String detalle;

  /// `RECIBIDA`, `EN_PROCESO`, `RESUELTA`, `RECHAZADA`: la etiqueta, el color
  /// y el icono salen del catálogo `ESTADO_ARCO`.
  final String estado;

  /// La última respuesta de la clínica, si hay.
  final String? respuesta;

  /// Instantes reales.
  final DateTime creadaEn;
  final DateTime plazoVence;

  /// Sigue abierta y ya pasó el plazo (lo calcula el servidor).
  final bool vencida;

  final List<PasoArco> historial;

  const SolicitudArco({
    required this.id,
    required this.tipo,
    required this.detalle,
    required this.estado,
    required this.creadaEn,
    required this.plazoVence,
    this.respuesta,
    this.vencida = false,
    this.historial = const [],
  });

  static SolicitudArco? desdeJson(Object? json) {
    if (json is! Map) return null;

    String texto(String campo) => json[campo]?.toString().trim() ?? '';

    final id = texto('_id');
    final creadaEn = leerInstante(json['creadaEn']);
    final plazoVence = leerInstante(json['plazoVence']);
    if (id.isEmpty || creadaEn == null || plazoVence == null) return null;

    final respuesta = texto('respuesta');

    return SolicitudArco(
      id: id,
      tipo: texto('tipo').toUpperCase(),
      detalle: texto('detalle'),
      estado: texto('estado').toUpperCase(),
      respuesta: respuesta.isEmpty ? null : respuesta,
      creadaEn: creadaEn,
      plazoVence: plazoVence,
      vencida: json['vencida'] == true,
      historial: [
        for (final p in (json['historial'] as List?) ?? const [])
          ?PasoArco.desdeJson(p),
      ],
    );
  }

  Map<String, dynamic> aJson() => {
    '_id': id,
    'tipo': tipo,
    'detalle': detalle,
    'estado': estado,
    'respuesta': ?respuesta,
    'creadaEn': aTextoInstante(creadaEn),
    'plazoVence': aTextoInstante(plazoVence),
    'vencida': vencida,
    'historial': [for (final p in historial) p.aJson()],
  };

  @override
  List<Object?> get props => [
    id,
    tipo,
    detalle,
    estado,
    respuesta,
    creadaEn,
    plazoVence,
    vencida,
    historial,
  ];
}

/// Las solicitudes y de dónde salieron.
class SolicitudesArco {
  final List<SolicitudArco> solicitudes;
  final bool desdeCache;

  const SolicitudesArco({required this.solicitudes, this.desdeCache = false});
}

/// `/portal/arco`: las solicitudes de derechos sobre los datos personales de
/// quien entró (el servidor toma la persona de la sesión).
///
/// La lista se guarda por persona (`arco:<uid>`, se borra al cerrar sesión)
/// para verla sin red; sin red y sin copia, el error.
class ArcoService {
  static const String ruta = '/portal/arco';

  final Dio _dio;
  final CacheLocal _cache;

  ArcoService(this._dio, this._cache);

  static String claveCache(String uid) => 'arco:$uid';

  /// `GET /portal/arco`: las mías, la más reciente primero.
  Future<SolicitudesArco> mias(String uid) async {
    try {
      final respuesta = await _dio.get<dynamic>(ruta);

      final datos = respuesta.data;
      if (datos is! List) {
        throw const FormatException('Las solicitudes ARCO no son una lista');
      }

      final solicitudes = [for (final d in datos) ?SolicitudArco.desdeJson(d)];
      await guardarCopia(uid, solicitudes);

      return SolicitudesArco(solicitudes: solicitudes);
    } catch (_) {
      final copia = await _leer(uid);
      if (copia != null) {
        return SolicitudesArco(solicitudes: copia, desdeCache: true);
      }

      rethrow;
    }
  }

  /// `POST /portal/arco {tipo, detalle}`: la solicitud nueva, ya con su
  /// plazo.
  Future<SolicitudArco> crear({
    required String tipo,
    required String detalle,
  }) async {
    final respuesta = await _dio.post<dynamic>(
      ruta,
      data: {'tipo': tipo, 'detalle': detalle},
    );

    final creada = SolicitudArco.desdeJson(respuesta.data);
    if (creada == null) {
      throw const FormatException('La respuesta no trae la solicitud');
    }

    return creada;
  }

  Future<void> guardarCopia(String uid, List<SolicitudArco> solicitudes) =>
      _cache.guardar(claveCache(uid), [for (final s in solicitudes) s.aJson()]);

  Future<List<SolicitudArco>?> _leer(String uid) async {
    try {
      final datos = await _cache.leer(claveCache(uid));
      if (datos is! List) return null;

      return [for (final d in datos) ?SolicitudArco.desdeJson(d)];
    } catch (_) {
      return null;
    }
  }
}
