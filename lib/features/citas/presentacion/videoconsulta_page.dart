// lib/features/citas/presentacion/videoconsulta_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/tema/tokens.dart';
import '../data/models/cita.dart';
import '../data/videollamada_service.dart';
import '../providers/citas_bloc.dart';
import '../providers/citas_state.dart';
import 'widgets/tarjeta_cita.dart';
import 'widgets/videoconsulta.dart';

/// La videoconsulta de una cita (`/portal/videoconsulta/:citaId`), para los
/// avisos y enlaces que llevan a ella.
///
/// Es la pantalla de la cita —su tarjeta y el botón de siempre, con la
/// ventana de la sala— y, si la sala ya está abierta al llegar, la
/// videoconsulta se abre sola encima, en su ventana; al colgar se vuelve
/// aquí. Si la cita no está (todavía no se cargaron, o es de otra lista),
/// se entra igual: el servidor decide si es de quien entra y si la sala
/// está abierta, y lo explica si no.
class VideoconsultaPage extends StatefulWidget {
  final String citaId;
  final ServicioVideollamada? servicio;

  const VideoconsultaPage({super.key, required this.citaId, this.servicio});

  @override
  State<VideoconsultaPage> createState() => _VideoconsultaPageState();
}

class _VideoconsultaPageState extends State<VideoconsultaPage> {
  /// Se entra solo una vez, aunque la lista de citas cambie debajo.
  final EntradaAutomatica _entrada = EntradaAutomatica();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CitasBloc, CitasState>(
      builder: (context, state) {
        Cita? cita;
        for (final c in state.citas) {
          if (c.id == widget.citaId) cita = c;
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
                  BotonVideoconsulta(
                    cita: cita,
                    entradaAutomatica: _entrada,
                    servicio: widget.servicio,
                  ),
                ] else if (state.carga == CargaCitas.cargando)
                  const CargandoCentro(mensaje: 'Buscando tu cita…')
                else ...[
                  const RecuadroAviso.informacion(
                    'La sala se abre poco antes de la cita y se cierra un rato '
                    'después de que termina.',
                    icono: Icons.videocam_outlined,
                  ),
                  const SizedBox(height: 16),
                  EntrarASala(
                    citaId: widget.citaId,
                    entradaAutomatica: _entrada,
                    servicio: widget.servicio,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
