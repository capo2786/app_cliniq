// lib/features/encuestas/data/encuestas_service.dart

import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../core/network/errores.dart';
import '../../../core/storage/cache_local.dart';
import '../../citas/data/models/cita.dart';

/// La respuesta a la encuesta de una cita atendida.
class RespuestaEncuesta extends Equatable {
  final String citaId;

  /// De 1 a 5 estrellas.
  final int puntuacion;

  /// De 0 a 10: cuánto recomendaría al médico (la escala del NPS).
  final int recomendaria;

  /// Opcional; vacío no se manda.
  final String comentario;

  const RespuestaEncuesta({
    required this.citaId,
    required this.puntuacion,
    required this.recomendaria,
    this.comentario = '',
  });

  Map<String, dynamic> aJson() => {
    'citaId': citaId,
    'puntuacion': puntuacion,
    'recomendaria': recomendaria,
    if (comentario.trim().isNotEmpty) 'comentario': comentario.trim(),
  };

  @override
  List<Object?> get props => [citaId, puntuacion, recomendaria, comentario];
}

/// Esa cita ya tenía encuesta (409).
class EncuestaYaRespondida implements Exception {
  const EncuestaYaRespondida();
}

/// Las citas por calificar y de dónde salieron.
class EncuestasPendientes {
  final List<Cita> citas;
  final bool desdeCache;

  const EncuestasPendientes({required this.citas, this.desdeCache = false});
}

/// Las encuestas de satisfacción del portal (`/portal/encuestas`).
///
/// El servidor decide qué se puede calificar: las citas atendidas propias
/// (las de un dependiente cuentan para el titular) de los últimos
/// `general.encuestasDiasVentana` días que todavía no tienen encuesta. La
/// lista se guarda por persona (`encuestas:<uid>`, se borra al cerrar
/// sesión) para verla sin red.
class EncuestasService {
  static const String ruta = '/portal/encuestas';

  final Dio _dio;
  final CacheLocal _cache;

  EncuestasService(this._dio, this._cache);

  static String claveCache(String uid) => 'encuestas:$uid';

  /// `GET /portal/encuestas/pendientes`: las citas por calificar, la más
  /// reciente primero. Llegan con `citaId` y sin estado (todas están
  /// atendidas); se leen como cualquier cita, igual que en el panel.
  Future<EncuestasPendientes> pendientes(String uid) async {
    try {
      final respuesta = await _dio.get<dynamic>('$ruta/pendientes');

      final datos = respuesta.data;
      if (datos is! List) {
        throw const FormatException('Las encuestas pendientes no son lista');
      }

      final citas = _ordenadas([
        for (final c in datos)
          if (c is Map && c['citaId'] != null)
            Cita.desdeJson({...c, '_id': c['citaId'], 'status': 'ATENDIDA'}),
      ]);

      await guardarCopia(uid, citas);

      return EncuestasPendientes(citas: citas);
    } catch (_) {
      final copia = await _leer(uid);
      if (copia != null) {
        return EncuestasPendientes(citas: copia, desdeCache: true);
      }

      rethrow;
    }
  }

  /// `POST /portal/encuestas`. Si esa cita ya tenía respuesta (409), lanza
  /// [EncuestaYaRespondida].
  Future<void> responder(RespuestaEncuesta respuesta) async {
    try {
      await _dio.post<dynamic>(ruta, data: respuesta.aJson());
    } catch (error) {
      if (estadoDe(error) == 409) throw const EncuestaYaRespondida();
      rethrow;
    }
  }

  Future<void> guardarCopia(String uid, List<Cita> citas) =>
      _cache.guardar(claveCache(uid), [for (final c in citas) c.aJson()]);

  Future<List<Cita>?> _leer(String uid) async {
    try {
      final datos = await _cache.leer(claveCache(uid));
      if (datos is! List) return null;

      return _ordenadas([
        for (final d in datos)
          if (d is Map) Cita.desdeJson(d),
      ]);
    } catch (_) {
      return null;
    }
  }

  static List<Cita> _ordenadas(List<Cita> citas) =>
      citas..sort((a, b) => b.inicio.compareTo(a.inicio));
}
