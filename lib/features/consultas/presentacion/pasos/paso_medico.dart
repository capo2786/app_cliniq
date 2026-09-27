import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/tema/tokens.dart';
import '../../../agendar/presentacion/widgets/opcion_seleccionable.dart';
import '../../dominio/reglas_consultas.dart';
import '../../providers/nueva_consulta_bloc.dart';
import '../../providers/nueva_consulta_event.dart';
import '../../providers/nueva_consulta_state.dart';

/// Paso 4: el médico que va a responder. Solo están los que atienden
/// consultas en línea en la especialidad elegida.
class PasoMedicoConsulta extends StatelessWidget {
  final NuevaConsultaState state;

  const PasoMedicoConsulta({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NuevaConsultaBloc>();
    final medicos = state.medicosDisponibles;

    if (medicos.isEmpty) {
      return EstadoVacio(
        icono: Icons.person_search_rounded,
        titulo: 'Ningún médico disponible',
        descripcion:
            'En esta especialidad no hay médicos atendiendo en línea ahora. '
            'Elige otra especialidad.',
        accion: 'Cambiar especialidad',
        alPulsar: () => bloc.add(
          const NuevaConsultaPasoCambiado(PasoConsulta.especialidad),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'El médico que elijas tiene $horasDeRespuesta horas para '
          'responderte desde que envías la consulta.',
          style: TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        for (final medico in medicos) ...[
          OpcionSeleccionable(
            titulo: medico.nombreVisible,
            descripcion: medico.especialidad.isEmpty
                ? state.especialidad
                : medico.especialidad,
            icono: Icons.medical_information_outlined,
            color: AppColors.primarioClaro,
            elegida: state.medico?.uid == medico.uid,
            onTap: () => bloc.add(NuevaConsultaMedicoElegido(medico.uid)),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
