import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../network/api_interceptor.dart';
import '../storage/cache_local.dart';

/// Los catálogos que usa la aplicación, con los nombres de la API.
class Catalogos {
  const Catalogos._();

  static const String especialidad = 'ESPECIALIDAD';
  static const String motivoCancelacionPaciente = 'MOTIVO_CANCELACION_PACIENTE';
  static const String parentescoDependiente = 'PARENTESCO_DEPENDIENTE';

  /// El parentesco del contacto de emergencia del perfil (los dependientes
  /// usan [parentescoDependiente]).
  static const String parentesco = 'PARENTESCO';

  static const String modalidadCita = 'MODALIDAD_CITA';
  static const String preparacionCita = 'PREPARACION_CITA';
  static const String ciudad = 'CIUDAD';
  static const String sexo = 'SEXO';
  static const String tipoDocumento = 'TIPO_DOCUMENTO';
  static const String tipoSangre = 'TIPO_SANGRE';

  /// Etiqueta, color, icono y descripción de los estados (códigos fijos).
  static const String estadoCita = 'ESTADO_CITA';
  static const String estadoConsulta = 'ESTADO_CONSULTA';

  /// Los derechos ARCO que se pueden pedir (nombre, descripción, orden y
  /// cuáles se ofrecen) y cómo se ve cada estado de una solicitud.
  static const String tipoArco = 'TIPO_ARCO';
  static const String estadoArco = 'ESTADO_ARCO';

  static const List<String> todos = [
    especialidad,
    motivoCancelacionPaciente,
    parentescoDependiente,
    parentesco,
    modalidadCita,
    preparacionCita,
    ciudad,
    sexo,
    tipoDocumento,
    tipoSangre,
    estadoCita,
    estadoConsulta,
    tipoArco,
    estadoArco,
  ];
}

/// Un elemento de un catálogo, completo: el código que usa el sistema y
/// todo lo que el administrador edita.
class ItemCatalogo extends Equatable {
  final String codigo;
  final String nombre;
  final String descripcion;

  /// `#RRGGBB` o vacío.
  final String color;

  /// Nombre de un icono del juego del panel (`video`, `estetoscopio`…) o
  /// vacío.
  final String icono;

  final int orden;
  final bool esPorDefecto;

  const ItemCatalogo({
    required this.codigo,
    required this.nombre,
    this.descripcion = '',
    this.color = '',
    this.icono = '',
    this.orden = 0,
    this.esPorDefecto = false,
  });

  /// Lee un elemento del lote, o `null` si no tiene nombre (sin nombre no hay
  /// nada que enseñar) o si viene inactivo.
  static ItemCatalogo? desdeJson(Object? json) {
    if (json is! Map || json['isActive'] == false) return null;

    String texto(String campo) => json[campo]?.toString().trim() ?? '';

    final nombre = texto('nombre');
    if (nombre.isEmpty) return null;

    final orden = json['orden'];

    return ItemCatalogo(
      codigo: texto('codigo'),
      nombre: nombre,
      descripcion: texto('descripcion'),
      color: texto('color'),
      icono: texto('icono'),
      orden: orden is num ? orden.toInt() : int.tryParse('$orden') ?? 0,
      esPorDefecto: json['esPorDefecto'] == true,
    );
  }

  Map<String, dynamic> aJson() => {
    'codigo': codigo,
    'nombre': nombre,
    'descripcion': descripcion,
    'color': color,
    'icono': icono,
    'orden': orden,
    'esPorDefecto': esPorDefecto,
  };

  @override
  List<Object?> get props => [
    codigo,
    nombre,
    descripcion,
    color,
    icono,
    orden,
    esPorDefecto,
  ];
}

/// Los catálogos cargados y de dónde salió cada uno.
class CatalogosCargados {
  final Map<String, List<ItemCatalogo>> listas;

  /// Los que salieron de la copia del teléfono porque el servidor no
  /// respondió.
  final Set<String> desdeCache;

  /// Los pedidos que no se pudieron cargar ni había copia.
  final Set<String> faltantes;

  const CatalogosCargados({
    required this.listas,
    this.desdeCache = const {},
    this.faltantes = const {},
  });
}

/// Las listas que se administran desde el panel, leídas por la aplicación.
///
/// `GET /catalogos/lote?keys=A,B,C` es pública (`@Public()`) y devuelve
/// `{A: [elementos], …}` con los elementos activos ya ordenados, completos:
/// `{codigo, nombre, descripcion, color, icono, orden, esPorDefecto}`. Se
/// conservan todos esos campos.
///
/// Lo que responde el servidor manda, aunque sea una lista vacía. Sin red se
/// usa la última copia guardada de cada catálogo; sin copia, el catálogo
/// queda en [CatalogosCargados.faltantes]. La aplicación no trae ninguna
/// lista de respaldo: nunca se inventan opciones.
class CatalogoService {
  static const String ruta = '/catalogos/lote';

  /// Con el prefijo `catalogos`, que es de la clínica y sobrevive al cierre
  /// de sesión. La clave cambió al guardar los elementos completos: la copia
  /// vieja (`catalogos:lote`, solo nombres) no se lee.
  static const String claveCache = 'catalogos:elementos';

  final Dio _dio;
  final CacheLocal _cache;

  CatalogoService(this._dio, this._cache);

  Future<CatalogosCargados> cargar([
    List<String> claves = Catalogos.todos,
  ]) async {
    final guardado = await _leerGuardado();

    Map<String, List<ItemCatalogo>> recibido;
    try {
      final respuesta = await _dio.get<dynamic>(
        ruta,
        queryParameters: {'keys': claves.join(',')},
        options: Options(extra: const {rutaPublica: true}),
      );

      if (respuesta.data is! Map) {
        throw const FormatException('El lote de catálogos no es un objeto');
      }

      recibido = interpretarLote(respuesta.data);
    } catch (_) {
      recibido = const {};
    }

    final listas = <String, List<ItemCatalogo>>{};
    final desdeCache = <String>{};
    final faltantes = <String>{};

    for (final clave in claves) {
      final delServidor = recibido[clave];
      final copia = guardado[clave];

      if (delServidor != null) {
        listas[clave] = delServidor;
      } else if (copia != null) {
        listas[clave] = copia;
        desdeCache.add(clave);
      } else {
        faltantes.add(clave);
      }
    }

    if (recibido.isNotEmpty) {
      await _cache.guardar(claveCache, {
        for (final entrada in {...guardado, ...recibido}.entries)
          entrada.key: [for (final item in entrada.value) item.aJson()],
      });
    }

    return CatalogosCargados(
      listas: listas,
      desdeCache: desdeCache,
      faltantes: faltantes,
    );
  }

  Future<Map<String, List<ItemCatalogo>>> _leerGuardado() async {
    try {
      return interpretarLote(await _cache.leer(claveCache));
    } catch (_) {
      return const {};
    }
  }
}

/// Lee la respuesta del lote: `{CLAVE: [{codigo, nombre, …}]}`, en el orden
/// en que llegan (el servidor ya los ordena).
Map<String, List<ItemCatalogo>> interpretarLote(Object? datos) {
  if (datos is! Map) return {};

  return {
    for (final entrada in datos.entries)
      if (entrada.value is List)
        entrada.key.toString().toUpperCase(): [
          for (final item in entrada.value as List)
            ?ItemCatalogo.desdeJson(item),
        ],
  };
}
