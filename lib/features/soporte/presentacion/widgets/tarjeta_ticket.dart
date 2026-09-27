// lib/features/soporte/presentacion/widgets/tarjeta_ticket.dart

import 'package:flutter/material.dart';

import '../../../../core/formato/instantes.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/servicios.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/ticket.dart';
import '../estilos_soporte.dart';

/// Un ticket en la lista: el asunto, hace cuánto se movió, su estado, su
/// categoría y, si el equipo escribió lo último, «Soporte respondió».
class TarjetaTicket extends StatelessWidget {
  final Ticket ticket;
  final VoidCallback onTap;

  const TarjetaTicket({super.key, required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final estado = context.estadoTicket(ticket.estado);
    final categoria = context.categoriaTicket(ticket.categoria);
    final actividad = ticket.ultimaActividad;
    final respondio = ticket.respondioSoporte && !ticket.estado.atendido;

    return TarjetaTranslucida(
      onTap: onTap,
      tinte: respondio ? AppColors.acento : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  ticket.asunto,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (actividad != null) ...[
                const SizedBox(width: 8),
                Text(
                  haceCuanto(actividad, Servicios.reloj.instante()),
                  style: const TextStyle(
                    color: AppColors.textoTenue,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pastilla(
                texto: estado.nombre,
                color: estado.color,
                icono: estado.icono,
              ),
              Pastilla(
                texto: categoria.nombre,
                color: categoria.color,
                icono: categoria.icono,
              ),
              if (respondio)
                Pastilla(
                  key: const Key('soporte-respondio'),
                  texto: 'Soporte respondió',
                  color: AppColors.acentoClaro,
                  icono: Icons.mark_chat_unread_outlined,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
