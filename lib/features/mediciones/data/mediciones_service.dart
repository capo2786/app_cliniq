// lib/features/mediciones/data/mediciones_service.dart

import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/errores.dart';
import '../../../core/storage/cache_local.dart';
import '../../../core/storage/copia_guardada.dart';
import 'models/medicion.dart';

/// Una página de mediciones y si hay más atrás.
class PaginaMediciones {
  final List<Medicion> mediciones;

  /// Hay mediciones más antiguas que pedir.
  final bool hayMas;

  /// El número de esta página (1 la primera).
  final int pagina;

  /// Cómo se llama el parámetro de la página en este servidor (`page` o
  /// `pagina`), para pedir la siguiente igual.
  final String parametroPagina;

  final bool desdeCache;
  final DateTime? guardadaEn;

  const PaginaMediciones({
    required this.mediciones,
    this.hayMas = false,
    this.pagina = 1,
    this.parametroPagina = 'page',
    this.desdeCache = false,
    this.guardadaEn,
  });
}

/// Una medición completa (`GET /portal/mediciones/:id`), del servidor o de
/// la copia del teléfono.
class MedicionObtenida {
  final Medicion medicion;
  final bool desdeCache;
  final DateTime? guardadaEn;

  const MedicionObtenida(
    this.medicion, {
    this.desdeCache = false,
    this.guardadaEn,
  });
}

/// Las mediciones del paciente en el servidor: `/portal/mediciones`.
///
/// El servidor deja ver y registrar solo lo propio y lo de los dependientes
/// del titular (`pacienteId`). La primera página se guarda en el teléfono
/// tal como llegó (por persona y por paciente) para verla sin red, y
/// también las últimas [copiasDeMediciones] mediciones completas que se
/// abrieron (con su detalle, unos 10 KB cada una); todo se borra al cerrar
/// sesión, como todo lo personal.
class MedicionesService {
  static const String ruta = '/portal/mediciones';

  /// Cuántas mediciones admite el servidor en un envío.
  static const int maximoPorEnvio = 10;

  /// Cuántas mediciones completas abiertas se guardan para verlas sin red.
  static const int copiasDeMediciones = 10;

  final Dio _dio;
  final CacheLocal _cache;

  MedicionesService(this._dio, this._cache);

  String _paciente(String uid, String? pacienteId) =>
      pacienteId == null || pacienteId.isEmpty ? uid : pacienteId;

  String _clave(String uid, String paciente) => 'mediciones:$uid:$paciente';

  String _claveCompletas(String uid) => 'mediciones-completas:$uid';

  /// `GET /portal/mediciones`: la página [pagina] (la primera, si no se
  /// dice). Sin red, la primera página guardada; sin copia, el error.
  Future<PaginaMediciones> listar(
    String uid, {
    String? pacienteId,
    int pagina = 1,
    String parametroPagina = 'page',
  }) async {
    final paciente = _paciente(uid, pacienteId);

    try {
      final respuesta = await _dio.get<dynamic>(
        ruta,
        queryParameters: {
          if (paciente != uid) 'pacienteId': paciente,
          if (pagina > 1) parametroPagina: pagina,
        },
      );
      final leida = leerPagina(respuesta.data);
      if (pagina == 1) {
        await _cache.guardarCopia(_clave(uid, paciente), respuesta.data);
      }
      return leida;
    } catch (error) {
      if (pagina != 1 || !esFaltaDeRed(error)) rethrow;

      final copia = await guardada(uid, pacienteId: pacienteId);
      if (copia == null) rethrow;
      return copia;
    }
  }

  /// Las mediciones desde [desde] (para las tendencias), en páginas de
  /// [porPagina] (el máximo del servidor) hasta tenerlas todas o llegar a
  /// [maximoPaginas]. `completo` dice si llegaron todas. No se guardan: sin
  /// red, lanza el error.
  Future<({List<Medicion> mediciones, bool completo})> delPeriodo(
    String uid, {
    String? pacienteId,
    required DateTime desde,
    int porPagina = 100,
    int maximoPaginas = 5,
  }) async {
    final paciente = _paciente(uid, pacienteId);
    final mediciones = <Medicion>[];
    var hayMas = true;
    for (var pagina = 1; hayMas && pagina <= maximoPaginas; pagina++) {
      final respuesta = await _dio.get<dynamic>(
        ruta,
        queryParameters: {
          if (paciente != uid) 'pacienteId': paciente,
          'desde': desde.toUtc().toIso8601String(),
          'limit': porPagina,
          if (pagina > 1) 'page': pagina,
        },
      );
      final leida = leerPagina(respuesta.data);
      mediciones.addAll(leida.mediciones);
      hayMas = leida.hayMas;
    }
    return (mediciones: mediciones, completo: !hayMas);
  }

  /// La primera página guardada de ese paciente, si hay.
  Future<PaginaMediciones?> guardada(String uid, {String? pacienteId}) async {
    final copia = await _cache.leerCopia(
      _clave(uid, _paciente(uid, pacienteId)),
    );
    if (copia == null) return null;

    try {
      final pagina = leerPagina(copia.datos);
      return PaginaMediciones(
        mediciones: pagina.mediciones,
        hayMas: pagina.hayMas,
        pagina: pagina.pagina,
        parametroPagina: pagina.parametroPagina,
        desdeCache: true,
        guardadaEn: copia.guardadaEn,
      );
    } on FormatException {
      return null;
    }
  }

  /// `POST /portal/mediciones` con hasta [maximoPorEnvio] mediciones.
  /// Devuelve las que creó el servidor, si las devuelve.
  Future<List<Medicion>> enviar({
    String? pacienteId,
    required List<MedicionNueva> mediciones,
  }) async {
    assert(mediciones.isNotEmpty && mediciones.length <= maximoPorEnvio);

    final respuesta = await _dio.post<dynamic>(
      ruta,
      data: {
        'pacienteId': ?pacienteId,
        'mediciones': [for (final m in mediciones) m.aJson()],
      },
    );
    return _lista(respuesta.data);
  }

  /// `DELETE /portal/mediciones/:id`: solo quien la registró y si no se usó
  /// en una atención (si no, el servidor lo dice). Con [uid], también se
  /// borra su copia del teléfono.
  Future<void> eliminar(String id, {String? uid}) async {
    await _dio.delete<dynamic>('$ruta/${Uri.encodeComponent(id)}');
    if (uid != null) await _cambiarCompletas(uid, id, null);
  }

  /// `GET /portal/mediciones/:id`: la medición completa, con su detalle.
  /// El servidor la da solo si es propia o de un dependiente del titular
  /// (si no, 404). Sin red, la copia del teléfono; sin copia, el error.
  Future<MedicionObtenida> obtener(String uid, String id) async {
    try {
      final respuesta = await _dio.get<dynamic>(
        '$ruta/${Uri.encodeComponent(id)}',
      );
      final medicion = leerMedicion(respuesta.data);
      if (medicion == null) {
        throw const FormatException('La medición no se pudo leer');
      }
      await _cambiarCompletas(uid, id, respuesta.data);
      return MedicionObtenida(medicion);
    } catch (error) {
      if (!esFaltaDeRed(error)) rethrow;

      final copia = await completaGuardada(uid, id);
      if (copia == null) rethrow;
      return copia;
    }
  }

  /// La copia de esa medición completa, si se abrió antes.
  Future<MedicionObtenida?> completaGuardada(String uid, String id) async {
    try {
      final copias = await _cache.leer(_claveCompletas(uid));
      final copia = copias is Map ? copias[id] : null;
      if (copia is! Map) return null;
      final medicion = leerMedicion(copia['datos']);
      if (medicion == null) return null;
      return MedicionObtenida(
        medicion,
        desdeCache: true,
        guardadaEn: DateTime.tryParse(copia['guardadaEn']?.toString() ?? '')
            ?.toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Guarda (o, con [datos] nulos, borra) la copia de una medición
  /// completa; se quedan solo las [copiasDeMediciones] más recientes. Un
  /// fallo al guardar no se propaga.
  Future<void> _cambiarCompletas(String uid, String id, Object? datos) async {
    try {
      final clave = _claveCompletas(uid);
      final previas = await _cache.leer(clave);
      final habia = previas is Map && previas.containsKey(id);
      if (datos == null && !habia) return;

      // Las más viejas primero: la que se abre ahora va al final.
      final copias = <String, Object?>{
        if (previas is Map)
          for (final MapEntry(:key, :value) in previas.entries)
            if (key.toString() != id) key.toString(): value,
        if (datos != null)
          id: {
            'guardadaEn': DateTime.now().toUtc().toIso8601String(),
            'datos': datos,
          },
      };
      final sobran = copias.keys
          .take(math.max(0, copias.length - copiasDeMediciones))
          .toList();
      sobran.forEach(copias.remove);
      await _cache.guardar(clave, copias);
    } catch (error) {
      debugPrint('Cliniq · no se pudo guardar la copia de la medición: $error');
    }
  }

  /// Lee la respuesta de una medición: la medición sola, o dentro de
  /// `medicion`, `data` o `item`.
  static Medicion? leerMedicion(Object? datos) {
    if (datos is! Map) return null;
    final adentro = datos['medicion'] ?? datos['data'] ?? datos['item'];
    return Medicion.desdeJson(adentro is Map ? adentro : datos);
  }

  /// Lee la respuesta de la lista. El contrato dice «paginadas» sin fijar
  /// la forma, así que se aceptan las dos que usa el API: `{items, total,
  /// page, limit}` (o con los nombres en español) y `{items, hayMas}`; y
  /// también una lista sola.
  static PaginaMediciones leerPagina(Object? datos) {
    if (datos is List) return PaginaMediciones(mediciones: _lista(datos));
    if (datos is! Map) {
      throw const FormatException('Las mediciones no son una lista');
    }

    final items = datos['items'] ?? datos['datos'] ?? datos['data'];
    if (items is! List) {
      throw const FormatException('Las mediciones no traen sus items');
    }

    int? entero(Object? valor) => valor is num ? valor.toInt() : null;

    final parametro = datos.containsKey('pagina') ? 'pagina' : 'page';
    final pagina = entero(datos['page'] ?? datos['pagina']) ?? 1;
    final limite = entero(datos['limit'] ?? datos['limite']);
    final total = entero(datos['total']);

    final hayMas =
        datos['hayMas'] == true ||
        (total != null && limite != null && pagina * limite < total);

    return PaginaMediciones(
      mediciones: _lista(items),
      hayMas: hayMas,
      pagina: pagina,
      parametroPagina: parametro,
    );
  }

  static List<Medicion> _lista(Object? datos) {
    final lista = datos is List
        ? datos
        : datos is Map
        ? (datos['mediciones'] ?? datos['items'] ?? const [])
        : const [];
    if (lista is! List) return const [];

    return [
      for (final item in lista)
        if (item is Map) ?Medicion.desdeJson(item),
    ];
  }
}
