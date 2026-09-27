import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../../agendar/presentacion/widgets/opcion_seleccionable.dart';
import '../../providers/nueva_consulta_bloc.dart';
import '../../providers/nueva_consulta_event.dart';
import '../../providers/nueva_consulta_state.dart';

/// Paso 3: el motivo. Cada uno dice de qué se trata y si pide un archivo;
/// de él salen las preguntas del formulario.
class PasoMotivoConsulta extends StatelessWidget {
  final NuevaConsultaState state;

  const PasoMotivoConsulta({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NuevaConsultaBloc>();
    final motivos = state.motivosDisponibles;

    if (motivos.isEmpty) {
      return EstadoVacio(
        icono: Icons.help_outline_rounded,
        titulo: 'Sin motivos en esta especialidad',
        descripcion: 'Elige otra especialidad.',
        accion: 'Cambiar especialidad',
        alPulsar: () => bloc.add(
          const NuevaConsultaPasoCambiado(PasoConsulta.especialidad),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${state.especialidad}. Elige el motivo que más se parece a lo que '
          'te pasa; si ninguno encaja, «Otro motivo».',
          style: const TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        for (final motivo in motivos) ...[
          OpcionSeleccionable(
            titulo: motivo.nombre,
            descripcion: motivo.descripcion.isEmpty ? null : motivo.descripcion,
            icono: Icons.assignment_outlined,
            color: AppColors.acentoClaro,
            elegida: state.motivo?.id == motivo.id,
            extra: motivo.requiereAdjunto
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Pastilla(
                      texto: 'Pide una foto o un PDF',
                      color: AppColors.ambar,
                      icono: Icons.attach_file_rounded,
                    ),
                  )
                : null,
            onTap: () => bloc.add(NuevaConsultaMotivoElegido(motivo.id)),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
