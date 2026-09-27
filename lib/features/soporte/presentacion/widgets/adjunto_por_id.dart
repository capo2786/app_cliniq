// lib/features/soporte/presentacion/widgets/adjunto_por_id.dart

import 'package:flutter/material.dart';

import '../../../../core/archivos/archivos_service.dart';
import '../../../../core/network/errores.dart';
import '../../../../core/presentacion/avisos.dart';
import '../../../../core/servicios.dart';
import '../../../../core/tema/tokens.dart';
import '../../../consultas/presentacion/widgets/visor_imagen.dart';

/// Abre el adjunto de un mensaje de soporte, del que solo se conoce el
/// identificador: lo baja una sola vez con la sesión y, si es una imagen, la
/// enseña en el visor de la aplicación; si es un PDF, lo abre con el visor
/// del teléfono (la copia queda en la carpeta privada y se borra al salir).
Future<void> abrirAdjuntoPorId(
  BuildContext context,
  String id, {
  ArchivosService? archivos,
}) async {
  final servicio = archivos ?? Servicios.archivos;
  final navegador = Navigator.of(context);
  final raiz = Navigator.of(context, rootNavigator: true);

  // Mientras baja, una rueda que no se puede cerrar: tocar dos veces el
  // mismo archivo lo bajaría dos veces.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Center(
        child: CircularProgressIndicator(color: AppColors.acentoClaro),
      ),
    ),
  );

  ArchivoDescargado? descargado;
  String? problema;

  try {
    descargado = await servicio.descargarConDatos(id);
  } catch (error) {
    problema = mensajeDeError(error, generico: 'No pudimos abrir el archivo.');
  } finally {
    raiz.pop();
  }

  if (descargado == null) {
    if (problema != null && context.mounted) {
      mostrarAviso(context, problema, error: true);
    }
    return;
  }

  final bytes = descargado.bytes;
  final meta = descargado.meta;

  if (meta.esImagen) {
    await navegador.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            VisorDeImagen(archivo: meta, descargar: (_) async => bytes),
      ),
    );
    return;
  }

  try {
    await servicio.abrirBytesConElSistema(meta, bytes);
  } on ErrorAlAbrirArchivo catch (error) {
    if (context.mounted) mostrarAviso(context, error.mensaje, error: true);
  } catch (error) {
    if (context.mounted) {
      mostrarAviso(
        context,
        mensajeDeError(error, generico: 'No pudimos abrir «${meta.nombre}».'),
        error: true,
      );
    }
  }
}
