import 'package:flutter/material.dart';

import '../../../../core/tema/tokens.dart';

/// El resultado de abrir un enlace del correo: un icono con su color, el
/// título y la explicación. Lo usan la confirmación del correo y la
/// contraseña nueva.
class ResultadoDeEnlace extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String texto;

  const ResultadoDeEnlace({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Icon(icono, color: color, size: 28),
        ),
        const SizedBox(height: 18),
        Semantics(
          header: true,
          child: Text(
            titulo,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          texto,
          style: const TextStyle(
            color: AppColors.textoSuave,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Vuelve a la primera pantalla: el acceso (o el inicio, si ya había una
/// sesión abierta).
void volverAlAcceso(BuildContext context) =>
    Navigator.of(context).popUntil((ruta) => ruta.isFirst);
