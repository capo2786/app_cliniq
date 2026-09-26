import 'package:dio/dio.dart';

import '../storage/cache_local.dart';

/// Los catálogos que usa la aplicación, con los nombres de la API.
class Catalogos {
  const Catalogos._();

  static const String motivoCancelacion = 'MOTIVO_CANCELACION';
  static const String especialidad = 'ESPECIALIDAD';
  static const String parentesco = 'PARENTESCO';

  static const List<String> todos = [
    motivoCancelacion,
    especialidad,
    parentesco,
  ];
}

/// Valores de partida, iguales a los que siembra la API y a los del panel
/// web (`CATALOGOS_DE_PARTIDA`). Solo se usan si el servidor no responde y
/// no hay copia guardada: un formulario sin opciones no se puede llenar.
const Map<String, List<String>> catalogosDePartida = {
  Catalogos.especialidad: [
    'Medicina General',
    'Medicina Familiar',
    'Medicina Interna',
    'Pediatría',
    'Ginecología y Obstetricia',
    'Cardiología',
    'Dermatología',
    'Endocrinología',
    'Gastroenterología',
    'Neurología',
    'Traumatología',
    'Psicología',
    'Psiquiatría',
    'Nutrición',
    'Odontología',
  ],
  Catalogos.motivoCancelacion: [
    'El paciente pidió cancelar',
    'El paciente no puede asistir',
    'El médico no está disponible',
    'Se reprogramó para otra fecha',
    'Emergencia médica',
    'Error al registrar la cita',
    'Otro motivo',
  ],
  Catalogos.parentesco: [
    'Madre',
    'Padre',
    'Cónyuge',
    'Hijo/a',
    'Hermano/a',
    'Otro familiar',
    'Amigo/a',
  ],
};

/// Las listas que se administran desde el panel, leídas por la aplicación.
///
/// `GET /catalogos/lote?keys=A,B,C` devuelve `{A: [elementos], …}` con los
/// elementos activos ya ordenados. Se guarda una copia en el teléfono: un
/// catálogo cambia poco, y sin él no se puede ni cancelar una cita.
class CatalogoService {
  static const String _claveCache = 'catalogos:lote';

  final Dio _dio;
  final CacheLocal _cache;

  CatalogoService(this._dio, this._cache);

  /// Los nombres de cada catálogo pedido, en el orden del panel.
  ///
  /// Con red se descarga y se guarda; sin red se usa lo guardado; y si nunca
  /// se descargó, los valores de partida. Un catálogo que llega vacío
  /// también cae a lo guardado o a la partida: vacío no sirve para nada.
  Future<Map<String, List<String>>> cargar([
    List<String> claves = Catalogos.todos,
  ]) async {
    final guardado = await _leerGuardado();

    try {
      final respuesta = await _dio.get<dynamic>(
        '/catalogos/lote',
        queryParameters: {'keys': claves.join(',')},
      );

      final recibido = interpretarLote(respuesta.data);
      final resultado = {
        for (final clave in claves)
          clave: _primeroConAlgo([
            recibido[clave],
            guardado[clave],
            catalogosDePartida[clave],
          ]),
      };

      await _cache.guardar(_claveCache, {...guardado, ...resultado});

      return resultado;
    } catch (_) {
      return {
        for (final clave in claves)
          clave: _primeroConAlgo([guardado[clave], catalogosDePartida[clave]]),
      };
    }
  }

  Future<Map<String, List<String>>> _leerGuardado() async {
    try {
      final datos = await _cache.leer(_claveCache);
      if (datos is! Map) return {};

      return {
        for (final entrada in datos.entries)
          if (entrada.value is List)
            entrada.key.toString(): (entrada.value as List)
                .map((x) => x.toString())
                .toList(),
      };
    } catch (_) {
      return {};
    }
  }

  static List<String> _primeroConAlgo(List<List<String>?> candidatos) {
    for (final lista in candidatos) {
      if (lista != null && lista.isNotEmpty) return lista;
    }

    return const [];
  }
}

/// Lee la respuesta del lote: `{CLAVE: [{nombre, isActive, …}]}`.
Map<String, List<String>> interpretarLote(Object? datos) {
  if (datos is! Map) return {};

  return {
    for (final entrada in datos.entries)
      if (entrada.value is List)
        entrada.key.toString().toUpperCase(): [
          for (final item in entrada.value as List)
            if (item is Map &&
                item['isActive'] != false &&
                (item['nombre']?.toString().trim().isNotEmpty ?? false))
              item['nombre'].toString().trim(),
        ],
  };
}
