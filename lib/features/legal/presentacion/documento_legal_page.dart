// lib/features/legal/presentacion/documento_legal_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/configuracion/en_contexto.dart';
import '../../../core/fechas/instante.dart';
import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/presentacion/widgets/texto_markdown.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../navegacion/presentacion/enrutador.dart';
import '../data/legal_service.dart';
import '../providers/documento_legal_cubit.dart';

/// Un documento legal, leído dentro de la aplicación (`/legal/:slug`).
///
/// El texto llega del servidor en Markdown, con los datos de la clínica ya
/// sustituidos, y se pinta aquí: no se abre el panel web. Queda una copia en
/// el teléfono para leerlo sin red. [titulo] es el que ya se conoce (de la
/// lista de documentos), para la cabecera mientras llega el texto.
class DocumentoLegalPage extends StatelessWidget {
  final String slug;
  final String? titulo;
  final LegalService? servicio;

  const DocumentoLegalPage({
    super.key,
    required this.slug,
    this.titulo,
    this.servicio,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          DocumentoLegalCubit(servicio ?? Servicios.legal, slug)..cargar(),
      child: _VistaDocumento(titulo: titulo),
    );
  }
}

class _VistaDocumento extends StatelessWidget {
  final String? titulo;

  const _VistaDocumento({this.titulo});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocumentoLegalCubit, DocumentoLegalState>(
      builder: (context, state) {
        final documento = state.documento;
        final error = state.error;

        return Scaffold(
          key: const Key('documento-legal'),
          backgroundColor: AppColors.fondo,
          appBar: AppBar(
            title: Text(
              documento?.titulo ?? titulo ?? 'Documento legal',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: FondoDegradado(
            child: RefreshIndicator(
              color: AppColors.acentoClaro,
              backgroundColor: AppColors.superficie,
              onRefresh: () => context.read<DocumentoLegalCubit>().cargar(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: context.margenDeScroll(),
                children: [
                  const AvisoSinConexion(
                    queSePuedeHacer:
                        'Si ya lo abriste antes, ves la copia guardada en '
                        'este teléfono.',
                  ),
                  if (documento != null)
                    _Documento(documento: documento)
                  else if (state.cargando)
                    const CargandoCentro(mensaje: 'Cargando el documento…')
                  else if (state.noEncontrado)
                    const EstadoVacio(
                      icono: Icons.search_off_rounded,
                      titulo: 'Documento no encontrado',
                      descripcion:
                          'Puede que el documento ya no esté vigente. Los '
                          'documentos de la clínica están en tu perfil.',
                    )
                  else if (error != null)
                    EstadoError(
                      mensaje: error,
                      alReintentar: () =>
                          context.read<DocumentoLegalCubit>().cargar(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Documento extends StatelessWidget {
  final TextoLegal documento;

  const _Documento({required this.documento});

  @override
  Widget build(BuildContext context) {
    final vigente = documento.vigenteDesde;
    final datos = [
      if (documento.version.isNotEmpty) 'Versión ${documento.version}',
      if (vigente != null)
        'vigente desde el '
            '${FormatoFecha.diaLargoConAnio(enHoraDeLaClinica(vigente)).toLowerCase()}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TarjetaTranslucida(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DOCUMENTO LEGAL · ${context.config.clinica.nombre}'
                    .toUpperCase(),
                style: TextStyle(
                  color: AppColors.acentoSuave,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                documento.titulo,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              if (documento.resumen.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  documento.resumen,
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
              if (datos.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  FormatoFecha.capitalizar(datos.join(' · ')),
                  style: const TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        TarjetaTranslucida(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: TextoMarkdown(
            documento.contenido,
            alTocarEnlace: (enlace) => abrirEnlaceDeTexto(context, enlace),
          ),
        ),
      ],
    );
  }
}
