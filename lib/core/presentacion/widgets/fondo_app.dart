// lib/core/presentacion/widgets/fondo_app.dart

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../tema/tokens.dart';

/// Fondo degradado de las pantallas oscuras.
///
/// Va del gris azulado de la marca, arriba a la izquierda, al fondo profundo,
/// con dos halos difusos encima: uno del tono de la marca y otro terracota.
/// No es adorno: sobre un fondo plano las tarjetas semitransparentes se ven
/// sucias, y el degradado les da algo detrás que se note a través.
class FondoDegradado extends StatelessWidget {
  final Widget child;

  const FondoDegradado({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.fondoDegradadoInicio,
            AppColors.fondoDegradadoMedio,
            AppColors.fondo,
          ],
          stops: [0, 0.47, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -70,
            child: _Halo(
              color: AppColors.primarioClaro.withValues(alpha: 0.18),
              tamano: 230,
            ),
          ),
          Positioned(
            bottom: 80,
            left: -100,
            child: _Halo(
              color: AppColors.acento.withValues(alpha: 0.12),
              tamano: 250,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Halo extends StatelessWidget {
  final Color color;
  final double tamano;

  const _Halo({required this.color, required this.tamano});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          width: tamano,
          height: tamano,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
