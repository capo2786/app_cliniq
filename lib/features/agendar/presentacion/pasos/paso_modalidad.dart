import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/tema/tokens.dart';
import '../../../citas/presentacion/estilos_cita.dart';
import '../../dominio/horarios.dart';
import '../../providers/agendar_bloc.dart';
import '../../providers/agendar_event.dart';
import '../../providers/agendar_state.dart';
import '../widgets/opcion_seleccionable.dart';
import '../../../ayuda/presentacion/widgets/boton_ayuda.dart';

/// Paso 4: la modalidad. Solo las que ofrece el médico elegido.
class PasoModalidad extends StatelessWidget {
  final AgendarState state;

  const PasoModalidad({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AgendarBloc>();
    final medico = state.medico;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                medico == null
                    ? 'Elige cómo quieres la consulta.'
                    : '${medico.nombre} atiende así:',
                style: const TextStyle(
                  color: AppColors.textoSecundario,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const BotonAyuda(clave: 'app.agendar.modalidad', enLinea: true),
          ],
        ),
        const SizedBox(height: 16),
        for (final tipo in state.modalidadesMedico) ...[
          Builder(
            builder: (context) {
              final estilo = context.modalidad(tipo);
              final minutos =
                  '${duracionDe(medico, tipo, state.reglas)} '
                  'minutos';

              return OpcionSeleccionable(
                titulo: estilo.nombre,
                descripcion: estilo.descripcion.isEmpty
                    ? minutos
                    : '${estilo.descripcion} · $minutos',
                icono: estilo.icono,
                color: estilo.color,
                elegida: state.tipo == tipo,
                onTap: () => bloc.add(AgendarModalidadElegida(tipo)),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
