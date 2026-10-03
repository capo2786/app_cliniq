// lib/features/mi_salud/presentacion/visor_pdf_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/archivos/archivos_service.dart';
import '../../../core/archivos/salida_de_archivos.dart';
import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/lienzo_pdf.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../data/documentos_pdf_service.dart';
import '../data/models/mi_salud.dart';
import '../dominio/reglas_mi_salud.dart';
import '../providers/visor_pdf_cubit.dart';

/// «Receta», «Orden de laboratorio», «Certificado de reposo»: qué es el
/// documento, para el título del visor y el nombre del archivo.
String nombreDelDocumento(
  TipoDocumentoFirmado tipo, [
  DocumentoClinico? documento,
]) => switch (tipo) {
  TipoDocumentoFirmado.receta => 'Receta',
  TipoDocumentoFirmado.orden => nombreDeLaOrden(
    documento is Orden ? documento.tipo : TipoOrden.otro,
  ),
  TipoDocumentoFirmado.certificado => 'Certificado de reposo',
};

/// «Receta UC7F6DB5UU.pdf», «Certificado de reposo 7Q2M.pdf»: el nombre con
/// que se guarda o se comparte el PDF de un documento.
String nombreDelPdf(TipoDocumentoFirmado tipo, DocumentoClinico documento) {
  final codigo = documento.codigoVerificacion.isEmpty
      ? documento.id
      : documento.codigoVerificacion;

  return nombreSeguro('${nombreDelDocumento(tipo, documento)} $codigo.pdf');
}

/// Abre el PDF de una receta, una orden o un certificado en el visor de la
/// aplicación: el firmado o, sin firma, la vista previa.
Future<void> abrirPdfDelDocumento(
  BuildContext context,
  TipoDocumentoFirmado tipo,
  DocumentoClinico documento,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => VisorPdfPage(
        tipo: tipo,
        id: documento.id,
        sha256: documento.firma?.sha256,
        nombreArchivo: nombreDelPdf(tipo, documento),
        titulo: nombreDelDocumento(tipo, documento),
        firmado: documento.firmado,
      ),
    ),
  );
}

/// El PDF de una receta, una orden o un certificado de reposo, **dentro de
/// la aplicación**: se baja con la sesión
/// (`GET /portal/{recetas|ordenes|certificados}/:id/pdf`), queda guardado
/// en el teléfono para verlo sin Internet y se pinta aquí mismo. Nunca se
/// abre en otra aplicación ni en el navegador.
///
/// Si el médico todavía no lo firmó, el servidor entrega la vista previa y
/// arriba se dice; si no la entrega, se enseña su mensaje.
///
/// Abajo, «Guardar en el teléfono» (el diálogo del sistema para elegir
/// dónde) y «Compartir» (la hoja de compartir del sistema): solo si la
/// persona los toca.
class VisorPdfPage extends StatelessWidget {
  final TipoDocumentoFirmado tipo;
  final String id;

  /// La huella del PDF firmado, si el portal la mandó: con ella se abre la
  /// copia guardada sin gastar datos y se comprueba lo que se baja.
  final String? sha256;

  final String nombreArchivo;

  /// El título de la cabecera; sin él, el del tipo («Receta»).
  final String? titulo;

  /// El documento está firmado electrónicamente. Si no, lo que se ve es la
  /// vista previa y arriba se dice.
  final bool firmado;

  /// Por defecto, `Servicios.documentosPdf`.
  final DocumentosPdfService? servicio;

  /// Por defecto, `Servicios.salidaDeArchivos`.
  final SalidaDeArchivos? salida;

  /// Por defecto, `Servicios.pintorDePdf`.
  final PintorDePdf? pintor;

  const VisorPdfPage({
    super.key,
    required this.tipo,
    required this.id,
    required this.nombreArchivo,
    this.sha256,
    this.titulo,
    this.firmado = true,
    this.servicio,
    this.salida,
    this.pintor,
  });

  String get _titulo => titulo ?? nombreDelDocumento(tipo);

  @override
  Widget build(BuildContext context) {
    final fuente = servicio ?? Servicios.documentosPdf;

    return BlocProvider(
      create: (_) => VisorPdfCubit(
        () => fuente.obtener(tipo, id, sha256: sha256),
        salida ?? Servicios.salidaDeArchivos,
        nombreArchivo: nombreArchivo,
        asunto: _titulo,
      )..cargar(),
      child: _VistaVisorPdf(
        titulo: _titulo,
        firmado: firmado,
        pintor: pintor ?? Servicios.pintorDePdf,
      ),
    );
  }
}

class _VistaVisorPdf extends StatelessWidget {
  final String titulo;
  final bool firmado;
  final PintorDePdf pintor;

  const _VistaVisorPdf({
    required this.titulo,
    required this.firmado,
    required this.pintor,
  });

  Future<void> _guardar(BuildContext context) async {
    final resultado = await context.read<VisorPdfCubit>().guardar();
    if (!context.mounted) return;

    switch (resultado) {
      case ResultadoSalida.hecho:
        mostrarAviso(context, 'Guardamos el PDF en tu teléfono.');
      case ResultadoSalida.fallo:
        mostrarAviso(
          context,
          'No pudimos guardar el PDF. Intenta de nuevo.',
          error: true,
        );
      case ResultadoSalida.cancelado:
        break;
    }
  }

  Future<void> _compartir(BuildContext context, Rect? origen) async {
    final resultado = await context.read<VisorPdfCubit>().compartir(
      origen: origen,
    );
    if (!context.mounted) return;

    if (resultado == ResultadoSalida.fallo) {
      mostrarAviso(
        context,
        'No pudimos compartir el PDF. Intenta de nuevo.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VisorPdfCubit, VisorPdfState>(
      builder: (context, state) {
        final pdf = state.pdf;
        final cubit = context.read<VisorPdfCubit>();

        return Scaffold(
          backgroundColor: AppColors.fondo,
          appBar: AppBar(title: Text(titulo)),
          bottomNavigationBar: pdf == null
              ? null
              : BarraDeAccion(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _BotonDeSalida(
                          key: const Key('boton-guardar-pdf'),
                          texto: 'Guardar en el teléfono',
                          icono: Icons.download_rounded,
                          alTocar: state.ocupado
                              ? null
                              : (_) => _guardar(context),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: _BotonDeSalida(
                          key: const Key('boton-compartir-pdf'),
                          texto: 'Compartir',
                          icono: Icons.ios_share_rounded,
                          alTocar: state.ocupado
                              ? null
                              : (origen) => _compartir(context, origen),
                        ),
                      ),
                    ],
                  ),
                ),
          body: switch (state.carga) {
            CargaPdf.listo when pdf != null => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pdf.sinConexion)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: RecuadroAviso.informacion(
                      'Sin conexión: es la copia guardada en este teléfono.',
                      icono: Icons.offline_pin_outlined,
                    ),
                  ),
                if (!firmado || pdf.sinFirma)
                  const Padding(
                    key: Key('aviso-vista-previa'),
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: RecuadroAviso.alerta(
                      'Vista previa: el médico todavía no firmó '
                      'electrónicamente este documento.',
                      icono: Icons.edit_note_rounded,
                    ),
                  ),
                Expanded(
                  child: KeyedSubtree(
                    key: const Key('lienzo-pdf'),
                    child: pintor.pintar(context, pdf.ruta),
                  ),
                ),
              ],
            ),
            CargaPdf.error => ListView(
              padding: context.margenDeScroll(),
              children: [
                EstadoError(
                  mensaje: state.error ?? 'No pudimos abrir el PDF.',
                  alReintentar: cubit.cargar,
                ),
              ],
            ),
            _ => const CargandoCentro(mensaje: 'Descargando el PDF…'),
          },
        );
      },
    );
  }
}

/// «Guardar en el teléfono» o «Compartir»: borde fino, el texto en dos
/// líneas si no cabe. Entrega el rectángulo del botón (la hoja de compartir
/// del iPad se ubica sobre él).
class _BotonDeSalida extends StatelessWidget {
  final String texto;
  final IconData icono;
  final void Function(Rect? origen)? alTocar;

  const _BotonDeSalida({
    super.key,
    required this.texto,
    required this.icono,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primarioClaro;
    final tocar = alTocar;

    return OutlinedButton.icon(
      onPressed: tocar == null
          ? null
          : () {
              final caja = context.findRenderObject();
              tocar(
                caja is RenderBox && caja.hasSize
                    ? caja.localToGlobal(Offset.zero) & caja.size
                    : null,
              );
            },
      icon: Icon(icono, size: 19),
      label: Text(
        texto,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: AppColors.textoTenue,
        minimumSize: const Size.fromHeight(50),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
