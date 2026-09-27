// lib/features/encuestas/presentacion/widgets/aviso_encuestas.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../../citas/data/models/cita.dart';
import '../../providers/encuestas_cubit.dart';

/// El aviso del inicio cuando hay citas por calificar: «¿Cómo te fue en tu
/// consulta?», con el botón para responder la más reciente. Sin pendientes
/// no ocupa lugar.
class AvisoEncuestas extends StatelessWidget {
  /// Abre la encuesta de esa cita.
  final ValueChanged<String> alResponder;

  const AvisoEncuestas({super.key, required this.alResponder});

  @override
  Widget build(BuildContext context) {
    final pendientes = context.select<EncuestasCubit, List<Cita>>(
      (cubit) => cubit.state.pendientes,
    );
    if (pendientes.isEmpty) return const SizedBox.shrink();

    final primera = pendientes.first;

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: TarjetaTranslucida(
        key: const Key('aviso-encuestas'),
        tinte: AppColors.acento,
        onTap: () => alResponder(primera.id),
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.acento.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.star_outline_rounded,
                color: AppColors.acentoClaro,
                size: 24,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¿Cómo te fue en tu consulta?',
                    style: TextStyle(
                      color: AppColors.texto,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    textoDelAviso(pendientes),
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Responder',
              style: TextStyle(
                color: AppColors.acentoClaro,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.acentoClaro),
          ],
        ),
      ),
    );
  }
}

/// Qué dice el aviso: con una, a quién y cuándo; con varias, cuántas.
String textoDelAviso(List<Cita> pendientes) {
  if (pendientes.length > 1) {
    return 'Tienes ${pendientes.length} consultas recientes por calificar. '
        'Toma diez segundos cada una.';
  }

  final cita = pendientes.single;
  final medico = cita.medico;
  final quien = medico == null || medico.isEmpty ? 'tu médico' : medico;

  return 'Cuéntanos cómo te atendió $quien el '
      '${FormatoFecha.diaYMes(cita.inicio)}. Toma diez segundos.';
}
