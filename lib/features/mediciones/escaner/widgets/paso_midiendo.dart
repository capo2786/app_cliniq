// lib/features/mediciones/escaner/widgets/paso_midiendo.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../dominio/reglas_mediciones.dart';
import '../escaner_cubit.dart';
import '../serie_senal.dart';
import 'dibujos_escaner.dart';
import 'pasos_comunes.dart';

/// Mientras mide: la vista con el óvalo (rostro) o el latido (dedo), la
/// cuenta regresiva, la onda, la calidad y el consejo del momento.
class PasoMidiendo extends StatelessWidget {
  final EscanerState state;

  const PasoMidiendo({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EscanerCubit>();
    final calidad = state.lectura.calidad;
    final color = colorDeCalidad(calidad);

    return CuerpoConBoton(
      boton: BotonSecundario(
        key: const Key('escaner-cancelar'),
        texto: 'Cancelar',
        icono: Icons.stop_rounded,
        color: AppColors.peligroSuave,
        onPressed: cubit.cancelar,
      ),
      children: [
        if (state.modo == ModoEscaner.rostro)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: 300,
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: AppColors.lente,
                        child: cubit.fuente.vistaPrevia(context),
                      ),
                      OvaloDelRostro(color: color),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          Center(child: LatidoDelDedo(color: AppColors.acento)),
        const SizedBox(height: 20),
        Center(
          child: Text(
            '${state.segundosRestantes} s',
            key: const Key('escaner-cuenta'),
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 40,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: state.avance,
            minHeight: 6,
            color: AppColors.acentoClaro,
            backgroundColor: AppColors.bordeCampo,
          ),
        ),
        const SizedBox(height: 18),
        TarjetaTranslucida(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OndaEnVivo(
                key: const Key('escaner-onda'),
                onda: state.lectura.onda,
                color: AppColors.acentoClaro,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.circle, color: color, size: 12),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      calidad == null
                          ? 'Midiendo la calidad de la señal…'
                          : 'Señal: ${nombreDelNivel(nivelDeCalidad(calidad)).replaceFirst('Calidad ', '')}',
                      key: const Key('escaner-calidad'),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (state.lectura.consejo != null) ...[
          const SizedBox(height: 12),
          RecuadroAviso.alerta(
            state.lectura.consejo!,
            key: const Key('escaner-consejo'),
            icono: Icons.tips_and_updates_outlined,
          ),
        ],
        const LineaPrivacidad(),
      ],
    );
  }
}
