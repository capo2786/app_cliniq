import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../configuracion/config_publica.dart';
import 'archivo_meta.dart';

/*
 * El tope de tamaño y los tipos que se aceptan son los de la configuración
 * de la clínica (`archivos.tamanoMaximoMb`, `archivos.tipos`). Lo que queda
 * aquí es la regla técnica: cómo se reconoce cada tipo por su contenido
 * («bytes mágicos», la misma verificación del servidor), con qué extensión
 * se nombra y cómo se llama cada formato.
 */

/// Los tipos que la aplicación sabe reconocer por su contenido, con sus
/// extensiones (la primera es la que se usa al corregir un nombre).
const Map<String, List<String>> extensionesPorTipo = {
  'application/pdf': ['pdf'],
  'image/jpeg': ['jpg', 'jpeg'],
  'image/png': ['png'],
  'image/webp': ['webp'],
  'image/heic': ['heic', 'heif'],
};

/// El nombre corto de cada formato, para decirlo en una frase.
const Map<String, String> nombresDeFormato = {
  'application/pdf': 'PDF',
  'image/jpeg': 'JPG',
  'image/png': 'PNG',
  'image/webp': 'WEBP',
  'image/heic': 'HEIC',
};

/// «PDF, JPG o PNG» (o «PDF, JPG ni PNG» con [conjuncion] `ni`): los
/// formatos aceptados, en palabras.
String formatosLegibles(List<String> tipos, {String conjuncion = 'o'}) {
  final nombres = [
    for (final tipo in tipos) nombresDeFormato[tipo.toLowerCase()] ?? tipo,
  ];

  if (nombres.isEmpty) return '';
  if (nombres.length == 1) return nombres.first;

  return '${nombres.sublist(0, nombres.length - 1).join(', ')} $conjuncion '
      '${nombres.last}';
}

/// «PDF, JPG o PNG de hasta 20 MB»: lo que se puede adjuntar.
String loQueSePuedeAdjuntar(ReglasArchivos reglas) =>
    '${formatosLegibles(reglas.tipos)} de hasta ${reglas.tamanoMaximoMb} MB';

/// Un archivo elegido en el teléfono que todavía no se subió.
///
/// Se guardan los bytes y no la ruta: una foto recién tomada vive en una
/// carpeta temporal que el sistema puede vaciar, y en la web no hay rutas.
class ArchivoLocal extends Equatable {
  final String nombre;
  final Uint8List bytes;

  const ArchivoLocal({required this.nombre, required this.bytes});

  int get tamano => bytes.length;

  /// El tipo según el contenido, o `null` si no es ninguno de los que la
  /// aplicación sabe reconocer.
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

  // WebP: «RIFF», cuatro bytes de tamaño y «WEBP».
  if (empieza(const [0x52, 0x49, 0x46, 0x46]) &&
      bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }

  // HEIC/HEIF: una caja «ftyp» con una de sus marcas.
  if (bytes.length >= 12 &&
      String.fromCharCodes(bytes.sublist(4, 8)) == 'ftyp' &&
      const {
        'heic',
        'heix',
        'hevc',
        'hevx',
        'heim',
        'heis',
        'mif1',
        'msf1',
      }.contains(String.fromCharCodes(bytes.sublist(8, 12)))) {
    return 'image/heic';
  }

  return null;
}

/// Por qué no se puede subir un archivo, o `null` si se puede.
///
/// Se comprueba **antes** de subirlo, con las mismas reglas del servidor
/// (los tipos que acepta la clínica, reconocidos por su contenido, y su tope
/// de tamaño): esperar a que suban veinte megas para enterarse de que no
/// valían es tiempo y datos perdidos.
String? problemaDelArchivo(ArchivoLocal archivo, ReglasArchivos reglas) {
  if (archivo.tamano == 0) {
    return '«${archivo.nombre}» está vacío.';
  }

  if (archivo.tamano > reglas.tamanoMaximoBytes) {
    return demasiadoGrande(archivo.nombre, archivo.tamano, reglas);
  }

  final mime = archivo.mime;
  if (mime == null || !reglas.tipos.contains(mime)) {
    return '«${archivo.nombre}» no es un '
        '${formatosLegibles(reglas.tipos, conjuncion: 'ni')}. Solo se aceptan '
        'esos formatos.';
  }

  return null;
}

/// «“video.mp4” pesa 80 MB y el máximo es 20 MB.»
String demasiadoGrande(String nombre, int tamano, ReglasArchivos reglas) =>
    '«$nombre» pesa ${tamanoLegible(tamano)} y el máximo es '
    '${reglas.tamanoMaximoMb} MB.';

/// El nombre con la extensión de su contenido.
///
/// El servidor rechaza un archivo cuya extensión no coincide con lo que
/// contiene, y el teléfono a veces cambia uno sin cambiar el otro (una foto
/// PNG que al comprimirse pasa a JPG). Se corrige aquí en vez de fallar allá.
String nombreConExtension(String nombre, String? mime) {
  final base = nombre.trim().isEmpty ? 'archivo' : nombre.trim();
  final extensiones = extensionesPorTipo[mime];
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
