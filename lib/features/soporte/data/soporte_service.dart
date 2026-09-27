// lib/features/soporte/data/soporte_service.dart

import 'package:dio/dio.dart';

import '../../../core/archivos/archivo_local.dart';
import '../../../core/archivos/archivo_meta.dart';
import '../../../core/archivos/subida.dart';
import '../../../core/network/errores.dart';
import '../../../core/storage/cache_local.dart';
import '../../../core/storage/copia_guardada.dart';
import 'models/ticket.dart';

/// Los tickets de quien entró y de dónde salieron.
class ResultadoTickets {
  final List<Ticket> tickets;
  final bool desdeCache;
  final DateTime? guardadosEn;

  const ResultadoTickets({
    required this.tickets,
    this.desdeCache = false,
    this.guardadosEn,
  });
}

/// Un ticket entero y de dónde salió.
class ResultadoTicket {
  final Ticket ticket;
  final bool desdeCache;
  final DateTime? guardadoEn;

  const ResultadoTicket({
    required this.ticket,
    this.desdeCache = false,
    this.guardadoEn,
  });
}

/// La mesa de ayuda: `/soporte/tickets`.
///
/// Cada persona ve solo sus tickets; uno ajeno responde 404. La lista y
/// cada ticket se guardan en el teléfono para releer la conversación sin
/// cobertura; se borran al cerrar sesión.
class SoporteService {
  static const String _ruta = '/soporte/tickets';

  final Dio _dio;
  final CacheLocal _cache;

  SoporteService(this._dio, this._cache);

  String _claveLista(String uid) => 'tickets:$uid';
  String _claveTicket(String uid, String id) => 'ticket:$uid:$id';

  // ── Lectura ────────────────────────────────────────────────────────

  /// `GET /soporte/tickets`: los míos. Sin conexión, los guardados.
  Future<ResultadoTickets> listar(String uid) async {
    try {
      final respuesta = await _dio.get<dynamic>(_ruta);
      final tickets = interpretarTickets(respuesta.data);

      await _cache.guardarCopia(_claveLista(uid), respuesta.data);

      return ResultadoTickets(tickets: tickets);
    } catch (error) {
      if (!esFaltaDeRed(error)) rethrow;

      final guardados = await ticketsGuardados(uid);
      if (guardados == null) rethrow;

      return guardados;
    }
  }

  Future<ResultadoTickets?> ticketsGuardados(String uid) async {
    final copia = await _cache.leerCopia(_claveLista(uid));
    if (copia == null || copia.datos is! List) return null;

    return ResultadoTickets(
      tickets: interpretarTickets(copia.datos),
      desdeCache: true,
      guardadosEn: copia.guardadaEn,
    );
  }

  /// `GET /soporte/tickets/:id`, con la conversación. Sin conexión, la
  /// copia guardada.
  Future<ResultadoTicket> detalle(String uid, String id) async {
    try {
      final respuesta = await _dio.get<dynamic>('$_ruta/$id');
      final ticket = _ticketDe(respuesta.data);

      await _cache.guardarCopia(_claveTicket(uid, ticket.id), respuesta.data);

      return ResultadoTicket(ticket: ticket);
    } catch (error) {
      if (!esFaltaDeRed(error)) rethrow;

      final guardado = await ticketGuardado(uid, id);
      if (guardado == null) rethrow;

      return guardado;
    }
  }

  Future<ResultadoTicket?> ticketGuardado(String uid, String id) async {
    final copia = await _cache.leerCopia(_claveTicket(uid, id));
    final datos = copia?.datos;
    if (datos is! Map) return null;

    try {
      return ResultadoTicket(
        ticket: Ticket.desdeJson(datos),
        desdeCache: true,
        guardadoEn: copia!.guardadaEn,
      );
    } on FormatException {
      return null;
    }
  }

  // ── Escritura ──────────────────────────────────────────────────────

  /// `POST /soporte/tickets` → 201 con el ticket ABIERTO.
  Future<Ticket> crear(NuevoTicket ticket) async {
    final respuesta = await _dio.post<dynamic>(_ruta, data: ticket.aJson());
    return _ticketDe(respuesta.data);
  }

  /// `POST /soporte/tickets/:id/adjuntos`: sube el archivo (antes de
  /// mandarlo en un mensaje).
  Future<ArchivoMeta> subirAdjunto(
    String id,
    ArchivoLocal archivo, {
    void Function(int enviados, int total)? progreso,
  }) => subirArchivo(_dio, '$_ruta/$id/adjuntos', archivo, progreso: progreso);

  /// `POST /soporte/tickets/:id/mensajes {texto, adjuntoId?}` → el ticket
  /// con el mensaje nuevo. Si la respuesta no trae la conversación, se
  /// vuelve a pedir el ticket.
  Future<Ticket> responder(
    String uid,
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

    final datos = respuesta.data;
    if (datos is Map && datos['mensajes'] is List) {
      final ticket = _ticketDe(datos);
      await _cache.guardarCopia(_claveTicket(uid, ticket.id), datos);
      return ticket;
    }

    return (await detalle(uid, id)).ticket;
  }

  // ── Ayudantes ──────────────────────────────────────────────────────

  Ticket _ticketDe(Object? datos) {
    if (datos is! Map) throw const FormatException('Ticket ilegible');
    return Ticket.desdeJson(datos);
  }
}
