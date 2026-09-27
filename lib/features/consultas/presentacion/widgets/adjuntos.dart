import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/archivos/archivo_meta.dart';
import '../../../../core/archivos/archivos_service.dart';
import '../../../../core/archivos/selector_de_archivos.dart';
import '../../../../core/network/errores.dart';
import '../../../../core/presentacion/avisos.dart';
import '../../../../core/servicios.dart';
import '../../../../core/tema/tokens.dart';
import 'visor_imagen.dart';

/// De dónde sacar un archivo.
enum OrigenDeArchivo { camara, galeria, archivos }

/// Pregunta de dónde sacar el archivo y lo trae: la cámara, la galería o los
/// archivos del teléfono. `null` si la persona cerró la hoja sin elegir.
///
/// Con [varios], la galería y los archivos dejan elegir más de uno.
Future<SeleccionDeArchivos?> elegirArchivos(
  BuildContext context, {
  bool varios = true,
  SelectorDeArchivos? selector,
}) async {
  final origen = await showModalBottomSheet<OrigenDeArchivo>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (contexto) => _HojaDeOrigen(varios: varios),
  );

  if (origen == null) return null;

  final elegir = selector ?? Servicios.selectorDeArchivos;

  try {
    return switch (origen) {
      OrigenDeArchivo.camara => await elegir.tomarFoto(),
      OrigenDeArchivo.galeria => await elegir.elegirFotos(),
      OrigenDeArchivo.archivos => await elegir.elegirDocumentos(),
    };
  } on PlatformException catch (error) {
    // Sin permiso de cámara, sin cámara, o el selector no abrió.
    final permiso = error.code.contains('denied');

    return SeleccionDeArchivos(
      problemas: [
        switch (origen) {
          OrigenDeArchivo.camara =>
            permiso
                ? 'Cliniq no tiene permiso para usar la cámara. Actívalo en los '
                      'ajustes del teléfono.'
                : 'No pudimos abrir la cámara.',
          OrigenDeArchivo.galeria =>
            permiso
                ? 'Cliniq no tiene permiso para ver tus fotos. Actívalo en los '
                      'ajustes del teléfono.'
                : 'No pudimos abrir la galería.',
          OrigenDeArchivo.archivos => 'No pudimos abrir tus archivos.',
        },
      ],
    );
  } catch (_) {
    return const SeleccionDeArchivos(
      problemas: ['No pudimos traer el archivo. Intenta de nuevo.'],
    );
  }
}

class _HojaDeOrigen extends StatelessWidget {
  final bool varios;

  const _HojaDeOrigen({required this.varios});

  @override
  Widget build(BuildContext context) {
    Widget opcion(
      OrigenDeArchivo origen,
      IconData icono,
      String titulo,
      String descripcion,
    ) {
      return ListTile(
        onTap: () => Navigator.of(context).pop(origen),
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primarioClaro.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icono, color: AppColors.primarioClaro, size: 21),
        ),
        title: Text(
          titulo,
          style: const TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
          ),
        ),
        subtitle: Text(
          descripcion,
          style: const TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 12,
          ),
        ),
      );
    }

    // Con el texto del sistema agrandado la hoja crece: se desplaza en vez de
    // cortarse.
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 14, bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.bordeCampo,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 16, 22, 4),
            child: Text(
              'Adjuntar un archivo',
              style: TextStyle(
                color: AppColors.texto,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 0, 22, 8),
            child: Text(
              'PDF, JPG o PNG de hasta 20 MB. Las fotos se reducen para que '
              'suban rápido sin perder lo que se lee.',
              style: TextStyle(
                color: AppColors.textoSecundario,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
          opcion(
            OrigenDeArchivo.camara,
            Icons.photo_camera_outlined,
            'Tomar una foto',
            'De una receta, un examen o una lesión',
          ),
          opcion(
            OrigenDeArchivo.galeria,
            Icons.photo_library_outlined,
            varios ? 'Elegir fotos' : 'Elegir una foto',
            'De la galería del teléfono',
          ),
          opcion(
            OrigenDeArchivo.archivos,
            Icons.picture_as_pdf_outlined,
            varios ? 'Elegir archivos' : 'Elegir un archivo',
            'Un PDF o una imagen guardada',
          ),
        ],
      ),
    );
  }
}

/// Un archivo en una lista: tipo, nombre, tamaño y lo que se puede hacer.
class FilaAdjunto extends StatelessWidget {
  final String nombre;
  final int tamano;
  final bool esImagen;

  /// Una línea más bajo el tamaño: «Se sube al enviar».
  final String? nota;

  final VoidCallback? onTap;
  final VoidCallback? alQuitar;

  /// Se está quitando: la papelera cambia por una rueda.
  final bool quitando;

  const FilaAdjunto({
    super.key,
    required this.nombre,
    required this.tamano,
    required this.esImagen,
    this.nota,
    this.onTap,
    this.alQuitar,
    this.quitando = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = esImagen ? AppColors.celeste : AppColors.acentoClaro;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: AppColors.campo,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.bordeCampo),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  esImagen
                      ? Icons.image_outlined
                      : Icons.picture_as_pdf_outlined,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [tamanoLegible(tamano), ?nota].join(' · '),
                      style: const TextStyle(
                        color: AppColors.textoSecundario,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (quitando)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.acentoClaro,
                    ),
                  ),
                )
              else if (alQuitar != null)
                IconButton(
                  tooltip: 'Quitar $nombre',
                  onPressed: alQuitar,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textoSecundario,
                    size: 20,
                  ),
                )
              else if (onTap != null)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.open_in_new_rounded,
                    color: AppColors.textoSecundario,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre un archivo de la clínica: una imagen en el visor de la aplicación,
/// un PDF con el visor del teléfono.
Future<void> abrirArchivo(BuildContext context, ArchivoMeta archivo) async {
  if (archivo.esImagen) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisorDeImagen(archivo: archivo),
        fullscreenDialog: true,
      ),
    );
    return;
  }

  final navegador = Navigator.of(context, rootNavigator: true);

  // Mientras baja, una rueda que no se puede cerrar: tocar dos veces el
  // mismo PDF lo bajaría dos veces.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: Center(
        child: CircularProgressIndicator(color: AppColors.acentoClaro),
      ),
    ),
  );

  String? problema;

  try {
    await Servicios.archivos.abrirConElSistema(archivo);
  } on ErrorAlAbrirArchivo catch (error) {
    problema = error.mensaje;
  } catch (error) {
    problema = mensajeDeError(
      error,
      generico: 'No pudimos abrir «${archivo.nombre}».',
    );
  } finally {
    navegador.pop();
  }

  if (problema != null && context.mounted) {
    mostrarAviso(context, problema, error: true);
  }
}
