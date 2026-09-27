// lib/core/presentacion/widgets/barra_de_accion.dart

import 'package:flutter/material.dart';

import '../../tema/tokens.dart';

/// Cierra el teclado, si hay uno abierto.
void cerrarTeclado() => FocusManager.instance.primaryFocus?.unfocus();

/// La barra de abajo con el botón que avanza («Continuar», «Confirmar»…).
///
/// Va en `Scaffold.bottomNavigationBar`, y ahí Flutter no la sube cuando se
/// abre el teclado: quedaba tapada y, en un campo de varias líneas (que en
/// iPhone no trae tecla para cerrar el teclado), no había forma de seguir.
/// Por eso se levanta sola por encima del teclado; cerrado el teclado,
/// respeta la barra de gestos del sistema.
class BarraDeAccion extends StatelessWidget {
  final Widget child;

  const BarraDeAccion({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.viewInsetsOf(context).bottom;
    final sistema = MediaQuery.viewPaddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: teclado),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          12 + (teclado > 0 ? 0 : sistema),
        ),
        decoration: BoxDecoration(
          color: AppColors.superficie,
          border: Border(
            top: BorderSide(
              color: AppColors.primarioClaro.withValues(alpha: 0.14),
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Tocar fuera de un campo de texto cierra el teclado, en toda la
/// aplicación (Flutter, en el teléfono, lo deja abierto). Los botones y los
/// demás campos siguen recibiendo sus toques: esto solo actúa donde nadie
/// más responde.
class CerrarTecladoAlTocarFuera extends StatelessWidget {
  final Widget child;

  const CerrarTecladoAlTocarFuera({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: cerrarTeclado,
      child: child,
    );
  }
}
