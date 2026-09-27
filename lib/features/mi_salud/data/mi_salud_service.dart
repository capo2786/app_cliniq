// lib/features/mi_salud/data/mi_salud_service.dart

import 'package:dio/dio.dart';

import '../../../core/network/errores.dart';
import '../../../core/storage/cache_local.dart';
import '../../../core/storage/copia_guardada.dart';
import 'models/mi_salud.dart';

/// Mi salud y de dónde salió.
class ResultadoMiSalud {
  final MiSalud datos;

  /// Viene de la copia guardada porque no hubo conexión.
  final bool desdeCache;

  /// Cuándo se guardó esa copia (hora del teléfono).
  final DateTime? guardadaEn;

  const ResultadoMiSalud({
    required this.datos,
    this.desdeCache = false,
    this.guardadaEn,
  });
}

/// Una receta, una orden o un certificado y de dónde salió.
class ResultadoDocumento<T extends DocumentoClinico> {
  final T documento;
  final bool desdeCache;
  final DateTime? guardadoEn;

  const ResultadoDocumento({
    required this.documento,
    this.desdeCache = false,
    this.guardadoEn,
  });
}

/// La historia clínica que ve el paciente: `GET /portal/mi-salud`, y el
/// detalle de cada receta, orden y certificado de reposo
/// (`/portal/recetas/:id`, `/portal/ordenes/:id`,
/// `/portal/certificados/:id`).
///
/// El servidor solo deja ver lo propio y lo de los dependientes del
/// titular (`?pacienteId=`); lo ajeno responde 404. Cada respuesta se
/// guarda en el teléfono tal como llegó, por persona y por paciente: una
/// receta se tiene que poder enseñar en la farmacia sin cobertura. Se borra
/// al cerrar sesión, como todo lo personal.
class MiSaludService {
  static const String _ruta = '/portal/mi-salud';

  final Dio _dio;
  final CacheLocal _cache;

  MiSaludService(this._dio, this._cache);

  /// El titular se pide sin `pacienteId`; un dependiente, con el suyo.
  String _paciente(String uid, String? pacienteId) =>
      pacienteId == null || pacienteId.isEmpty ? uid : pacienteId;

  String _claveMiSalud(String uid, String paciente) =>
      'mi-salud:$uid:$paciente';
  String _claveReceta(String uid, String id) => 'receta:$uid:$id';
  String _claveOrden(String uid, String id) => 'orden:$uid:$id';
  String _claveCertificado(String uid, String id) => 'certificado:$uid:$id';

  /// Mi salud del titular o de uno de sus dependientes. Sin conexión, la
  /// última copia guardada; sin copia, el error.
  Future<ResultadoMiSalud> cargar(String uid, {String? pacienteId}) async {
    final paciente = _paciente(uid, pacienteId);

    try {
      final respuesta = await _dio.get<dynamic>(
        _ruta,
        queryParameters: {if (paciente != uid) 'pacienteId': paciente},
      );
      final datos = MiSalud.desdeJson(respuesta.data);

      await _cache.guardarCopia(_claveMiSalud(uid, paciente), respuesta.data);

      return ResultadoMiSalud(datos: datos);
    } catch (error) {
      if (!esFaltaDeRed(error)) rethrow;

      final copia = await guardada(uid, pacienteId: pacienteId);
      if (copia == null) rethrow;

      return copia;
    }
  }

  /// La última copia de Mi salud de ese paciente, si hay.
  Future<ResultadoMiSalud?> guardada(String uid, {String? pacienteId}) async {
    final copia = await _cache.leerCopia(
      _claveMiSalud(uid, _paciente(uid, pacienteId)),
    );
    if (copia == null) return null;

    try {
      return ResultadoMiSalud(
        datos: MiSalud.desdeJson(copia.datos),
        desdeCache: true,
        guardadaEn: copia.guardadaEn,
      );
    } on FormatException {
      return null;
    }
  }

  /// `GET /portal/recetas/:id`. Sin conexión, la copia guardada.
  Future<ResultadoDocumento<Receta>> receta(String uid, String id) =>
      _documento(
        '/portal/recetas/$id',
        _claveReceta(uid, id),
        Receta.desdeJson,
      );

  /// `GET /portal/ordenes/:id`. Sin conexión, la copia guardada.
  Future<ResultadoDocumento<Orden>> orden(String uid, String id) =>
      _documento('/portal/ordenes/$id', _claveOrden(uid, id), Orden.desdeJson);

  /// `GET /portal/certificados/:id`. Sin conexión, la copia guardada.
  Future<ResultadoDocumento<CertificadoReposo>> certificado(
    String uid,
    String id,
  ) => _documento(
    '/portal/certificados/$id',
    _claveCertificado(uid, id),
    CertificadoReposo.desdeJson,
  );

  Future<ResultadoDocumento<T>> _documento<T extends DocumentoClinico>(
    String ruta,
    String clave,
    T Function(Map<dynamic, dynamic> json) leer,
  ) async {
    try {
      final respuesta = await _dio.get<dynamic>(ruta);
      final datos = respuesta.data;
      if (datos is! Map) throw const FormatException('Documento ilegible');

      final documento = leer(datos);
      await _cache.guardarCopia(clave, datos);

      return ResultadoDocumento(documento: documento);
    } catch (error) {
      if (!esFaltaDeRed(error)) rethrow;

      final copia = await _cache.leerCopia(clave);
      final datos = copia?.datos;
      if (datos is! Map) rethrow;

      T? documento;
      try {
        documento = leer(datos);
      } on FormatException {
        documento = null;
      }
      if (documento == null) rethrow;

      return ResultadoDocumento(
        documento: documento,
        desdeCache: true,
        guardadoEn: copia!.guardadaEn,
      );
    }
  }
}
