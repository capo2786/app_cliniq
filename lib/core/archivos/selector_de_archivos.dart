import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../configuracion/config_publica.dart';
import 'archivo_local.dart';

/// Lo que se eligió: los archivos que se pudieron leer y, de los que no, por
/// qué.
class SeleccionDeArchivos {
  final List<ArchivoLocal> archivos;
  final List<String> problemas;

  const SeleccionDeArchivos({
    this.archivos = const [],
    this.problemas = const [],
  });

  static const SeleccionDeArchivos nada = SeleccionDeArchivos();

  bool get vacia => archivos.isEmpty && problemas.isEmpty;
}

/// De dónde salen los adjuntos: la cámara, la galería o los archivos.
///
/// Las [reglas] son las de la configuración de la clínica: qué tipos se
/// pueden elegir y hasta qué tamaño. Es una interfaz para que las pruebas
/// elijan «archivos» sin cámara ni selector del sistema.
abstract class SelectorDeArchivos {
  Future<SeleccionDeArchivos> tomarFoto(ReglasArchivos reglas);

  Future<SeleccionDeArchivos> elegirFotos(ReglasArchivos reglas);

  Future<SeleccionDeArchivos> elegirDocumentos(ReglasArchivos reglas);
}

/// El identificador de tipo de iOS de cada tipo MIME que se sabe reconocer.
const Map<String, String> _identificadoresDeTipo = {
  'application/pdf': 'com.adobe.pdf',
  'image/jpeg': 'public.jpeg',
  'image/png': 'public.png',
  'image/webp': 'org.webmproject.webp',
  'image/heic': 'public.heic',
};

/// Los selectores del teléfono.
///
/// Las fotos se reducen **al elegirlas**: `image_picker` las vuelve a
/// comprimir en el propio teléfono, sin librerías de imagen en Dart. Una foto
/// de 12 megapíxeles pasa de 5–8 MB a menos de uno y medio, sube en segundos
/// con datos móviles y a 2560 px de lado una receta o un examen se siguen
/// leyendo sin esfuerzo.
class SelectorDelSistema implements SelectorDeArchivos {
  static const int calidadFotos = 85;
  static const double ladoMaximoFotos = 2560;

  final ImagePicker _fotos;

  SelectorDelSistema([ImagePicker? fotos]) : _fotos = fotos ?? ImagePicker();

  @override
  Future<SeleccionDeArchivos> tomarFoto(ReglasArchivos reglas) async {
    final foto = await _fotos.pickImage(
      source: ImageSource.camera,
      imageQuality: calidadFotos,
      maxWidth: ladoMaximoFotos,
      maxHeight: ladoMaximoFotos,
      requestFullMetadata: false,
    );

    return foto == null ? SeleccionDeArchivos.nada : _leer([foto], reglas);
  }

  @override
  Future<SeleccionDeArchivos> elegirFotos(ReglasArchivos reglas) async {
    final fotos = await _fotos.pickMultiImage(
      imageQuality: calidadFotos,
      maxWidth: ladoMaximoFotos,
      maxHeight: ladoMaximoFotos,
      // Sin pedir los metadatos completos, iOS no necesita el permiso de la
      // fototeca para elegir: basta con su selector.
      requestFullMetadata: false,
    );

    return _leer(fotos, reglas);
  }

  @override
  Future<SeleccionDeArchivos> elegirDocumentos(ReglasArchivos reglas) async {
    final conocidos = [
      for (final tipo in reglas.tipos)
        if (extensionesPorTipo.containsKey(tipo)) tipo,
    ];

    final tipos = XTypeGroup(
      label: formatosLegibles(conocidos),
      extensions: [for (final t in conocidos) ...extensionesPorTipo[t]!],
      mimeTypes: conocidos,
      uniformTypeIdentifiers: [
        for (final t in conocidos) ?_identificadoresDeTipo[t],
      ],
    );

    final archivos = await openFiles(acceptedTypeGroups: [tipos]);

    return _leer(archivos, reglas);
  }

  /// Lee los bytes de lo elegido. Lo que pasa del tope de la clínica ni se
  /// lee: no se va a poder subir y cargarlo en memoria solo gastaría batería.
  Future<SeleccionDeArchivos> _leer(
    List<XFile> elegidos,
    ReglasArchivos reglas,
  ) async {
    final archivos = <ArchivoLocal>[];
    final problemas = <String>[];

    for (final elegido in elegidos) {
      try {
        final tamano = await elegido.length();

        if (tamano > reglas.tamanoMaximoBytes) {
          problemas.add(demasiadoGrande(elegido.name, tamano, reglas));
          continue;
        }

        archivos.add(
          ArchivoLocal(
            nombre: elegido.name,
            bytes: await elegido.readAsBytes(),
          ),
        );
      } catch (error) {
        debugPrint('Cliniq · no se pudo leer un adjunto: $error');
        problemas.add('No pudimos leer «${elegido.name}».');
      }
    }

    return SeleccionDeArchivos(archivos: archivos, problemas: problemas);
  }
}
