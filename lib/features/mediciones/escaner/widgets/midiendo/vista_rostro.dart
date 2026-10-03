// lib/features/mediciones/escaner/widgets/midiendo/vista_rostro.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/tema/tokens.dart';
import '../../../../ayuda/presentacion/widgets/boton_ayuda.dart';
import '../../escaner_cubit.dart';
import 'malla_rostro.dart';
import 'marco_rostro.dart';
import 'panel_en_vivo.dart';

/// La instrucción de arriba: la de la guía de encuadre y, con la cara bien
/// puesta, el consejo de la calidad si lo hay. Una sola a la vez.
String? textoDeGuia(EscanerState state) {
  final instruccion = state.instruccion;
  if (instruccion == null) return null;
  final consejo = state.lectura.consejo;
  if (instruccion.bien && state.fase == FaseMedicion.midiendo) {
    return consejo ?? instruccion.texto;
  }
  return instruccion.texto;
}

/// El color de las esquinas según el encuadre.
EstadoDelMarco estadoDelMarco(EscanerState state) {
  final instruccion = state.instruccion;
  if (instruccion == null || !instruccion.hayRostro) {
    return EstadoDelMarco.buscando;
  }
  return state.fase == FaseMedicion.midiendo && instruccion.bien
      ? EstadoDelMarco.midiendo
      : EstadoDelMarco.ajustando;
}

/// La medición con el rostro a pantalla completa: la cámara frontal
/// cubriendo todo (espejada), la malla de los contornos detectados, el
/// marco con sus esquinas, la línea de barrido, arriba la guía y abajo el
/// panel con los valores en vivo.
class VistaRostroCompleta extends StatelessWidget {
  final EscanerState state;
  final VoidCallback alCerrar;

  const VistaRostroCompleta({
    super.key,
    required this.state,
    required this.alCerrar,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EscanerCubit>();
    final guia = textoDeGuia(state);

    return ColoredBox(
      color: AppColors.lente,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: cubit.fuente.vistaPrevia(context)),
          if (!state.porColorDePiel)
            Positioned.fill(
              child: IgnorePointer(
                child: MallaDelRostro(
                  rostro: cubit.rostroEnVivo,
                  fc: state.lectura.fcVisible ? state.lectura.fc : null,
                  color: AppColors.celeste,
                ),
              ),
            ),
          Positioned.fill(
            child: IgnorePointer(
              child: MarcoConEsquinas(estado: estadoDelMarco(state)),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: LineaDeBarrido(color: AppColors.celeste),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _Arriba(guia: guia, alCerrar: alCerrar),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PanelEnVivo(state: state, alCancelar: cubit.cancelar),
          ),
        ],
      ),
    );
  }
}

class _Arriba extends StatelessWidget {
  final String? guia;
  final VoidCallback alCerrar;

  const _Arriba({required this.guia, required this.alCerrar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('escaner-cerrar'),
                tooltip: 'Cerrar',
                color: AppColors.texto,
                icon: const Icon(Icons.close_rounded),
                onPressed: alCerrar,
              ),
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.fondoProfundo.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.veloClaro),
                    ),
                    child: const Text(
                      'Signos vitales · Experimental',
                      style: TextStyle(
                        color: AppColors.texto,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const BotonAyuda(clave: 'app.escaner'),
              const SizedBox(width: 6),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (hijo, animacion) => FadeTransition(
              opacity: animacion,
              child: ScaleTransition(
                scale: Tween(begin: 0.92, end: 1.0).animate(animacion),
                child: hijo,
              ),
            ),
            child: guia == null
                ? const SizedBox(height: 40)
                : Container(
                    key: ValueKey(guia),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.fondoProfundo.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      guia!,
                      key: const Key('escaner-guia'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
