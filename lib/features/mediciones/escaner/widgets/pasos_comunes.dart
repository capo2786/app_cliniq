// lib/features/mediciones/escaner/widgets/pasos_comunes.dart

import 'package:flutter/material.dart';

import '../../../../core/presentacion/margenes.dart';
import '../../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../../core/tema/tokens.dart';
import '../../dominio/reglas_mediciones.dart';

/// La línea de privacidad del escáner, en cada pantalla donde se mide.
const String lineaDePrivacidad =
    'Ninguna imagen de la cámara se guarda ni se envía: cada cuadro se '
    'convierte aquí mismo en números, y solo números salen del teléfono.';

/// El cuerpo de cada paso del escáner: lo desplazable arriba y el botón
/// abajo, en la barra de acción.
class CuerpoConBoton extends StatelessWidget {
  final List<Widget> children;
  final Widget? boton;

  const CuerpoConBoton({super.key, required this.children, this.boton});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: context.margenDeScroll(superior: 16, inferior: 24),
            children: children,
          ),
        ),
        if (boton != null) BarraDeAccion(child: boton!),
      ],
    );
  }
}

/// La línea de privacidad, con su candado.
class LineaPrivacidad extends StatelessWidget {
  const LineaPrivacidad({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, color: AppColors.textoTenue, size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            lineaDePrivacidad,
            key: Key('escaner-privacidad'),
            style: TextStyle(
              color: AppColors.textoTenue,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

/// El color de una calidad: verde, ámbar o rojo; gris mientras no se sabe.
Color colorDeCalidad(double? calidad) => calidad == null
    ? AppColors.textoTenue
    : switch (nivelDeCalidad(calidad)) {
        NivelCalidad.buena => AppColors.exito,
        NivelCalidad.regular => AppColors.alerta,
        NivelCalidad.baja => AppColors.peligroSuave,
      };
