// lib/core/presentacion/widgets/cerrar_sesion.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../features/auth/providers/auth_bloc.dart';
import '../../../features/auth/providers/auth_event.dart';
import '../../tema/tokens.dart';

/// Cerrar sesión, disponible desde la barra de cada pantalla de contenido.
///
/// Es una sola pieza —el mismo diálogo, el mismo texto, el mismo lugar— y
/// siempre pregunta antes: un toque accidental en el borde de la pantalla no
/// puede sacar a nadie de su cuenta en plena sala de espera.
class BotonCerrarSesion extends StatelessWidget {
  final double tamano;

  const BotonCerrarSesion({super.key, this.tamano = 22});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Cerrar sesión',
      onPressed: () => confirmarCierreDeSesion(context),
      iconSize: tamano,
      icon: const Icon(Icons.logout_rounded, color: AppColors.textoSuave),
    );
  }
}

/// Pregunta y, si la persona confirma, cierra la sesión.
Future<void> confirmarCierreDeSesion(BuildContext context) async {
  final salir = await showDialog<bool>(
    context: context,
    builder: (contextoDialogo) => AlertDialog(
      backgroundColor: AppColors.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.peligroSuave.withValues(alpha: 0.35)),
      ),
      title: const Row(
        children: [
          Icon(Icons.logout_rounded, color: AppColors.peligroSuave, size: 23),
          SizedBox(width: 10),
          Text(
            'Cerrar sesión',
            style: TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      content: const Text(
        '¿Deseas salir de tu cuenta de Cliniq? Tus recordatorios de citas '
        'dejarán de sonar en este teléfono hasta que vuelvas a entrar.',
        style: TextStyle(color: AppColors.textoSuave, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(contextoDialogo).pop(false),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textoSecundario),
          ),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(contextoDialogo).pop(true),
          icon: const Icon(Icons.logout_rounded, size: 17),
          label: const Text('Cerrar sesión'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.peligroBoton,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    ),
  );

  if (salir != true || !context.mounted) return;

  context.read<AuthBloc>().add(const AuthCierreSolicitado());
}
