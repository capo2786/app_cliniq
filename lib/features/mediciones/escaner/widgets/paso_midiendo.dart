// lib/features/mediciones/escaner/widgets/paso_midiendo.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/tema/tokens.dart';
import '../escaner_cubit.dart';
import '../serie_senal.dart';
import 'dibujos_escaner.dart';
import 'midiendo/panel_en_vivo.dart';
import 'midiendo/vista_rostro.dart';

/// Mientras mide. Con el rostro, la vista a pantalla completa
/// ([VistaRostroCompleta]); con el dedo (sin vista: con la yema encima
/// solo se vería rojo), el círculo que late, el consejo del momento y el
/// mismo panel en vivo.
class PasoMidiendo extends StatelessWidget {
  final EscanerState state;

  /// Cerrar el escáner (la equis de arriba, en el modo rostro).
  final VoidCallback alCerrar;

  const PasoMidiendo({super.key, required this.state, required this.alCerrar});

  @override
  Widget build(BuildContext context) {
    if (state.modo == ModoEscaner.rostro) {
      return VistaRostroCompleta(state: state, alCerrar: alCerrar);
    }

    final cubit = context.read<EscanerCubit>();
    final consejo = state.lectura.consejo;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  LatidoDelDedo(color: AppColors.acento),
                  if (consejo != null) ...[
                    const SizedBox(height: 18),
                    RecuadroAviso.alerta(
                      consejo,
                      key: const Key('escaner-consejo'),
                      icono: Icons.tips_and_updates_outlined,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        PanelEnVivo(state: state, alCancelar: cubit.cancelar),
      ],
    );
  }
}
