// lib/features/mi_salud/data/documentos_pdf_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/archivos/salida_de_archivos.dart';
import '../../../core/network/errores.dart';
import 'models/mi_salud.dart';

/// El PDF de un documento, ya guardado en el teléfono: el firmado o, si el
/// médico todavía no firmó, la vista previa que arma el servidor.
class PdfGuardado extends Equatable {
  final TipoDocumentoFirmado tipo;
  final String id;

  /// Dónde quedó el archivo, dentro de la carpeta privada de la aplicación.
  final String ruta;

  final Uint8List bytes;

  /// La huella sha256 del archivo, calculada en el teléfono.
  final String sha256;

  /// Se abrió la copia del teléfono porque no hubo conexión.
  final bool sinConexion;

  /// El servidor dijo que es la vista previa, sin firma electrónica
  /// (`X-Firma-Estado: SIN_FIRMA`). De una copia guardada no se sabe: lo
  /// dice el documento.
  final bool sinFirma;

  const PdfGuardado({
    required this.tipo,
    required this.id,
    required this.ruta,
    required this.bytes,
    required this.sha256,
    this.sinConexion = false,
    this.sinFirma = false,
  });

  PdfGuardado _sinConexion() => PdfGuardado(
    tipo: tipo,
    id: id,
    ruta: ruta,
    bytes: bytes,
    sha256: sha256,
    sinConexion: true,
  );

  @override
  List<Object?> get props => [tipo, id, ruta, sha256, sinConexion, sinFirma];
}

/// Lo que llegó no es el PDF del documento: no se guarda ni se enseña.
class PdfNoValido implements Exception {
  final String mensaje;

  const PdfNoValido(this.mensaje);

  @override
  String toString() => mensaje;
}

/// El PDF de una receta, una orden o un certificado de reposo:
/// `GET /portal/{recetas|ordenes|certificados}/:id/pdf`, con la sesión.
/// Firmado, el servidor entrega el archivo guardado; sin firma, arma al
/// vuelo la vista previa (y lo dice en `X-Firma-Estado: SIN_FIRMA`). Si la
/// clínica lo entrega solo firmado, responde con su mensaje, que es el que
/// se enseña.
///
/// El servidor guarda el archivo firmado con su sha256 y nunca lo regenera,
/// así que una copia sirve para siempre: cada PDF bajado se guarda en la
/// carpeta de documentos de la aplicación (`cliniq_documentos/`), con el
/// tipo, el identificador y la huella en el nombre
/// (`receta_<id>_<sha256>.pdf`), y se vuelve a abrir sin Internet.
///
/// - Si se conoce la huella del documento firmado (`firma.sha256Firmado`),
///   primero se busca esa copia: se abre sin gastar datos. Lo que se baja
///   tiene que tener esa misma huella; si no, no se guarda.
/// - Sin la huella (sin firma, o un servidor que no la manda), se pide al
///   servidor y, sin conexión, se abre la última copia de ese documento.
///   La vista previa también se guarda: es la última que dio el servidor.
/// - Cada copia se comprueba al leerla contra la huella de su nombre: una
///   copia dañada se borra y no se enseña.
/// - Al cerrar sesión se borra la carpeta entera ([borrarTodo]), y con ella
///   lo que ver, guardar o compartir un PDF deja en la carpeta temporal:
///   son datos de salud y el teléfono puede ser compartido.
class DocumentosPdfService {
  static const String carpetaDeDocumentos = 'cliniq_documentos';

  /// Lo que queda en la carpeta temporal por un PDF: la copia con nombre
  /// legible que se comparte, la que `share_plus` hace en Android y las
  /// páginas que el visor (`pdfx`) pinta como imágenes en Android.
  static const List<String> restosTemporales = [
    SalidaDelSistema.carpetaParaCompartir,
    'share_plus',
    'pdf_renderer_cache',
  ];

  final Dio _dio;
  final Future<Directory> Function() _carpetaBase;
  final Future<Directory> Function() _carpetaTemporal;

  DocumentosPdfService(
    this._dio, {
    Future<Directory> Function()? carpetaBase,
    Future<Directory> Function()? carpetaTemporal,
  }) : _carpetaBase = carpetaBase ?? getApplicationDocumentsDirectory,
       _carpetaTemporal = carpetaTemporal ?? getTemporaryDirectory;

  Future<Directory> _carpeta() async =>
      Directory('${(await _carpetaBase()).path}/$carpetaDeDocumentos');

  /// El PDF firmado del documento: la copia del teléfono si ya se tiene
  /// (con [sha256]) o la descarga, que queda guardada. Sin conexión, la
  /// copia; sin copia, el error de la red.
  Future<PdfGuardado> obtener(
    TipoDocumentoFirmado tipo,
    String id, {
    String? sha256,
  }) async {
    _comprobarId(id);
    final huella = huellaSha256(sha256);

    if (huella != null) {
      final copia = await copiaGuardada(tipo, id, sha256: huella);
      if (copia != null) return copia;
    }

    final ({Uint8List bytes, bool sinFirma}) descarga;
    try {
      descarga = await _descargar(tipo, id);
    } catch (error) {
      if (!esFaltaDeRed(error)) rethrow;

      final copia = await copiaGuardada(tipo, id, sha256: huella);
      if (copia == null) rethrow;

      return copia._sinConexion();
    }

    final bytes = descarga.bytes;
    if (!_esPdf(bytes)) {
      throw const PdfNoValido(
        'Lo que llegó del servidor no es un PDF. Intenta de nuevo más tarde.',
      );
    }

    final calculada = crypto.sha256.convert(bytes).toString();
    if (huella != null && calculada != huella) {
      throw const PdfNoValido(
        'El PDF que llegó no coincide con el documento firmado. Intenta de '
        'nuevo más tarde.',
      );
    }

    final ruta = await _guardar(tipo, id, calculada, bytes);

    return PdfGuardado(
      tipo: tipo,
      id: id,
      ruta: ruta,
      bytes: bytes,
      sha256: calculada,
      sinFirma: descarga.sinFirma,
    );
  }

  /// La copia guardada de ese documento, si hay una sana: con [sha256], solo
  /// la de esa huella; sin ella, la más reciente.
  Future<PdfGuardado?> copiaGuardada(
    TipoDocumentoFirmado tipo,
    String id, {
    String? sha256,
  }) async {
    if (kIsWeb) return null;
    _comprobarId(id);

    final huella = huellaSha256(sha256);

    try {
      final carpeta = await _carpeta();
      if (!await carpeta.exists()) return null;

      final candidatas = <File>[
        await for (final entrada in carpeta.list())
          if (entrada is File && _huellaDelNombre(entrada, tipo, id) != null)
            entrada,
      ];

      if (huella != null) {
        candidatas.retainWhere(
          (archivo) => _huellaDelNombre(archivo, tipo, id) == huella,
        );
      }

      final conFecha = [
        for (final archivo in candidatas)
          (archivo: archivo, cuando: await archivo.lastModified()),
      ]..sort((a, b) => b.cuando.compareTo(a.cuando));

      for (final (:archivo, cuando: _) in conFecha) {
        final esperada = _huellaDelNombre(archivo, tipo, id)!;
        final bytes = await archivo.readAsBytes();

        if (crypto.sha256.convert(bytes).toString() != esperada) {
          // Dañada: no se enseña un documento clínico que no es el firmado.
          await _borrar(archivo);
          continue;
        }

        return PdfGuardado(
          tipo: tipo,
          id: id,
          ruta: archivo.path,
          bytes: bytes,
          sha256: esperada,
        );
      }
    } catch (error) {
      debugPrint('Cliniq · no se pudo leer la copia del PDF: $error');
    }

    return null;
  }

  /// Borra todos los PDF guardados y sus restos temporales: al cerrar
  /// sesión o al vencer la sesión.
  Future<void> borrarTodo() async {
    if (kIsWeb) return;

    Future<void> borrarCarpeta(Future<Directory> Function() cual) async {
      try {
        final carpeta = await cual();
        if (await carpeta.exists()) await carpeta.delete(recursive: true);
      } catch (error) {
        debugPrint('Cliniq · no se pudieron borrar los PDF guardados: $error');
      }
    }

    await borrarCarpeta(_carpeta);
    for (final resto in restosTemporales) {
      await borrarCarpeta(
        () async => Directory('${(await _carpetaTemporal()).path}/$resto'),
      );
    }
  }

  Future<({Uint8List bytes, bool sinFirma})> _descargar(
    TipoDocumentoFirmado tipo,
    String id,
  ) async {
    try {
      final respuesta = await _dio.get<List<int>>(
        '/portal/${tipo.ruta}/$id/pdf',
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Accept': 'application/pdf'},
          // Un PDF con datos móviles tarda más que una lista de citas.
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      final datos = respuesta.data;
      final estado = respuesta.headers.value('x-firma-estado');

      return (
        bytes: datos == null
            ? Uint8List(0)
            : (datos is Uint8List ? datos : Uint8List.fromList(datos)),
        sinFirma: estado?.trim().toUpperCase() == 'SIN_FIRMA',
      );
    } on DioException catch (error) {
      throw _conMensajeLegible(error);
    }
  }

  Future<String> _guardar(
    TipoDocumentoFirmado tipo,
    String id,
    String huella,
    Uint8List bytes,
  ) async {
    final carpeta = await _carpeta();
    await carpeta.create(recursive: true);

    final nombre = _nombre(tipo, id, huella);
    final definitivo = File('${carpeta.path}/$nombre');

    // Primero a un temporal y después se renombra: un corte a mitad de la
    // escritura no deja un PDF a medias con nombre de bueno.
    final temporal = File('${definitivo.path}.part');
    await temporal.writeAsBytes(bytes, flush: true);
    await temporal.rename(definitivo.path);

    // Las copias viejas de ese mismo documento sobran.
    await for (final entrada in carpeta.list()) {
      if (entrada is File &&
          entrada.path != definitivo.path &&
          _huellaDelNombre(entrada, tipo, id) != null) {
        await _borrar(entrada);
      }
    }

    return definitivo.path;
  }

  Future<void> _borrar(File archivo) async {
    try {
      await archivo.delete();
    } catch (_) {
      // Si no se puede borrar ahora, se intenta al cerrar sesión.
    }
  }
}

final RegExp _idValido = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

/// El identificador va en el nombre del archivo y en la ruta: solo letras,
/// números, `_` y `-` (los de Mongo son hexadecimales).
void _comprobarId(String id) {
  if (!_idValido.hasMatch(id)) {
    throw const PdfNoValido('Este documento no tiene un identificador válido.');
  }
}

String _nombre(TipoDocumentoFirmado tipo, String id, String huella) =>
    '${tipo.prefijo}_${id}_$huella.pdf';

/// La huella escrita en el nombre de una copia de ese documento, o `null`
/// si el archivo no es una copia suya.
String? _huellaDelNombre(File archivo, TipoDocumentoFirmado tipo, String id) {
  final nombre = archivo.uri.pathSegments.last;
  final inicio = '${tipo.prefijo}_${id}_';

  if (!nombre.startsWith(inicio) || !nombre.endsWith('.pdf')) return null;

  return huellaSha256(
    nombre.substring(inicio.length, nombre.length - '.pdf'.length),
  );
}

/// Empieza con `%PDF-`.
bool _esPdf(Uint8List bytes) =>
    bytes.length > 5 &&
    bytes[0] == 0x25 &&
    bytes[1] == 0x50 &&
    bytes[2] == 0x44 &&
    bytes[3] == 0x46 &&
    bytes[4] == 0x2d;

/// Un error del servidor que llegó como bytes (se pidió un PDF) con su
/// `{status, message}` ya leído, para que `mensajeDeError` lo entienda.
DioException _conMensajeLegible(DioException error) {
  final respuesta = error.response;
  final datos = respuesta?.data;
  if (respuesta == null || datos is! List<int>) return error;

  try {
    final leido = jsonDecode(utf8.decode(datos));
    if (leido is! Map) return error;

    return error.copyWith(
      response: Response<dynamic>(
        requestOptions: respuesta.requestOptions,
        statusCode: respuesta.statusCode,
        statusMessage: respuesta.statusMessage,
        headers: respuesta.headers,
        data: leido,
      ),
    );
  } catch (_) {
    return error;
  }
}
