// lib/features/soporte/data/models/ticket.dart

import 'package:equatable/equatable.dart';

import '../../../../core/fechas/instante.dart';

/// En qué va un ticket: `ABIERTO → EN_PROCESO → RESUELTO → CERRADO`.
///
/// Solo los códigos y su lógica: la etiqueta, el color y el icono de cada
/// uno están en el catálogo `ESTADO_TICKET`.
enum EstadoTicket {
  abierto('ABIERTO'),
  enProceso('EN_PROCESO'),
  resuelto('RESUELTO'),
  cerrado('CERRADO');

  /// Como lo escribe la API.
  final String codigo;

  const EstadoTicket(this.codigo);

  /// Resuelto o cerrado: el plazo ya no corre (el panel lo llama «cerrado»).
  bool get atendido =>
      this == EstadoTicket.resuelto || this == EstadoTicket.cerrado;

  /// Se puede escribir: en uno resuelto también (el servidor lo reabre);
  /// en uno cerrado, no.
  bool get admiteMensajes => this != EstadoTicket.cerrado;

  /// Un estado que esta versión no conoce se trata como cerrado: es la forma
  /// segura, porque no ofrece escribir donde el servidor lo rechazaría.
  static EstadoTicket desdeCodigo(Object? codigo) {
    final texto = codigo?.toString().toUpperCase().trim();

    return EstadoTicket.values.firstWhere(
      (estado) => estado.codigo == texto,
      orElse: () => EstadoTicket.cerrado,
    );
  }
}

String? _texto(Object? valor) {
  final texto = valor?.toString().trim();
  return texto == null || texto.isEmpty ? null : texto;
}

/// Un mensaje de la conversación: de quien pidió ayuda o del equipo.
class MensajeTicket extends Equatable {
  final String id;
  final String autorNombre;

  /// Lo escribió el equipo de soporte.
  final bool esSoporte;

  final String texto;

  /// El archivo que lo acompaña: solo su identificador (el nombre y el tipo
  /// llegan al descargarlo).
  final String? adjuntoId;

  /// Instante real en que se escribió.
  final DateTime? fecha;

  const MensajeTicket({
    required this.id,
    required this.texto,
    this.autorNombre = '',
    this.esSoporte = false,
    this.adjuntoId,
    this.fecha,
  });

  factory MensajeTicket.desdeJson(Map<dynamic, dynamic> json) => MensajeTicket(
    id: _texto(json['_id']) ?? '',
    autorNombre: _texto(json['autorNombre']) ?? '',
    esSoporte: json['esSoporte'] == true,
    texto: json['texto']?.toString() ?? '',
    adjuntoId: _texto(json['adjuntoId']),
    fecha: leerInstante(json['fecha']),
  );

  @override
  List<Object?> get props => [
    id,
    autorNombre,
    esSoporte,
    texto,
    adjuntoId,
    fecha,
  ];
}

/// Un ticket de soporte, como lo manda la API.
///
/// En la lista (`GET /soporte/tickets`) llega resumido, con cuántos
/// mensajes tiene y si el último es del equipo; en el detalle llega con la
/// conversación entera ([mensajes]). Todas sus fechas son instantes reales.
class Ticket extends Equatable {
  final String id;

  /// Código del catálogo `CATEGORIA_TICKET`.
  final String categoria;

  final String asunto;
  final String descripcion;

  /// Código del catálogo `SEVERIDAD_TICKET`.
  final String severidad;

  final EstadoTicket estado;
  final String usuarioNombre;
  final String? asignadoNombre;

  /// Hasta cuándo tiene soporte para responder (según la severidad).
  final DateTime? venceEn;

  final bool vencido;
  final bool vencePronto;
  final DateTime? creadoEn;
  final DateTime? actualizadoEn;

  // Solo en la lista.
  final int totalMensajes;
  final DateTime? ultimoMensajeEn;
  final bool? ultimoEsSoporte;

  /// Solo en el detalle; `null` en la lista.
  final List<MensajeTicket>? mensajes;

  const Ticket({
    required this.id,
    required this.asunto,
    required this.estado,
    this.categoria = '',
    this.descripcion = '',
    this.severidad = '',
    this.usuarioNombre = '',
    this.asignadoNombre,
    this.venceEn,
    this.vencido = false,
    this.vencePronto = false,
    this.creadoEn,
    this.actualizadoEn,
    this.totalMensajes = 0,
    this.ultimoMensajeEn,
    this.ultimoEsSoporte,
    this.mensajes,
  });

  /// El último mensaje es del equipo: «Soporte respondió».
  bool get respondioSoporte {
    final conversacion = mensajes;
    if (conversacion != null) {
      return conversacion.isNotEmpty && conversacion.last.esSoporte;
    }
    return ultimoEsSoporte == true;
  }

  /// Lo último que pasó: el último mensaje o, si no hay, la creación.
  DateTime? get ultimaActividad =>
      mensajes?.lastOrNull?.fecha ?? ultimoMensajeEn ?? creadoEn;

  /// Lee un ticket; lanza [FormatException] si no tiene identificador.
  factory Ticket.desdeJson(Map<dynamic, dynamic> json) {
    final id = _texto(json['_id']);
    if (id == null) throw const FormatException('Ticket sin identificador');

    final total = json['totalMensajes'];
    final mensajes = json['mensajes'];

    return Ticket(
      id: id,
      categoria: _texto(json['categoria'])?.toUpperCase() ?? '',
      asunto: _texto(json['asunto']) ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      severidad: _texto(json['severidad'])?.toUpperCase() ?? '',
      estado: EstadoTicket.desdeCodigo(json['estado']),
      usuarioNombre: _texto(json['usuarioNombre']) ?? '',
      asignadoNombre: _texto(json['asignadoNombre']),
      venceEn: leerInstante(json['venceEn']),
      vencido: json['vencido'] == true,
      vencePronto: json['vencePronto'] == true,
      creadoEn: leerInstante(json['creadoEn']),
      actualizadoEn: leerInstante(json['actualizadoEn']),
      totalMensajes: total is num
          ? total.toInt()
          : (mensajes is List ? mensajes.length : 0),
      ultimoMensajeEn: leerInstante(json['ultimoMensajeEn']),
      ultimoEsSoporte: json['ultimoEsSoporte'] is bool
          ? json['ultimoEsSoporte'] as bool
          : null,
      mensajes: mensajes is List
          ? [
              for (final m in mensajes)
                if (m is Map) MensajeTicket.desdeJson(m),
            ]
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    categoria,
    asunto,
    descripcion,
    severidad,
    estado,
    usuarioNombre,
    asignadoNombre,
    venceEn,
    vencido,
    vencePronto,
    creadoEn,
    actualizadoEn,
    totalMensajes,
    ultimoMensajeEn,
    ultimoEsSoporte,
    mensajes,
  ];
}

/// Lee la lista de tickets, saltando los que no se puedan leer.
List<Ticket> interpretarTickets(Object? datos) {
  if (datos is! List) return const [];

  final tickets = <Ticket>[];
  for (final item in datos) {
    if (item is! Map) continue;
    try {
      tickets.add(Ticket.desdeJson(item));
    } on FormatException {
      // Un ticket sin identificador no se puede abrir: no se enseña.
    }
  }

  return tickets;
}

/// Lo que se manda para abrir un ticket (`POST /soporte/tickets`).
class NuevoTicket extends Equatable {
  final String categoria;
  final String severidad;
  final String asunto;
  final String descripcion;

  const NuevoTicket({
    required this.categoria,
    required this.severidad,
    required this.asunto,
    required this.descripcion,
  });

  Map<String, dynamic> aJson() => {
    'categoria': categoria,
    if (severidad.isNotEmpty) 'severidad': severidad,
    'asunto': asunto.trim(),
    'descripcion': descripcion.trim(),
  };

  @override
  List<Object?> get props => [categoria, severidad, asunto, descripcion];
}
