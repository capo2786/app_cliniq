// lib/features/soporte/presentacion/widgets/encabezado_ticket.dart

import 'package:flutter/material.dart';

import '../../../../core/formato/instantes.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/ticket.dart';
import '../estilos_soporte.dart';

/// La cabecera de un ticket: el asunto, su estado, su categoría y
/// prioridad, cuándo se abrió y, mientras no esté atendido, hasta cuándo
/// se espera la respuesta.
class EncabezadoTicket extends StatelessWidget {
  final Ticket ticket;

  const EncabezadoTicket({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    final estado = context.estadoTicket(ticket.estado);
    final categoria = context.categoriaTicket(ticket.categoria);
    final severidad = context.severidadTicket(ticket.severidad);
    final creado = ticket.creadoEn;
    final vence = ticket.venceEn;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppEspaciado.xl),
      decoration: BoxDecoration(
        gradient: AppGradientes.encabezado,
        borderRadius: AppRadio.dePanel,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.sombraSuave,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ticket.asunto,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
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
              if (ticket.severidad.isNotEmpty)
                Pastilla(
                  texto: 'Prioridad ${severidad.nombre.toLowerCase()}',
                  color: severidad.color,
                  icono: severidad.icono,
                ),
            ],
          ),
          if (creado != null) ...[
            const SizedBox(height: 12),
            _Linea(
              icono: Icons.event_note_rounded,
              texto: 'Abierto el ${momentoLegible(creado).toLowerCase()}',
            ),
          ],
          if (!ticket.estado.atendido && vence != null) ...[
            const SizedBox(height: 4),
            _Linea(
              icono: Icons.schedule_rounded,
              texto:
                  'Respuesta estimada antes del '
                  '${momentoLegible(vence).toLowerCase()}',
            ),
          ],
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Linea({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 15, color: AppColors.textoSuave),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(color: AppColors.textoSuave, fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}
