import 'package:equatable/equatable.dart';

import '../../../../core/archivos/archivo_meta.dart';
import '../../../../core/fechas/instante.dart';
import 'campo_formulario.dart';

/// En qué va una consulta en línea.
///
/// `BORRADOR → ENVIADA → EN_REVISION → RESPONDIDA → CERRADA`, y una
/// `ENVIADA` se puede `CANCELADA`.
///
/// Solo los códigos y su lógica: la etiqueta, el color, el icono y la
/// descripción de cada uno están en el catálogo `ESTADO_CONSULTA`.
enum EstadoConsulta {
  borrador('BORRADOR'),
  enviada('ENVIADA'),
  enRevision('EN_REVISION'),
  respondida('RESPONDIDA'),
  cerrada('CERRADA'),
  cancelada('CANCELADA');

  /// Como lo escribe la API.
  final String codigo;

  const EstadoConsulta(this.codigo);

  /// Enviada o en revisión: el médico todavía no respondió.
  bool get esperandoRespuesta =>
      this == EstadoConsulta.enviada || this == EstadoConsulta.enRevision;

  /// Ya salió del borrador y todavía no terminó.
  bool get enCurso => esperandoRespuesta || this == EstadoConsulta.respondida;

  bool get terminada =>
      this == EstadoConsulta.cerrada || this == EstadoConsulta.cancelada;

  /// Un estado que esta versión no conoce se trata como terminado: es la
  /// forma segura, porque no ofrece acciones que el servidor rechazaría.
  static EstadoConsulta desdeCodigo(Object? codigo) {
    final texto = codigo?.toString().toUpperCase().trim();

    return EstadoConsulta.values.firstWhere(
      (estado) => estado.codigo == texto,
      orElse: () => EstadoConsulta.cerrada,
    );
  }
}

String? _texto(Object? valor) {
  final texto = valor?.toString().trim();
  return texto == null || texto.isEmpty ? null : texto;
}

int? _entero(Object? valor) => valor is num ? valor.toInt() : null;

/// Un mensaje de la conversación: del paciente o del médico.
class MensajeConsulta extends Equatable {
  final String id;
  final String autorId;
  final String autorNombre;
  final bool esMedico;
  final String texto;
  final ArchivoMeta? adjunto;

  /// Instante real en que se escribió.
  final DateTime? fecha;

  const MensajeConsulta({
    required this.id,
    required this.autorId,
    required this.autorNombre,
    required this.esMedico,
    required this.texto,
    this.adjunto,
    this.fecha,
  });

  factory MensajeConsulta.desdeJson(Map<dynamic, dynamic> json) {
    return MensajeConsulta(
      id: _texto(json['_id']) ?? '',
      autorId: _texto(json['autorId']) ?? '',
      autorNombre: _texto(json['autorNombre']) ?? '',
      esMedico: json['esMedico'] == true,
      texto: json['texto']?.toString() ?? '',
      adjunto: ArchivoMeta.desdeJson(json['adjunto']),
      fecha: leerInstante(json['fecha']),
    );
  }

  Map<String, dynamic> aJson() => {
    '_id': id,
    'autorId': autorId,
    'autorNombre': autorNombre,
    'esMedico': esMedico,
    'texto': texto,
    if (adjunto != null) 'adjunto': adjunto!.aJson(),
    'fecha': aTextoInstante(fecha),
  };

  @override
  List<Object?> get props => [
    id,
    autorId,
    autorNombre,
    esMedico,
    texto,
    adjunto,
    fecha,
  ];
}

/// Lo que se respondió a una pregunta del formulario.
class RespuestaConsulta extends Equatable {
  final String clave;
  final String etiqueta;
  final TipoCampo tipo;

  /// Texto, número, sí/no o `AAAA-MM-DD`; `null` si se dejó en blanco.
  final Object? valor;

  const RespuestaConsulta({
    required this.clave,
    required this.etiqueta,
    required this.tipo,
    this.valor,
  });

  static RespuestaConsulta? desdeJson(Object? json) {
    if (json is! Map) return null;

    final clave = _texto(json['clave']);
    if (clave == null) return null;

    final valor = json['valor'];

    return RespuestaConsulta(
      clave: clave,
      etiqueta: _texto(json['etiqueta']) ?? clave,
      tipo: TipoCampo.desdeCodigo(json['tipo']),
      valor: valor is String || valor is num || valor is bool ? valor : null,
    );
  }

  Map<String, dynamic> aJson() => {
    'clave': clave,
    'etiqueta': etiqueta,
    'tipo': tipo.codigo,
    'valor': valor,
  };

  @override
  List<Object?> get props => [clave, etiqueta, tipo, valor];
}

/// Una consulta en una lista (`ConsultaResumen`).
///
/// Todas sus fechas son instantes reales en UTC (ver `instante.dart`), no la
/// hora congelada de las citas.
class ConsultaResumen extends Equatable {
  final String id;

  /// «CA-XXXXXX», el número que se dicta por teléfono.
  final String codigo;

  final EstadoConsulta estado;
  final String pacienteId;
  final String pacienteNombre;
  final bool paraDependiente;
  final String medicoId;
  final String medicoNombre;
  final String especialidad;
  final String motivoId;
  final String motivoNombre;
  final DateTime? creadaEn;
  final DateTime? enviadaEn;

  /// Hasta cuándo tiene el médico para responder (48 h desde el envío).
  final DateTime? venceEn;

  final DateTime? respondidaEn;
  final DateTime? cerradaEn;

  /// Esperando respuesta y ya pasó `venceEn`.
  final bool vencida;

  /// Horas enteras que quedan, redondeadas hacia abajo; `null` fuera de
  /// ENVIADA y EN_REVISION.
  final int? horasRestantes;

  final int totalMensajes;
  final DateTime? ultimoMensajeEn;
  final bool? ultimoEsMedico;

  const ConsultaResumen({
    required this.id,
    required this.codigo,
    required this.estado,
    this.pacienteId = '',
    this.pacienteNombre = '',
    this.paraDependiente = false,
    this.medicoId = '',
    this.medicoNombre = '',
    this.especialidad = '',
    this.motivoId = '',
    this.motivoNombre = '',
    this.creadaEn,
    this.enviadaEn,
    this.venceEn,
    this.respondidaEn,
    this.cerradaEn,
    this.vencida = false,
    this.horasRestantes,
    this.totalMensajes = 0,
    this.ultimoMensajeEn,
    this.ultimoEsMedico,
  });

  /// El nombre del médico tal como llega, o `null` si todavía no tiene: no
  /// se le antepone ningún título ni se inventa uno.
  String? get medicoVisible => medicoNombre.isEmpty ? null : medicoNombre;

  /// El médico escribió lo último y la consulta sigue abierta: hay algo que
  /// leer.
  bool get respuestaPorLeer =>
      ultimoEsMedico == true && estado == EstadoConsulta.respondida;

  /// La fecha que ordena la lista: lo último que pasó.
  DateTime? get ultimaActividad =>
      ultimoMensajeEn ?? respondidaEn ?? enviadaEn ?? creadaEn;

  factory ConsultaResumen.desdeJson(Map<dynamic, dynamic> json) {
    return ConsultaResumen(
      id: _texto(json['_id']) ?? '',
      codigo: _texto(json['codigo']) ?? '',
      estado: EstadoConsulta.desdeCodigo(json['estado']),
      pacienteId: _texto(json['pacienteId']) ?? '',
      pacienteNombre: _texto(json['pacienteNombre']) ?? '',
      paraDependiente: json['paraDependiente'] == true,
      medicoId: _texto(json['medicoId']) ?? '',
      medicoNombre: _texto(json['medicoNombre']) ?? '',
      especialidad: _texto(json['especialidad']) ?? '',
      motivoId: _texto(json['motivoId']) ?? '',
      motivoNombre: _texto(json['motivoNombre']) ?? '',
      creadaEn: leerInstante(json['creadaEn']),
      enviadaEn: leerInstante(json['enviadaEn']),
      venceEn: leerInstante(json['venceEn']),
      respondidaEn: leerInstante(json['respondidaEn']),
      cerradaEn: leerInstante(json['cerradaEn']),
      vencida: json['vencida'] == true,
      horasRestantes: _entero(json['horasRestantes']),
      totalMensajes: _entero(json['totalMensajes']) ?? 0,
      ultimoMensajeEn: leerInstante(json['ultimoMensajeEn']),
      ultimoEsMedico: json['ultimoEsMedico'] is bool
          ? json['ultimoEsMedico'] as bool
          : null,
    );
  }

  /// Con los mismos nombres de la API, para la copia guardada.
  Map<String, dynamic> aJson() => {
    '_id': id,
    'codigo': codigo,
    'estado': estado.codigo,
    'pacienteId': pacienteId,
    'pacienteNombre': pacienteNombre,
    'paraDependiente': paraDependiente,
    'medicoId': medicoId,
    'medicoNombre': medicoNombre,
    'especialidad': especialidad,
    'motivoId': motivoId,
    'motivoNombre': motivoNombre,
    'creadaEn': aTextoInstante(creadaEn),
    'enviadaEn': aTextoInstante(enviadaEn),
    'venceEn': aTextoInstante(venceEn),
    'respondidaEn': aTextoInstante(respondidaEn),
    'cerradaEn': aTextoInstante(cerradaEn),
    'vencida': vencida,
    'horasRestantes': horasRestantes,
    'totalMensajes': totalMensajes,
    'ultimoMensajeEn': aTextoInstante(ultimoMensajeEn),
    'ultimoEsMedico': ultimoEsMedico,
  };

  @override
  List<Object?> get props => [
    id,
    codigo,
    estado,
    pacienteId,
    pacienteNombre,
    paraDependiente,
    medicoId,
    medicoNombre,
    especialidad,
    motivoId,
    motivoNombre,
    creadaEn,
    enviadaEn,
    venceEn,
    respondidaEn,
    cerradaEn,
    vencida,
    horasRestantes,
    totalMensajes,
    ultimoMensajeEn,
    ultimoEsMedico,
  ];
}

/// Una consulta entera (`ConsultaDetalle`): lo que se contó, lo adjuntado y
/// la conversación.
class ConsultaDetalle extends ConsultaResumen {
  final String descripcion;
  final List<RespuestaConsulta> respuestas;

  /// Los archivos del envío (los de los mensajes van en cada mensaje).
  final List<ArchivoMeta> adjuntos;

  final List<MensajeConsulta> mensajes;
  final String? atencionId;
  final DateTime? tomadaEn;

  /// Hasta cuándo se puede seguir escribiendo después de la respuesta.
  final DateTime? seguimientoHasta;

  final DateTime? canceladaEn;
  final String? motivoCancelacion;

  /// Si quien la pidió puede escribir ahora.
  final bool puedeEscribir;

  /// Las preguntas del motivo, copiadas al crear la consulta, si la API las
  /// manda. Son las que valida el envío, aunque el motivo cambie después.
  final List<CampoFormulario>? campos;

  /// Si el envío exige al menos un archivo. También se copia del motivo al
  /// crear la consulta y es lo que valida el servidor al enviarla; `false` si
  /// no viene.
  final bool requiereAdjunto;

  const ConsultaDetalle({
    required super.id,
    required super.codigo,
    required super.estado,
    super.pacienteId,
    super.pacienteNombre,
    super.paraDependiente,
    super.medicoId,
    super.medicoNombre,
    super.especialidad,
    super.motivoId,
    super.motivoNombre,
    super.creadaEn,
    super.enviadaEn,
    super.venceEn,
    super.respondidaEn,
    super.cerradaEn,
    super.vencida,
    super.horasRestantes,
    super.totalMensajes,
    super.ultimoMensajeEn,
    super.ultimoEsMedico,
    this.descripcion = '',
    this.respuestas = const [],
    this.adjuntos = const [],
    this.mensajes = const [],
    this.atencionId,
    this.tomadaEn,
    this.seguimientoHasta,
    this.canceladaEn,
    this.motivoCancelacion,
    this.puedeEscribir = false,
    this.campos,
    this.requiereAdjunto = false,
  });

  factory ConsultaDetalle.desdeJson(Map<dynamic, dynamic> json) {
    final resumen = ConsultaResumen.desdeJson(json);

    return ConsultaDetalle(
      id: resumen.id,
      codigo: resumen.codigo,
      estado: resumen.estado,
      pacienteId: resumen.pacienteId,
      pacienteNombre: resumen.pacienteNombre,
      paraDependiente: resumen.paraDependiente,
      medicoId: resumen.medicoId,
      medicoNombre: resumen.medicoNombre,
      especialidad: resumen.especialidad,
      motivoId: resumen.motivoId,
      motivoNombre: resumen.motivoNombre,
      creadaEn: resumen.creadaEn,
      enviadaEn: resumen.enviadaEn,
      venceEn: resumen.venceEn,
      respondidaEn: resumen.respondidaEn,
      cerradaEn: resumen.cerradaEn,
      vencida: resumen.vencida,
      horasRestantes: resumen.horasRestantes,
      totalMensajes: resumen.totalMensajes,
      ultimoMensajeEn: resumen.ultimoMensajeEn,
      ultimoEsMedico: resumen.ultimoEsMedico,
      descripcion: json['descripcion']?.toString() ?? '',
      respuestas: [
        for (final r in (json['respuestas'] as List?) ?? const [])
          ?RespuestaConsulta.desdeJson(r),
      ],
      adjuntos: interpretarArchivos(json['adjuntos']),
      mensajes: [
        for (final m in (json['mensajes'] as List?) ?? const [])
          if (m is Map) MensajeConsulta.desdeJson(m),
      ],
      atencionId: _texto(json['atencionId']),
      tomadaEn: leerInstante(json['tomadaEn']),
      seguimientoHasta: leerInstante(json['seguimientoHasta']),
      canceladaEn: leerInstante(json['canceladaEn']),
      motivoCancelacion: _texto(json['motivoCancelacion']),
      puedeEscribir: json['puedeEscribir'] == true,
      campos: json['campos'] is List ? interpretarCampos(json['campos']) : null,
      requiereAdjunto: json['requiereAdjunto'] == true,
    );
  }

  /// El resumen de esta consulta, para ponerlo al día en la lista.
  ConsultaResumen get resumen => ConsultaResumen(
    id: id,
    codigo: codigo,
    estado: estado,
    pacienteId: pacienteId,
    pacienteNombre: pacienteNombre,
    paraDependiente: paraDependiente,
    medicoId: medicoId,
    medicoNombre: medicoNombre,
    especialidad: especialidad,
    motivoId: motivoId,
    motivoNombre: motivoNombre,
    creadaEn: creadaEn,
    enviadaEn: enviadaEn,
    venceEn: venceEn,
    respondidaEn: respondidaEn,
    cerradaEn: cerradaEn,
    vencida: vencida,
    horasRestantes: horasRestantes,
    totalMensajes: totalMensajes,
    ultimoMensajeEn: ultimoMensajeEn,
    ultimoEsMedico: ultimoEsMedico,
  );

  @override
  Map<String, dynamic> aJson() => {
    ...super.aJson(),
    'descripcion': descripcion,
    'respuestas': [for (final r in respuestas) r.aJson()],
    'adjuntos': [for (final a in adjuntos) a.aJson()],
    'mensajes': [for (final m in mensajes) m.aJson()],
    'atencionId': atencionId,
    'tomadaEn': aTextoInstante(tomadaEn),
    'seguimientoHasta': aTextoInstante(seguimientoHasta),
    'canceladaEn': aTextoInstante(canceladaEn),
    'motivoCancelacion': motivoCancelacion,
    'puedeEscribir': puedeEscribir,
    if (campos != null) 'campos': [for (final c in campos!) c.aJson()],
    'requiereAdjunto': requiereAdjunto,
  };

  @override
  List<Object?> get props => [
    ...super.props,
    descripcion,
    respuestas,
    adjuntos,
    mensajes,
    atencionId,
    tomadaEn,
    seguimientoHasta,
    canceladaEn,
    motivoCancelacion,
    puedeEscribir,
    campos,
    requiereAdjunto,
  ];
}
