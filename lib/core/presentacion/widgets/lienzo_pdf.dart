// lib/core/presentacion/widgets/lienzo_pdf.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../tema/tokens.dart';
import 'estados.dart';

/// Cómo se pinta un PDF dentro de la aplicación. Es una interfaz para que
/// las pruebas pongan uno de mentira: el de verdad necesita el lector de PDF
/// del sistema, que en el anfitrión de pruebas no existe.
abstract class PintorDePdf {
  const PintorDePdf();

  /// El PDF guardado en [ruta], con sus páginas una bajo otra.
  Widget pintar(BuildContext context, String ruta);
}

/// El de `pdfx`: el lector de PDF del propio sistema (`PdfRenderer` en
/// Android, PDFKit en iOS) pinta cada página dentro de la aplicación, que
/// se amplía con los dedos. Nada se abre fuera: ni otra aplicación ni el
/// navegador.
class PintorPdfx extends PintorDePdf {
  const PintorPdfx();

  @override
  Widget pintar(BuildContext context, String ruta) {
    if (kIsWeb) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: RecuadroAviso.informacion(
          'Los PDF firmados se ven en la aplicación del teléfono.',
        ),
      );
    }

    return LienzoPdfx(key: ValueKey(ruta), ruta: ruta);
  }
}

/// Un PDF con `PdfViewPinch` y el número de página encima.
class LienzoPdfx extends StatefulWidget {
  final String ruta;

  const LienzoPdfx({super.key, required this.ruta});

  @override
  State<LienzoPdfx> createState() => _LienzoPdfxState();
}

class _LienzoPdfxState extends State<LienzoPdfx> {
  // Se abre desde el archivo y no desde los bytes: con los bytes, pdfx
  // escribe otra copia en la carpeta temporal.
  late final Future<PdfDocument> _documento = PdfDocument.openFile(widget.ruta);
  late final PdfControllerPinch _controlador = PdfControllerPinch(
    document: _documento,
  );

  @override
  void dispose() {
    _controlador.dispose();
    _documento.then((documento) => documento.close()).ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: PdfViewPinch(
            controller: _controlador,
            padding: 12,
            backgroundDecoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(
                loaderSwitchDuration: Duration(milliseconds: 250),
              ),
              documentLoaderBuilder: (_) =>
                  const CargandoCentro(mensaje: 'Abriendo el PDF…'),
              pageLoaderBuilder: (_) => Center(
                child: CircularProgressIndicator(
                  color: AppColors.acentoClaro,
                  strokeWidth: 2.4,
                ),
              ),
              errorBuilder: (_, _) => const Padding(
                padding: EdgeInsets.all(20),
                child: EstadoError(
                  mensaje: 'No pudimos mostrar el PDF en este teléfono.',
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 14,
          bottom: 14,
          child: PdfPageNumber(
            controller: _controlador,
            builder: (_, estado, pagina, total) {
              if (estado != PdfLoadingState.success ||
                  total == null ||
                  total < 2) {
                return const SizedBox.shrink();
              }

              return DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.superficie.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    'Página $pagina de $total',
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
