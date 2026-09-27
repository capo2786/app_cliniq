// lib/features/citas/presentacion/videoconsulta_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/integraciones/costuras.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/tema/tokens.dart';
import '../data/models/cita.dart';
import '../providers/citas_bloc.dart';
import '../providers/citas_state.dart';
import 'widgets/tarjeta_cita.dart';
import 'widgets/videoconsulta.dart';

/// La videoconsulta de una cita (`/portal/videoconsulta/:citaId`), para los
/// avisos y enlaces que llevan a ella.
///
/// Con la cita entre las de la persona, su tarjeta y el botón de siempre
/// (con la ventana de la sala). Si la cita no está (todavía no se cargaron,
/// o es de otra lista), se ofrece entrar igual: el servidor decide si es de
/// quien entra y si la sala está abierta, y lo explica si no.
class VideoconsultaPage extends StatelessWidget {
  final String citaId;
  final ServicioVideollamada? servicio;

  const VideoconsultaPage({super.key, required this.citaId, this.servicio});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CitasBloc, CitasState>(
      builder: (context, state) {
        Cita? cita;
        for (final c in state.citas) {
          if (c.id == citaId) cita = c;
        }

        return Scaffold(
          backgroundColor: AppColors.fondo,
          appBar: AppBar(title: const Text('Videoconsulta')),
          body: FondoDegradado(
            child: ListView(
              padding: context.margenDeScroll(),
              children: [
                const AvisoSinConexion(
                  queSePuedeHacer:
                      'Para entrar a la videoconsulta necesitas conexión.',
                ),
                if (cita != null) ...[
                  TarjetaCita(cita: cita),
                  const SizedBox(height: 16),
                  BotonVideoconsulta(cita: cita, servicio: servicio),
                ] else if (state.carga == CargaCitas.cargando)
                  const CargandoCentro(mensaje: 'Buscando tu cita…')
                else ...[
                  const RecuadroAviso.informacion(
                    'La sala se abre poco antes de la cita y se cierra un rato '
                    'después de que termina.',
                    icono: Icons.videocam_outlined,
                  ),
                  const SizedBox(height: 16),
                  EntrarASala(citaId: citaId, servicio: servicio),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
