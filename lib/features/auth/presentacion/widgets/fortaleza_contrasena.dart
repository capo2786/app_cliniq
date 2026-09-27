import 'package:flutter/material.dart';

import '../../../../core/tema/tokens.dart';
import '../../dominio/registro.dart';

/// Qué tan difícil de adivinar es la contraseña que se está escribiendo: la
/// barra de cuatro tramos y la pista del panel.
///
/// No bloquea (el mínimo lo exige el formulario y el servidor): orienta, que
/// es lo que evita el «Clinica2024» que todo el mundo elige sin pistas.
class FortalezaDeContrasena extends StatelessWidget {
  final String contrasena;

  /// La contraseña mínima de la clínica (`seguridad.passwordMinimo`).
  final int minimo;

  const FortalezaDeContrasena({
    super.key,
    required this.contrasena,
    required this.minimo,
  });

  static Color _color(int puntaje) => switch (puntaje) {
    0 || 1 => AppColors.peligroSuave,
    2 => AppColors.alerta,
    3 => AppColors.celeste,
    _ => AppColors.exito,
  };

  @override
  Widget build(BuildContext context) {
    final puntaje = puntajeDeContrasena(contrasena, minimo);
    final color = _color(puntaje);

    return Padding(
      padding: const EdgeInsets.only(top: AppEspaciado.s, left: 2, right: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                for (var tramo = 1; tramo <= 4; tramo++) ...[
                  if (tramo > 1) const SizedBox(width: 4),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 5,
                      decoration: BoxDecoration(
                        color: tramo <= puntaje ? color : AppColors.bordeCampo,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (contrasena.isNotEmpty) ...[
            const SizedBox(height: 5),
            Semantics(
              liveRegion: true,
              child: Text(
                pistaDeContrasena(puntaje, minimo),
                key: const Key('pista-contrasena'),
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
