// lib/features/ayuda/presentacion/widgets/acceso_a_soporte.dart

import 'package:flutter/material.dart';

import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';

/// La tarjeta que lleva a soporte cuando la ayuda no alcanzó: «¿No
/// encontraste lo que buscabas?», «¿No resolviste tu duda?».
class AccesoASoporte extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final String accion;
  final VoidCallback alTocar;

  const AccesoASoporte({
    super.key,
    required this.titulo,
    required this.descripcion,
    required this.accion,
    required this.alTocar,
  });

  @override
  Widget build(BuildContext context) {
    return TarjetaTranslucida(
      tinte: AppColors.acento,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.acento.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.support_agent_rounded,
                  color: AppColors.acentoClaro,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      descripcion,
                      style: const TextStyle(
                        color: AppColors.textoSecundario,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: alTocar,
              icon: const Icon(Icons.edit_note_rounded, size: 20),
              label: Text(accion),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.acentoClaro,
                side: BorderSide(
                  color: AppColors.acento.withValues(alpha: 0.55),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
