import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/campos.dart';
import '../../../../core/tema/tokens.dart';
import '../../providers/agendar_bloc.dart';
import '../../providers/agendar_event.dart';
import '../../providers/agendar_state.dart';

/// Paso 6: el motivo de consulta. Obligatorio y de hasta 500 caracteres.
///
/// Lo lee el médico antes de la cita: «dolor de cabeza desde hace tres
/// días, tomo paracetamol» le ahorra la mitad de la consulta.
class PasoMotivo extends StatefulWidget {
  final AgendarState state;

  const PasoMotivo({super.key, required this.state});

  @override
  State<PasoMotivo> createState() => _PasoMotivoState();
}

class _PasoMotivoState extends State<PasoMotivo> {
  late final TextEditingController _motivo = TextEditingController(
    text: widget.state.motivo,
  );

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final largo = widget.state.motivo.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Cuéntale al médico qué te pasa: desde cuándo, qué sientes y si '
          'tomas algún medicamento.',
          style: TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        const EtiquetaCampo('Motivo de consulta *'),
        TextField(
          key: const Key('campo-motivo'),
          controller: _motivo,
          minLines: 5,
          maxLines: 9,
          maxLength: maximoMotivo,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: AppColors.acentoClaro,
          style: const TextStyle(
            color: AppColors.texto,
            fontSize: 15,
            height: 1.4,
          ),
          decoration: decoracionCliniq(
            pista: 'Ej.: Dolor de garganta y fiebre desde el lunes.',
            contador: '$largo/$maximoMotivo',
          ),
          onChanged: (texto) =>
              context.read<AgendarBloc>().add(AgendarMotivoCambiado(texto)),
        ),
      ],
    );
  }
}
