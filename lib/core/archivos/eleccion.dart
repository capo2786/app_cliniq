// lib/core/archivos/eleccion.dart

import '../configuracion/config_publica.dart';
import 'archivo_local.dart';
import 'selector_de_archivos.dart';

/// Lo que queda de una elección cuando cabe un solo archivo (un mensaje, un
/// ticket nuevo): el archivo, o por qué no hay ninguno.
class UnSoloArchivo {
  final ArchivoLocal? archivo;

  /// Por qué no se puede usar lo elegido; `null` si no hay nada que decir
  /// (se cerró el selector sin elegir).
  final String? problema;

  /// Se eligió más de uno y se tomó el primero.
  final bool habiaVarios;

  const UnSoloArchivo({this.archivo, this.problema, this.habiaVarios = false});
}

/// Toma el primer archivo de [seleccion] y lo valida con las reglas de la
/// clínica (tipos y tamaño), antes de subir nada.
UnSoloArchivo unSoloArchivo(
  SeleccionDeArchivos seleccion,
  ReglasArchivos reglas,
) {
  if (seleccion.archivos.isEmpty) {
    return UnSoloArchivo(
      problema: seleccion.problemas.isEmpty
          ? null
          : seleccion.problemas.join('\n'),
    );
  }

  final archivo = seleccion.archivos.first;
  final problema = problemaDelArchivo(archivo, reglas);
  if (problema != null) return UnSoloArchivo(problema: problema);

  return UnSoloArchivo(
    archivo: archivo,
    habiaVarios: seleccion.archivos.length > 1,
  );
}
