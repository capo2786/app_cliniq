// lib/features/avisos/presentacion/widgets/boton_campana.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/visual_del_servidor.dart';
import '../../../../core/tema/tokens.dart';
import '../../../navegacion/dominio/destinos.dart';
import '../../../navegacion/presentacion/enrutador.dart';
import '../../dominio/avisos.dart';
import '../../providers/campana_cubit.dart';

/// La campana de la cabecera, con cuántos avisos quedan sin leer.
///
/// Es administrable: solo aparece si el menú de la aplicación trae el enlace
/// a `/notificaciones` (con su nombre, que se usa de título). Fuera del
/// tablero —una pantalla suelta— no aparece.
class BotonCampana extends StatelessWidget {
  const BotonCampana({super.key});

  @override
  Widget build(BuildContext context) {
    final alcance = AlcanceDeNavegacion.maybeOf(context);
    final campana = alcance?.campana;
    if (alcance == null || campana == null) return const SizedBox.shrink();

    final icono =
        iconosDelPanel[campana.icon.trim().toLowerCase()] ??
        Icons.notifications_none_rounded;

    return BlocBuilder<CampanaCubit, CampanaState>(
      builder: (context, state) {
        final n = state.noLeidos;

        return IconButton(
          key: const Key('boton-campana'),
          tooltip: n == 0 ? campana.label : '${campana.label}: $n sin leer',
          onPressed: () => alcance.abrir(
            const DestinoNativo(PantallaNativa.avisos),
            titulo: campana.label,
          ),
          icon: Badge(
            isLabelVisible: n > 0,
            label: Text(insigniaDeAvisos(n)),
            backgroundColor: AppColors.acento,
            textColor: Colors.white,
            child: Icon(icono, color: AppColors.textoSuave),
          ),
        );
      },
    );
  }
}
