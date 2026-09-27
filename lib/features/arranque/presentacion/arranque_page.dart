import 'package:flutter/material.dart';

import '../../../core/presentacion/widgets/entrada_animada.dart';
import '../../../core/presentacion/widgets/logo_clinica.dart';
import '../../../core/tema/tokens.dart';

/// Lo que se ve mientras se restaura la sesión guardada o llegan los datos de
/// la clínica.
///
/// Tiene el mismo fondo que la pantalla de arranque nativa, para que el paso
/// de una a otra no se note: la persona ve una sola pantalla que termina de
/// cargar, no dos. El logotipo es el de la clínica en cuanto se conoce su
/// configuración; antes, el de marca.
class ArranquePage extends StatelessWidget {
  const ArranquePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.fondoProfundo,
      body: Center(
        child: EntradaAnimada(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LogoDeLaClinica(tamano: 104, insignia: true),
              SizedBox(height: 28),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: AppColors.acentoClaro,
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Preparando tu espacio…',
                style: TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
