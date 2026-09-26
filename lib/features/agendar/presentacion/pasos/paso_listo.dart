import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/entrada_animada.dart';
import '../../../../core/tema/tokens.dart';
import '../../../citas/dominio/reglas_citas.dart';
import '../../../citas/presentacion/widgets/tarjeta_cita.dart';
import '../../providers/agendar_bloc.dart';
import '../../providers/agendar_event.dart';
import '../../providers/agendar_state.dart';

/// El final: la cita quedó, con todo lo que hay que saber.
class PasoListo extends StatelessWidget {
  final AgendarState state;

  const PasoListo({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cita = state.agendada;
    final reprogramada = state.reprogramando;

    return EntradaAnimada(
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.exito.withValues(alpha: 0.14),
              border: Border.all(
                color: AppColors.exito.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: AppColors.exito,
              size: 54,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            reprogramada ? '¡Cita reprogramada!' : '¡Cita agendada!',
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Te enviamos la confirmación a tu correo. Te recordaremos un día '
            'y una hora antes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textoSecundario,
              fontSize: 13.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          if (cita != null) ...[
            TarjetaCita(cita: cita),
            const SizedBox(height: 14),
            ConsejosDePreparacion(consejos: consejosPara(cita.tipo)),
            const SizedBox(height: 8),
            Text(
              '${cuentaRegresiva(cita, state.ahora)} · '
              '${FormatoFecha.diaLargo(cita.inicio)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textoTenue, fontSize: 12),
            ),
          ],
          const SizedBox(height: 26),
          BotonPrincipal(
            texto: 'Ver mis citas',
            icono: Icons.event_note_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
          if (!reprogramada) ...[
            const SizedBox(height: 10),
            BotonSecundario(
              texto: 'Agendar otra cita',
              icono: Icons.add_rounded,
              onPressed: () =>
                  context.read<AgendarBloc>().add(const AgendarOtraCita()),
            ),
          ],
        ],
      ),
    );
  }
}
