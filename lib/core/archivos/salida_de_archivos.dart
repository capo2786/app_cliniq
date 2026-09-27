// lib/core/archivos/salida_de_archivos.dart

import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Sacar del teléfono un archivo que la aplicación ya tiene guardado:
/// guardar una copia donde la persona elija o compartirlo.
///
/// Solo lo hace cuando la persona lo pide con su botón. Ver un documento
/// nunca pasa por aquí: se ve dentro de la aplicación.
abstract class SalidaDeArchivos {
  /// Abre el diálogo del sistema para guardar una copia (en Android, el de
  /// «Guardar en…» de documentos; en iOS, el de Archivos). `true` si se
  /// guardó; `false` si la persona lo cerró sin guardar.
  Future<bool> guardarEnElTelefono({
    required String ruta,
    required String nombre,
    required String mime,
  });

  /// Abre la hoja de compartir del sistema con el archivo. [origen] es el
  /// rectángulo del botón, que el iPad necesita para ubicar la hoja.
  Future<void> compartir({
    required String ruta,
    required String nombre,
    required String mime,
    String? asunto,
    Rect? origen,
  });
}

/// La del teléfono: `flutter_file_dialog` para guardar y `share_plus` para
/// compartir.
class SalidaDelSistema implements SalidaDeArchivos {
  /// Dentro de la carpeta temporal: la copia con el nombre legible que se
  /// comparte. Se borra al cerrar sesión (ver `DocumentosPdfService`).
  static const String carpetaParaCompartir = 'cliniq_compartir';

  const SalidaDelSistema();

  @override
  Future<bool> guardarEnElTelefono({
    required String ruta,
    required String nombre,
    required String mime,
  }) async {
    try {
      final destino = await FlutterFileDialog.saveFile(
        params: SaveFileDialogParams(
          sourceFilePath: ruta,
          fileName: nombre,
          mimeTypesFilter: [mime],
        ),
      );

      return destino != null;
    } finally {
      // En iOS el diálogo deja una copia con ese nombre en la carpeta
      // temporal del sistema: ya no hace falta.
      if (!kIsWeb && Platform.isIOS) {
        await _borrar(File('${Directory.systemTemp.path}/$nombre'));
      }
    }
  }

  @override
  Future<void> compartir({
    required String ruta,
    required String nombre,
    required String mime,
    String? asunto,
    Rect? origen,
  }) async {
    // Se comparte una copia con un nombre que se entienda («Receta
    // UC7F6DB5UU.pdf»), no el nombre interno con la huella.
    final carpeta = Directory(
      '${(await getTemporaryDirectory()).path}/$carpetaParaCompartir',
    );
    if (await carpeta.exists()) await carpeta.delete(recursive: true);
    await carpeta.create(recursive: true);

    final copia = await File(ruta).copy('${carpeta.path}/$nombre');

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(copia.path, mimeType: mime, name: nombre)],
        subject: asunto,
        title: asunto,
        sharePositionOrigin: origen,
      ),
    );
  }

  static Future<void> _borrar(File archivo) async {
    try {
      if (await archivo.exists()) await archivo.delete();
    } catch (_) {
      // Lo borra el sistema cuando necesite espacio.
    }
  }
}
