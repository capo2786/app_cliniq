// test/dobles/pdf.dart

/// Dobles del PDF firmado: el servicio que lo baja, la salida del sistema
/// (guardar y compartir) y el lienzo que lo pinta. En el anfitrión de
/// pruebas no hay lector de PDF, ni diálogo de guardar, ni hoja de
/// compartir.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:app_cliniq/core/archivos/salida_de_archivos.dart';
import 'package:app_cliniq/core/presentacion/widgets/lienzo_pdf.dart';
import 'package:app_cliniq/features/mi_salud/data/documentos_pdf_service.dart';
import 'package:app_cliniq/features/mi_salud/data/models/mi_salud.dart';
import 'package:flutter/material.dart';

/// Un PDF pequeño, que empieza como empiezan los PDF.
Uint8List pdfDePrueba([String contenido = 'receta firmada']) =>
    Uint8List.fromList(utf8.encode('%PDF-1.7\n% $contenido\n%%EOF\n'));

/// Lo que devuelve el servicio de mentira.
PdfGuardado pdfGuardado({
  TipoDocumentoFirmado tipo = TipoDocumentoFirmado.receta,
  String id = 'r1',
  bool sinConexion = false,
}) => PdfGuardado(
  tipo: tipo,
  id: id,
  ruta: '/documentos/${tipo.prefijo}_$id.pdf',
  bytes: pdfDePrueba(),
  sha256: 'ab' * 32,
  sinConexion: sinConexion,
);

/// El servicio de PDF con respuestas programadas; anota cada pedido.
class PdfFalso implements DocumentosPdfService {
  Future<PdfGuardado> Function(TipoDocumentoFirmado tipo, String id) responder;

  final List<({TipoDocumentoFirmado tipo, String id, String? sha256})> pedidos =
      [];

  var borrados = 0;

  PdfFalso([
    Future<PdfGuardado> Function(TipoDocumentoFirmado tipo, String id)?
    responder,
  ]) : responder =
           responder ?? ((tipo, id) async => pdfGuardado(tipo: tipo, id: id));

  @override
  Future<PdfGuardado> obtener(
    TipoDocumentoFirmado tipo,
    String id, {
    String? sha256,
  }) {
    pedidos.add((tipo: tipo, id: id, sha256: sha256));
    return responder(tipo, id);
  }

  @override
  Future<PdfGuardado?> copiaGuardada(
    TipoDocumentoFirmado tipo,
    String id, {
    String? sha256,
  }) async => null;

  @override
  Future<void> borrarTodo() async => borrados++;
}

/// La salida del sistema de mentira: anota lo que se guardó y compartió.
class SalidaFalsa implements SalidaDeArchivos {
  /// Lo que devuelve «Guardar» (`false`: la persona cerró el diálogo).
  bool guardar = true;

  /// Si se pone, «Guardar» y «Compartir» fallan con esto.
  Object? error;

  final List<({String ruta, String nombre, String mime})> guardados = [];
  final List<
    ({String ruta, String nombre, String mime, String? asunto, Rect? origen})
  >
  compartidos = [];

  @override
  Future<bool> guardarEnElTelefono({
    required String ruta,
    required String nombre,
    required String mime,
  }) async {
    if (error != null) throw error!;
    guardados.add((ruta: ruta, nombre: nombre, mime: mime));
    return guardar;
  }

  @override
  Future<void> compartir({
    required String ruta,
    required String nombre,
    required String mime,
    String? asunto,
    Rect? origen,
  }) async {
    if (error != null) throw error!;
    compartidos.add((
      ruta: ruta,
      nombre: nombre,
      mime: mime,
      asunto: asunto,
      origen: origen,
    ));
  }
}

/// Pinta el nombre del archivo en vez del PDF.
class PintorFalso extends PintorDePdf {
  const PintorFalso();

  @override
  Widget pintar(BuildContext context, String ruta) =>
      Center(child: Text('PDF: $ruta'));
}
