// test/dobles/soporte.dart

/// Tickets de soporte con la forma exacta de la API (`TicketDto` y
/// `TicketResumenDto` de auth-ms).
library;

import 'dart:typed_data';

import 'package:app_cliniq/core/archivos/archivo_local.dart';

Map<String, dynamic> mensajeTicketJson(
  String id, {
  bool esSoporte = true,
  String texto = 'Gracias por avisar. Ya lo revisamos.',
  String fecha = '2026-09-27T15:20:13.785Z',
  String? adjuntoId,
}) => {
  '_id': id,
  'autorId': esSoporte ? 'admin1' : 'u1',
  'autorNombre': esSoporte ? 'Admin Cliniq' : 'Ana María Pérez',
  'esSoporte': esSoporte,
  'texto': texto,
  'adjuntoId': ?adjuntoId,
  'fecha': fecha,
};

/// Un ticket entero (el detalle, con su conversación).
Map<String, dynamic> ticketJson({
  String id = 't1',
  String estado = 'EN_PROCESO',
  String categoria = 'TECNICO',
  String severidad = 'MEDIA',
  String asunto = 'No carga el calendario',
  String creadoEn = '2026-09-27T15:19:10.437Z',
  List<Map<String, dynamic>>? mensajes,
}) => {
  '_id': id,
  'usuarioId': 'u1',
  'usuarioNombre': 'Ana María Pérez',
  'usuarioEmail': 'ana@correo.com',
  'categoria': categoria,
  'asunto': asunto,
  'descripcion': 'Al abrir Agendar cita la pantalla queda en blanco.',
  'severidad': severidad,
  'estado': estado,
  'venceEn': '2026-09-30T15:19:10.437Z',
  'vencido': false,
  'vencePronto': false,
  'mensajes':
      mensajes ??
      [
        mensajeTicketJson(
          'm1',
          esSoporte: false,
          texto: 'Adjunto: captura.png',
          fecha: '2026-09-27T15:19:10.590Z',
          adjuntoId: 'arch1',
        ),
        mensajeTicketJson('m2'),
      ],
  'creadoEn': creadoEn,
  'actualizadoEn': '2026-09-27T15:20:13.785Z',
};

/// Un ticket de la lista (sin la conversación, con su resumen).
Map<String, dynamic> resumenTicketJson({
  String id = 't1',
  String estado = 'EN_PROCESO',
  String asunto = 'No carga el calendario',
  String creadoEn = '2026-09-27T15:19:10.437Z',
  String? ultimoMensajeEn = '2026-09-27T15:20:13.785Z',
  bool? ultimoEsSoporte = true,
  int totalMensajes = 2,
}) {
  final completo = ticketJson(
    id: id,
    estado: estado,
    asunto: asunto,
    creadoEn: creadoEn,
  )..remove('mensajes');

  return {
    ...completo,
    'totalMensajes': totalMensajes,
    'ultimoMensajeEn': ?ultimoMensajeEn,
    'ultimoEsSoporte': ?ultimoEsSoporte,
  };
}

/// Una captura de pantalla (bytes de un PNG de verdad).
ArchivoLocal capturaPng([String nombre = 'captura.png']) => ArchivoLocal(
  nombre: nombre,
  bytes: Uint8List.fromList([
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
    ...List.filled(32, 7),
  ]),
);

/// Un archivo que no es de ningún tipo aceptado.
ArchivoLocal videoMp4() =>
    ArchivoLocal(nombre: 'video.mp4', bytes: Uint8List.fromList([1, 2, 3, 4]));
