import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'archivo_meta.dart';

/// Lo más grande que acepta la API por archivo: 20 MB.
const int tamanoMaximoArchivo = 20 * 1024 * 1024;

/// Los tipos que acepta la API, con sus extensiones.
const Map<String, List<String>> extensionesPermitidas = {
  'application/pdf': ['pdf'],
  'image/jpeg': ['jpg', 'jpeg'],
  'image/png': ['png'],
};

/// Un archivo elegido en el teléfono que todavía no se subió.
///
/// Se guardan los bytes y no la ruta: una foto recién tomada vive en una
/// carpeta temporal que el sistema puede vaciar, y en la web no hay rutas.
class ArchivoLocal extends Equatable {
  final String nombre;
  final Uint8List bytes;

  const ArchivoLocal({required this.nombre, required this.bytes});

  int get tamano => bytes.length;

  /// El tipo según el contenido, o `null` si no es PDF, JPG ni PNG.
  String? get mime => tipoPorContenido(bytes);

  bool get esImagen => mime?.startsWith('image/') ?? false;

  /// El nombre con la extensión que corresponde a su contenido.
  String get nombreParaSubir => nombreConExtension(nombre, mime);

  @override
  List<Object?> get props => [nombre, tamano, bytes];
}

/// El tipo de un archivo según sus primeros bytes (su «firma»), como lo
/// decide el servidor: la extensión y lo que diga el teléfono no cuentan.
String? tipoPorContenido(List<int> bytes) {
  bool empieza(List<int> firma) {
    if (bytes.length < firma.length) return false;
    for (var i = 0; i < firma.length; i++) {
      if (bytes[i] != firma[i]) return false;
    }
    return true;
  }

  if (empieza(const [0x25, 0x50, 0x44, 0x46, 0x2d])) return 'application/pdf';
  if (empieza(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return 'image/png';
  }
  if (empieza(const [0xff, 0xd8, 0xff])) return 'image/jpeg';

  return null;
}

/// Por qué no se puede subir un archivo, o `null` si se puede.
///
/// Se comprueba **antes** de subirlo, con las mismas reglas del servidor
/// (PDF, JPG o PNG por su contenido, hasta 20 MB): esperar a que suban veinte
/// megas para enterarse de que no valían es tiempo y datos perdidos.
String? problemaDelArchivo(ArchivoLocal archivo) {
  if (archivo.tamano == 0) {
    return '«${archivo.nombre}» está vacío.';
  }

  if (archivo.tamano > tamanoMaximoArchivo) {
    return '«${archivo.nombre}» pesa ${tamanoLegible(archivo.tamano)} y el '
        'máximo es 20 MB.';
  }

  if (archivo.mime == null) {
    return '«${archivo.nombre}» no es un PDF, JPG ni PNG. Solo se aceptan '
        'esos formatos.';
  }

  return null;
}

/// El nombre con la extensión de su contenido.
///
/// El servidor rechaza un archivo cuya extensión no coincide con lo que
/// contiene, y el teléfono a veces cambia uno sin cambiar el otro (una foto
/// PNG que al comprimirse pasa a JPG). Se corrige aquí en vez de fallar allá.
String nombreConExtension(String nombre, String? mime) {
  final base = nombre.trim().isEmpty ? 'archivo' : nombre.trim();
  final extensiones = extensionesPermitidas[mime];
  if (extensiones == null) return base;

  final punto = base.lastIndexOf('.');
  final actual = punto < 0 ? '' : base.substring(punto + 1).toLowerCase();

  if (extensiones.contains(actual)) return base;

  // «foto.heic» pasa a «foto.jpg»; «informe.de.marzo» no tenía extensión y
  // queda «informe.de.marzo.pdf».
  final tieneExtension =
      punto > 0 && RegExp(r'^[a-z0-9]{1,4}$').hasMatch(actual);
  final sinExtension = tieneExtension ? base.substring(0, punto) : base;

  return '$sinExtension.${extensiones.first}';
}
