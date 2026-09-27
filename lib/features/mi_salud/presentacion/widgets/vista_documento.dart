// lib/features/mi_salud/presentacion/widgets/vista_documento.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/margenes.dart';
import '../../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/fondo_app.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/mi_salud.dart';
import '../../providers/documento_cubit.dart';

/// El esqueleto de una receta o una orden abierta: la barra, lo que se
/// dice mientras carga o si falla, la copia guardada y deslizar para
/// ponerla al día. El contenido lo pone cada pantalla.
class VistaDeDocumento<T extends DocumentoClinico> extends StatelessWidget {
  final String titulo;
  final String cargando;
  final List<Widget> Function(BuildContext context, T documento) contenido;

  const VistaDeDocumento({
    super.key,
    required this.titulo,
    required this.cargando,
    required this.contenido,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(title: Text(titulo)),
      body: FondoDegradado(
        child: BlocBuilder<DocumentoCubit<T>, DocumentoState<T>>(
          builder: (context, state) {
            final documento = state.documento;
            final cubit = context.read<DocumentoCubit<T>>();

            if (documento == null) {
              return ListView(
                padding: context.margenDeScroll(),
                children: [
                  if (state.carga == CargaDocumento.error)
                    EstadoError(
                      mensaje: state.error ?? 'No pudimos abrir el documento.',
                      alReintentar: cubit.cargar,
                    )
                  else
                    CargandoCentro(mensaje: cargando),
                ],
              );
            }

            return RefreshIndicator(
              color: AppColors.acentoClaro,
              backgroundColor: AppColors.superficie,
              onRefresh: cubit.cargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: context.margenDeScroll(inferior: 28),
                children: [
                  const AvisoSinConexion(
                    queSePuedeHacer:
                        'Mostramos la copia que guardamos en este teléfono.',
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
            );
          },
        ),
      ),
    );
  }
}
