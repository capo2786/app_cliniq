import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/tema/tokens.dart';
import '../../../agendar/presentacion/widgets/opcion_seleccionable.dart';
import '../../providers/nueva_consulta_bloc.dart';
import '../../providers/nueva_consulta_event.dart';
import '../../providers/nueva_consulta_state.dart';

/// Paso 2: la especialidad. Solo aparecen las que tienen médicos que
/// atienden en línea y algún motivo; al tocar una, se sigue.
class PasoEspecialidad extends StatelessWidget {
  final NuevaConsultaState state;

  const PasoEspecialidad({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NuevaConsultaBloc>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.pacienteNombre.isEmpty
              ? 'Elige el área de lo que te pasa.'
              : 'Consulta para ${state.pacienteNombre}. Elige el área de lo '
                    'que le pasa.',
          style: const TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        for (final especialidad in state.especialidades) ...[
          OpcionSeleccionable(
            titulo: especialidad.nombre,
            descripcion: [
              especialidad.medicos.length == 1
                  ? '1 médico en línea'
                  : '${especialidad.medicos.length} médicos en línea',
              especialidad.motivosOrdenados.length == 1
                  ? '1 motivo'
                  : '${especialidad.motivosOrdenados.length} motivos',
            ].join(' · '),
            icono: Icons.medical_services_outlined,
            color: AppColors.celeste,
            elegida: state.especialidad == especialidad.nombre,
            onTap: () =>
                bloc.add(NuevaConsultaEspecialidadElegida(especialidad.nombre)),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
