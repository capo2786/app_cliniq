import 'package:flutter/material.dart';

import '../tema/tokens.dart';

/// Un aviso flotante al pie de la pantalla, verde o rojo.
///
/// Uno solo para toda la aplicación: el mismo aspecto, la misma posición y
/// el mismo texto de apoyo, esté donde esté la persona.
void mostrarAviso(BuildContext context, String mensaje, {bool error = false}) {
  final mensajero = ScaffoldMessenger.maybeOf(context);
  if (mensajero == null) return;

  mensajero
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: error ? AppColors.avisoError : AppColors.avisoExito,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
      ),
    );
}

/// Pregunta antes de algo que no se deshace. Devuelve `true` si se confirma.
Future<bool> confirmarAccion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String confirmar,
  IconData icono = Icons.help_outline_rounded,
  bool peligroso = false,
}) async {
  final color = peligroso ? AppColors.peligroSuave : AppColors.acentoClaro;

  final respuesta = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      title: Row(
        children: [
          Icon(icono, color: color, size: 23),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(
                color: AppColors.texto,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        mensaje,
        style: const TextStyle(color: AppColors.textoSuave, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contexto).pop(false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textoSecundario),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(contexto).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: peligroso
                ? AppColors.peligroBoton
                : AppColors.acento,
            foregroundColor: Colors.white,
          ),
          child: Text(confirmar),
        ),
      ],
    ),
  );

  return respuesta == true;
}
