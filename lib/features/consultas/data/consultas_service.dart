import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/archivos/archivo_local.dart';
import '../../../core/archivos/archivo_meta.dart';
import '../../../core/archivos/subida.dart';
import '../../../core/network/errores.dart';
import '../../../core/storage/cache_local.dart';
import 'models/consulta.dart';
import 'models/opciones_consulta.dart';

/// Lo que se manda para crear una consulta (queda en BORRADOR).
class NuevaConsulta {
  final String motivoId;
  final String medicoId;

  /// Solo si es para un dependiente; sin él, es para el titular.
  final String? pacienteId;

  /// Clave de la pregunta → valor ya con su tipo (ver
  /// `respuestasParaApi`).
  final Map<String, Object?> respuestas;

  final String descripcion;

  const NuevaConsulta({
    required this.motivoId,
    required this.medicoId,
    required this.respuestas,
    required this.descripcion,
    this.pacienteId,
  });

  Map<String, dynamic> aJson() => {
    'motivoId': motivoId,
    'medicoId': medicoId,
    if (pacienteId != null && pacienteId!.isNotEmpty) 'pacienteId': pacienteId,
    'respuestas': respuestas,
    'descripcion': descripcion.trim(),
  };
}

/// Una lista de consultas y de dónde salió.
class ResultadoConsultas {
  final List<ConsultaResumen> consultas;

  /// Vienen de la copia guardada porque no hubo conexión.
  final bool desdeCache;

  /// Cuándo se guardó esa copia (hora del teléfono).
  final DateTime? guardadasEn;

  const ResultadoConsultas({
    required this.consultas,
    this.desdeCache = false,
    this.guardadasEn,
  });
}

/// Una consulta entera y de dónde salió.
class ResultadoDetalle {
  final ConsultaDetalle detalle;
  final bool desdeCache;
  final DateTime? guardadaEn;

  const ResultadoDetalle({
    required this.detalle,
    this.desdeCache = false,
    this.guardadaEn,
  });
}

/// Las consultas en línea del paciente: `/portal/consultas`.
///
/// El servidor solo deja ver y tocar las propias y las de los dependientes
/// del titular; cualquier otra responde 404. La lista y cada detalle se
/// guardan en el teléfono, como las citas: la respuesta del médico se tiene
/// que poder releer sin cobertura.
class ConsultasService {
  static const String _ruta = '/portal/consultas';

  final Dio _dio;
  final CacheLocal _cache;

  ConsultasService(this._dio, this._cache);

  String _claveLista(String uid) => 'consultas:$uid';
  String _claveDetalle(String uid, String id) => 'consulta:$uid:$id';

  // ── Lectura ────────────────────────────────────────────────────────

  /// `GET /portal/consultas/opciones`.
  Future<List<EspecialidadConsulta>> opciones() async {
    final respuesta = await _dio.get<dynamic>('$_ruta/opciones');
    return interpretarOpciones(respuesta.data);
  }

  /// `GET /portal/consultas?estado=`: las propias y las de los dependientes,
  /// las recientes primero. Sin conexión, las guardadas.
  Future<ResultadoConsultas> listar(String uid, {String? estado}) async {
    try {
      final respuesta = await _dio.get<dynamic>(
        _ruta,
        queryParameters: {
          if (estado != null && estado.isNotEmpty) 'estado': estado,
        },
      );
      final consultas = interpretarConsultas(respuesta.data);

      // Solo se guarda la lista completa: una filtrada pisaría la copia.
      if (estado == null || estado.isEmpty) {
        await _cache.guardar(_claveLista(uid), {
          'guardadasEn': DateTime.now().toUtc().toIso8601String(),
          'consultas': [for (final c in consultas) c.aJson()],
        });
      }

      return ResultadoConsultas(consultas: consultas);
    } catch (error) {
      if (!esFaltaDeRed(error)) rethrow;

      final guardadas = await consultasGuardadas(uid);
      if (guardadas == null) rethrow;

      return guardadas;
    }
  }

  /// La última lista guardada de esta persona, si hay.
  Future<ResultadoConsultas?> consultasGuardadas(String uid) async {
    try {
      final datos = await _cache.leer(_claveLista(uid));
      if (datos is! Map || datos['consultas'] is! List) return null;

      return ResultadoConsultas(
        consultas: interpretarConsultas(datos['consultas']),
        desdeCache: true,
        guardadasEn: DateTime.tryParse(datos['guardadasEn']?.toString() ?? '')
            ?.toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  /// `GET /portal/consultas/:id`. Sin conexión, la última copia guardada.
  Future<ResultadoDetalle> detalle(String uid, String id) async {
    try {
      final respuesta = await _dio.get<dynamic>('$_ruta/$id');
      final detalle = _detalleDe(respuesta.data);

      await _guardarDetalle(uid, detalle);

      return ResultadoDetalle(detalle: detalle);
    } catch (error) {
      if (!esFaltaDeRed(error)) rethrow;

      final guardado = await detalleGuardado(uid, id);
      if (guardado == null) rethrow;

      return guardado;
    }
  }

  Future<ResultadoDetalle?> detalleGuardado(String uid, String id) async {
    try {
      final datos = await _cache.leer(_claveDetalle(uid, id));
      if (datos is! Map || datos['detalle'] is! Map) return null;

      return ResultadoDetalle(
        detalle: ConsultaDetalle.desdeJson(datos['detalle'] as Map),
        desdeCache: true,
        guardadaEn: DateTime.tryParse(datos['guardadaEn']?.toString() ?? '')
            ?.toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Guarda la copia de una consulta que llegó por otra ruta (al enviar, al
  /// escribir), para que el detalle abra al día aunque no haya red.
  Future<void> recordar(String uid, ConsultaDetalle detalle) =>
      _guardarDetalle(uid, detalle);

  Future<void> _guardarDetalle(String uid, ConsultaDetalle detalle) async {
    try {
      await _cache.guardar(_claveDetalle(uid, detalle.id), {
        'guardadaEn': DateTime.now().toUtc().toIso8601String(),
        'detalle': detalle.aJson(),
      });
    } catch (error) {
      debugPrint('Cliniq · no se pudo guardar la consulta: $error');
    }
  }

  // ── Borrador ───────────────────────────────────────────────────────

  /// `POST /portal/consultas` → 201 con la consulta en BORRADOR.
  Future<ConsultaDetalle> crear(NuevaConsulta consulta) async {
    final respuesta = await _dio.post<dynamic>(_ruta, data: consulta.aJson());
    return _detalleDe(respuesta.data);
  }

  /// `PATCH /portal/consultas/:id`, solo en BORRADOR. Lo que no se pasa no
  /// se manda.
  Future<ConsultaDetalle> actualizar(
    String id, {
    Map<String, Object?>? respuestas,
    String? descripcion,
  }) async {
    final respuesta = await _dio.patch<dynamic>(
      '$_ruta/$id',
      data: {
        'respuestas': ?respuestas,
        if (descripcion != null) 'descripcion': descripcion.trim(),
      },
    );
    return _detalleDe(respuesta.data);
  }

  /// `POST /portal/consultas/:id/adjuntos`, multipart con el campo
  /// `archivo`. En BORRADOR se suma a los adjuntos del envío; después queda
  /// listo para acompañar un mensaje.
  Future<ArchivoMeta> subirAdjunto(
    String id,
    ArchivoLocal archivo, {
    void Function(int enviados, int total)? progreso,
  }) => subirArchivo(_dio, '$_ruta/$id/adjuntos', archivo, progreso: progreso);

  /// `DELETE /portal/consultas/:id/adjuntos/:archivoId`, solo en BORRADOR.
  Future<void> quitarAdjunto(String id, String archivoId) async {
    await _dio.delete<dynamic>('$_ruta/$id/adjuntos/$archivoId');
  }

  /// `POST /portal/consultas/:id/enviar` → la consulta ENVIADA.
  Future<ConsultaDetalle> enviar(String id) async {
    final respuesta = await _dio.post<dynamic>('$_ruta/$id/enviar');
    return _detalleDe(respuesta.data);
  }

  /// `DELETE /portal/consultas/:id`, solo en BORRADOR.
  Future<void> eliminar(String id) async {
    await _dio.delete<dynamic>('$_ruta/$id');
  }

  // ── Después de enviar ──────────────────────────────────────────────

  /// `POST /portal/consultas/:id/cancelar`, solo ENVIADA.
  Future<ConsultaDetalle> cancelar(String id, String motivo) async {
    final respuesta = await _dio.post<dynamic>(
      '$_ruta/$id/cancelar',
      data: {'motivo': motivo.trim()},
    );
    return _detalleDe(respuesta.data);
  }

  /// `POST /portal/consultas/:id/mensajes`, si `puedeEscribir`.
  Future<ConsultaDetalle> escribir(
    String id,
    String texto, {
    String? adjuntoId,
  }) async {
    final respuesta = await _dio.post<dynamic>(
      '$_ruta/$id/mensajes',
      data: {
        'texto': texto.trim(),
        if (adjuntoId != null && adjuntoId.isNotEmpty) 'adjuntoId': adjuntoId,
      },
    );
    return _detalleDe(respuesta.data);
  }

  ConsultaDetalle _detalleDe(Object? datos) {
    if (datos is! Map) throw const FormatException('Consulta ilegible');

    final detalle = ConsultaDetalle.desdeJson(datos);
    if (detalle.id.isEmpty) throw const FormatException('Consulta sin id');

    return detalle;
  }
}

/// Lee la lista de consultas, saltando las que no se puedan leer.
List<ConsultaResumen> interpretarConsultas(Object? datos) {
  if (datos is! List) return const [];

  final consultas = <ConsultaResumen>[];

  for (final item in datos) {
    if (item is! Map) continue;

    try {
      final consulta = ConsultaResumen.desdeJson(item);
      if (consulta.id.isNotEmpty) consultas.add(consulta);
    } catch (error) {
      debugPrint('Cliniq · consulta ilegible descartada: $error');
    }
  }

  return consultas;
}
