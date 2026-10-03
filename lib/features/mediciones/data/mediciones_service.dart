// lib/features/mediciones/data/mediciones_service.dart

import 'package:dio/dio.dart';

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

/// Las mediciones del paciente en el servidor: `/portal/mediciones`.
///
/// El servidor deja ver y registrar solo lo propio y lo de los dependientes
/// del titular (`pacienteId`). La primera página se guarda en el teléfono
/// tal como llegó (por persona y por paciente) para verla sin red; se
/// borra al cerrar sesión, como todo lo personal.
class MedicionesService {
  static const String ruta = '/portal/mediciones';

  /// Cuántas mediciones admite el servidor en un envío.
  static const int maximoPorEnvio = 10;

  final Dio _dio;
  final CacheLocal _cache;

  MedicionesService(this._dio, this._cache);

  String _paciente(String uid, String? pacienteId) =>
      pacienteId == null || pacienteId.isEmpty ? uid : pacienteId;

  String _clave(String uid, String paciente) => 'mediciones:$uid:$paciente';

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
  /// en una atención (si no, el servidor lo dice).
  Future<void> eliminar(String id) => _dio.delete<dynamic>('$ruta/$id');

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
