// lib/features/mi_salud/presentacion/widgets/vista_documento.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/margenes.dart';
import '../../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/fondo_app.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/mi_salud.dart';
import '../../providers/documento_cubit.dart';
import '../../../ayuda/presentacion/widgets/boton_ayuda.dart';

/// El esqueleto de una receta, una orden o un certificado abierto: la
/// barra, lo que se dice mientras carga o si falla, la copia guardada y
/// deslizar para ponerlo al día. El contenido lo pone cada pantalla.
///
/// Con [alVerPdf], si el documento sigue vigente, abajo va «Ver PDF» (en la
/// `BarraDeAccion`). Con [claveDeAyuda], el botón de ayuda en la barra de
/// arriba (si la clínica escribió su texto).
class VistaDeDocumento<T extends DocumentoClinico> extends StatelessWidget {
  final String titulo;
  final String cargando;
  final List<Widget> Function(BuildContext context, T documento) contenido;
  final void Function(BuildContext context, T documento)? alVerPdf;

  /// La clave del texto de ayuda de la pantalla (`app.miSalud.receta`).
  final String? claveDeAyuda;

  const VistaDeDocumento({
    super.key,
    required this.titulo,
    required this.cargando,
    required this.contenido,
    this.alVerPdf,
    this.claveDeAyuda,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentoCubit<T>, DocumentoState<T>>(
      builder: (context, state) {
        final documento = state.documento;
        final cubit = context.read<DocumentoCubit<T>>();

        return Scaffold(
          backgroundColor: AppColors.fondo,
          appBar: AppBar(
            title: Text(titulo),
            actions: [
              if (claveDeAyuda case final clave?) BotonAyuda(clave: clave),
              const SizedBox(width: 6),
            ],
          ),
          // Sin PDF, sin barra: una vacía le quitaría a la lista el margen
          // de la barra del sistema.
          bottomNavigationBar: _barra(context, documento),
          body: FondoDegradado(
            child: documento == null
                ? ListView(
                    padding: context.margenDeScroll(),
                    children: [
                      if (state.carga == CargaDocumento.error)
                        EstadoError(
                          mensaje:
                              state.error ?? 'No pudimos abrir el documento.',
                          alReintentar: cubit.cargar,
                        )
                      else
                        CargandoCentro(mensaje: cargando),
                    ],
                  )
                : RefreshIndicator(
                    color: AppColors.acentoClaro,
                    backgroundColor: AppColors.superficie,
                    onRefresh: cubit.cargar,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: context.margenDeScroll(inferior: 28),
                      children: [
                        const AvisoSinConexion(
                          queSePuedeHacer:
                              'Mostramos la copia que guardamos en este '
                              'teléfono.',
                        ),
                        if (state.desdeCache && state.guardadoEn != null) ...[
                          RecuadroAviso.informacion(
                            'Mostramos la copia guardada el '
                            '${FormatoFecha.cortaConHora(state.guardadoEn!)}.',
                            icono: Icons.offline_pin_outlined,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (state.error != null) ...[
                          RecuadroAviso.alerta(state.error!),
                          const SizedBox(height: 12),
                        ],
                        ...contenido(context, documento),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget? _barra(BuildContext context, T? documento) {
    final abrir = alVerPdf;
    if (abrir == null || documento == null || !documento.puedeVerPdf) {
      return null;
    }

    return BarraDeAccion(
      child: BotonPrincipal(
        key: const Key('boton-ver-pdf'),
        texto: 'Ver PDF',
        icono: Icons.picture_as_pdf_outlined,
        onPressed: () => abrir(context, documento),
      ),
    );
  }
}
