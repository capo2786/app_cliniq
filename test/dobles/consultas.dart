// test/dobles/consultas.dart

/// Datos y dobles de las consultas en línea, con la forma exacta del
/// contrato (`ConsultaResumen`, `ConsultaDetalle`, `OpcionesConsulta`…).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:app_cliniq/core/archivos/archivo_local.dart';
import 'package:app_cliniq/core/archivos/archivo_meta.dart';
import 'package:app_cliniq/features/consultas/data/consultas_service.dart';
import 'package:app_cliniq/features/consultas/data/models/consulta.dart';
import 'package:app_cliniq/features/consultas/data/models/opciones_consulta.dart';

/// Una consulta como la manda la API. Lo que no se pasa, con valores de
/// una consulta enviada hace poco.
Map<String, dynamic> consultaJson({
  String id = 'c1',
  String estado = 'ENVIADA',
  String venceEn = '2026-09-30T14:00:00.000Z',
  bool puedeEscribir = false,
  List<Map<String, dynamic>> mensajes = const [],
  List<Map<String, dynamic>> adjuntos = const [],
  List<Map<String, dynamic>> respuestas = const [],
  String descripcion = 'Tengo manchas rojas en el brazo desde el lunes.',
  bool paraDependiente = false,
  String pacienteId = 'u1',
  String pacienteNombre = 'Ana María Pérez',
  bool? ultimoEsMedico,
  List<Map<String, dynamic>>? campos,
  bool requiereAdjunto = false,
}) => {
  '_id': id,
  'codigo': 'CA-000123',
  'estado': estado,
  'pacienteId': pacienteId,
  'pacienteNombre': pacienteNombre,
  'paraDependiente': paraDependiente,
  'medicoId': 'doc1',
  'medicoNombre': 'Luis Mora',
  'especialidad': 'Dermatología',
  'motivoId': 'm-lesion',
  'motivoNombre': 'Lesión en la piel',
  'creadaEn': '2026-09-28T13:00:00.000Z',
  if (estado != 'BORRADOR') 'enviadaEn': '2026-09-28T14:00:00.000Z',
  if (estado != 'BORRADOR') 'venceEn': venceEn,
  'vencida': false,
  'horasRestantes': estado == 'ENVIADA' || estado == 'EN_REVISION' ? 48 : null,
  'totalMensajes': mensajes.length,
  if (mensajes.isNotEmpty) 'ultimoMensajeEn': mensajes.last['fecha'],
  'ultimoEsMedico': ?ultimoEsMedico,
  'descripcion': descripcion,
  'respuestas': respuestas,
  'adjuntos': adjuntos,
  'mensajes': mensajes,
  'puedeEscribir': puedeEscribir,
  'campos': ?campos,
  'requiereAdjunto': requiereAdjunto,
};

Map<String, dynamic> archivoJson(String id, {String nombre = 'foto.jpg'}) => {
  '_id': id,
  'nombre': nombre,
  'mime': nombre.endsWith('.pdf') ? 'application/pdf' : 'image/jpeg',
  'tamano': 2048,
  'creadoEn': '2026-09-28T14:00:00.000Z',
};

Map<String, dynamic> mensajeJson(
  String id, {
  bool esMedico = true,
  String texto = 'Es una dermatitis de contacto.',
  String fecha = '2026-09-28T16:00:00.000Z',
  Map<String, dynamic>? adjunto,
}) => {
  '_id': id,
  'autorId': esMedico ? 'doc1' : 'u1',
  'autorNombre': esMedico ? 'Luis Mora' : 'Ana María Pérez',
  'esMedico': esMedico,
  'texto': texto,
  'adjunto': ?adjunto,
  'fecha': fecha,
};

/// Los campos del motivo «Lesión en la piel»: uno de cada tipo.
const List<Map<String, dynamic>> camposLesion = [
  {
    'clave': 'desde',
    'etiqueta': '¿Desde cuándo?',
    'tipo': 'fecha',
    'requerido': true,
  },
  {
    'clave': 'zona',
    'etiqueta': 'Zona del cuerpo',
    'tipo': 'seleccion',
    'opciones': ['Cara', 'Brazos', 'Piernas'],
    'requerido': true,
  },
  {'clave': 'pica', 'etiqueta': '¿Pica?', 'tipo': 'siNo', 'requerido': true},
  {
    'clave': 'tamano',
    'etiqueta': 'Tamaño aproximado',
    'tipo': 'numero',
    'unidad': 'cm',
  },
  {'clave': 'forma', 'etiqueta': 'Forma', 'tipo': 'texto'},
  {'clave': 'notas', 'etiqueta': 'Algo más', 'tipo': 'textoLargo'},
];

/// `GET /portal/consultas/opciones`: dos especialidades.
Map<String, dynamic> opcionesJson() => {
  'especialidades': [
    {
      'nombre': 'Dermatología',
      'motivos': [
        {
          '_id': 'm-otro',
          'especialidad': '*',
          'nombre': 'Otro motivo',
          'descripcion': 'Cuéntanos qué te pasa.',
          'campos': <Map<String, dynamic>>[],
          'requiereAdjunto': false,
          'activo': true,
          'orden': 99,
          'isSystem': true,
        },
        {
          '_id': 'm-lesion',
          'especialidad': 'Dermatología',
          'nombre': 'Lesión en la piel',
          'descripcion': 'Manchas, granos o heridas que no sanan.',
          'campos': camposLesion,
          'requiereAdjunto': true,
          'activo': true,
          'orden': 1,
          'isSystem': true,
        },
      ],
      'medicos': [
        {'uid': 'doc1', 'nombre': 'Luis Mora', 'especialidad': 'Dermatología'},
      ],
    },
    {
      'nombre': 'Pediatría',
      'motivos': [
        {
          '_id': 'm-fiebre',
          'especialidad': 'Pediatría',
          'nombre': 'Fiebre',
          'descripcion': 'Fiebre en niños.',
          'campos': [
            {
              'clave': 'temp',
              'etiqueta': 'Temperatura',
              'tipo': 'numero',
              'unidad': '°C',
              'requerido': true,
            },
          ],
          'requiereAdjunto': false,
          'activo': true,
          'orden': 1,
          'isSystem': true,
        },
      ],
      'medicos': [
        {'uid': 'doc2', 'nombre': 'Rosa Vega', 'especialidad': 'Pediatría'},
      ],
    },
  ],
};

/// Bytes con la firma de un JPG.
Uint8List bytesJpg([int largo = 32]) =>
    Uint8List.fromList([0xff, 0xd8, 0xff, ...List.filled(largo, 7)]);

ArchivoLocal fotoLocal([String nombre = 'brazo.jpg']) =>
    ArchivoLocal(nombre: nombre, bytes: bytesJpg());

/// Las consultas en línea, con respuestas programadas y lo pedido anotado.
///
/// Lo que no se programa contesta con una consulta de ejemplo en el estado
/// que corresponde a la operación.
class ConsultasFalso implements ConsultasService {
  final List<String> llamadas = [];

  List<EspecialidadConsulta> especialidades = interpretarOpciones(
    opcionesJson(),
  );

  /// Lo que contesta `GET /portal/consultas`.
  List<ConsultaResumen> lista = const [];

  /// La lista contesta como la copia guardada: sin red, el servicio de
  /// verdad devuelve la última lista guardada.
  bool listaDesdeCache = false;

  /// Si está puesto, el próximo `listar` no contesta hasta que se complete.
  Completer<void>? retenerLista;

  ResultadoConsultas? guardadas;

  /// El detalle que devuelve cada `GET /portal/consultas/:id`, en orden; el
  /// último se repite.
  List<ConsultaDetalle> detalles = [];
  ResultadoDetalle? detalleEnCache;

  /// Si está puesto, el próximo `detalle` no contesta hasta que se complete:
  /// sirve para que una respuesta llegue tarde a propósito.
  Completer<void>? retenerDetalle;

  /// Errores programados por operación: 'listar', 'detalle', 'crear',
  /// 'actualizar', 'subir', 'enviar', 'escribir', 'cancelar', 'eliminar',
  /// 'quitar'. Se consumen de a uno.
  final Map<String, List<Object>> errores = {};

  final List<NuevaConsulta> creadas = [];
  final List<
    ({String id, Map<String, Object?>? respuestas, String? descripcion})
  >
  actualizadas = [];
  final List<({String id, ArchivoLocal archivo})> subidos = [];
  final List<({String id, String texto, String? adjuntoId})> escritos = [];
  final List<ConsultaDetalle> recordadas = [];

  int _archivos = 0;
  int _detallesPedidos = 0;

  void _quizaFalla(String operacion) {
    final pendientes = errores[operacion];
    if (pendientes != null && pendientes.isNotEmpty) {
      throw pendientes.removeAt(0);
    }
  }

  ConsultaDetalle _detalle(Map<String, dynamic> json) =>
      ConsultaDetalle.desdeJson(json);

  @override
  Future<List<EspecialidadConsulta>> opciones() async {
    llamadas.add('opciones');
    _quizaFalla('opciones');
    return especialidades;
  }

  @override
  Future<ResultadoConsultas> listar(String uid, {String? estado}) async {
    llamadas.add('listar:$uid');

    final retener = retenerLista;
    if (retener != null) {
      retenerLista = null;
      await retener.future;
    }

    _quizaFalla('listar');
    return ResultadoConsultas(consultas: lista, desdeCache: listaDesdeCache);
  }

  @override
  Future<ResultadoConsultas?> consultasGuardadas(String uid) async => guardadas;

  @override
  Future<ResultadoDetalle> detalle(String uid, String id) async {
    llamadas.add('detalle:$id');

    final retener = retenerDetalle;
    if (retener != null) {
      retenerDetalle = null;
      await retener.future;
    }

    _quizaFalla('detalle');

    final indice = _detallesPedidos < detalles.length
        ? _detallesPedidos
        : detalles.length - 1;
    _detallesPedidos++;

    return ResultadoDetalle(
      detalle: detalles.isEmpty
          ? _detalle(consultaJson(id: id))
          : detalles[indice],
    );
  }

  @override
  Future<ResultadoDetalle?> detalleGuardado(String uid, String id) async =>
      detalleEnCache;

  @override
  Future<void> recordar(String uid, ConsultaDetalle detalle) async =>
      recordadas.add(detalle);

  @override
  Future<ConsultaDetalle> crear(NuevaConsulta consulta) async {
    llamadas.add('crear');
    _quizaFalla('crear');
    creadas.add(consulta);

    return _detalle(
      consultaJson(
        id: 'c-nueva',
        estado: 'BORRADOR',
        descripcion: consulta.descripcion,
      ),
    );
  }

  @override
  Future<ConsultaDetalle> actualizar(
    String id, {
    Map<String, Object?>? respuestas,
    String? descripcion,
  }) async {
    llamadas.add('actualizar:$id');
    _quizaFalla('actualizar');
    actualizadas.add((
      id: id,
      respuestas: respuestas,
      descripcion: descripcion,
    ));

    return _detalle(
      consultaJson(id: id, estado: 'BORRADOR', descripcion: descripcion ?? ''),
    );
  }

  @override
  Future<ArchivoMeta> subirAdjunto(
    String id,
    ArchivoLocal archivo, {
    void Function(int enviados, int total)? progreso,
  }) async {
    llamadas.add('subir:$id:${archivo.nombre}');
    _quizaFalla('subir');
    subidos.add((id: id, archivo: archivo));

    return ArchivoMeta(
      id: 'a${++_archivos}',
      nombre: archivo.nombreParaSubir,
      mime: archivo.mime ?? '',
      tamano: archivo.tamano,
    );
  }

  @override
  Future<void> quitarAdjunto(String id, String archivoId) async {
    llamadas.add('quitar:$id:$archivoId');
    _quizaFalla('quitar');
  }

  @override
  Future<ConsultaDetalle> enviar(String id) async {
    llamadas.add('enviar:$id');
    _quizaFalla('enviar');
    return _detalle(consultaJson(id: id));
  }

  @override
  Future<void> eliminar(String id) async {
    llamadas.add('eliminar:$id');
    _quizaFalla('eliminar');
  }

  @override
  Future<ConsultaDetalle> cancelar(String id, String motivo) async {
    llamadas.add('cancelar:$id:$motivo');
    _quizaFalla('cancelar');
    return _detalle(consultaJson(id: id, estado: 'CANCELADA'));
  }

  @override
  Future<ConsultaDetalle> escribir(
    String id,
    String texto, {
    String? adjuntoId,
  }) async {
    llamadas.add('escribir:$id');
    _quizaFalla('escribir');
    escritos.add((id: id, texto: texto, adjuntoId: adjuntoId));

    return _detalle(
      consultaJson(
        id: id,
        estado: 'RESPONDIDA',
        puedeEscribir: true,
        mensajes: [
          mensajeJson('m1'),
          mensajeJson(
            'm2',
            esMedico: false,
            texto: texto,
            fecha: '2026-09-28T17:00:00.000Z',
            adjunto: adjuntoId == null ? null : archivoJson(adjuntoId),
          ),
        ],
      ),
    );
  }
}
