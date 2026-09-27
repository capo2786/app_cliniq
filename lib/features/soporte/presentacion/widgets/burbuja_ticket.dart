// lib/features/soporte/presentacion/widgets/burbuja_ticket.dart

import 'package:flutter/material.dart';

import '../../../../core/formato/instantes.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/ticket.dart';

/// Un mensaje de la conversación con soporte, como en cualquier chat: lo
/// propio a la derecha y lo del equipo a la izquierda, con otro color y su
/// marca «Soporte». La descripción del ticket abre el hilo.
class BurbujaTicket extends StatelessWidget {
  final String texto;
  final bool esSoporte;

  /// El nombre de quien escribió en el equipo; lo propio dice «Tú».
  final String autor;

  final DateTime? fecha;

  /// La primera burbuja: lo que se contó al abrir el ticket.
  final bool esDescripcion;

  /// Si el mensaje lleva un archivo, qué hacer al tocarlo.
  final VoidCallback? alVerAdjunto;

  const BurbujaTicket({
    super.key,
    required this.texto,
    required this.esSoporte,
    required this.autor,
    this.fecha,
    this.esDescripcion = false,
    this.alVerAdjunto,
  });

  /// Un mensaje de la conversación.
  factory BurbujaTicket.mensaje(
    MensajeTicket mensaje, {
    VoidCallback? alVerAdjunto,
  }) => BurbujaTicket(
    key: ValueKey('mensaje-${mensaje.id}'),
    texto: mensaje.texto,
    esSoporte: mensaje.esSoporte,
    autor: mensaje.esSoporte
        ? (mensaje.autorNombre.isEmpty ? 'Soporte' : mensaje.autorNombre)
        : 'Tú',
    fecha: mensaje.fecha,
    alVerAdjunto: mensaje.adjuntoId == null ? null : alVerAdjunto,
  );

  @override
  Widget build(BuildContext context) {
    final color = esSoporte ? AppColors.primarioClaro : AppColors.acento;
    final colorAutor = esSoporte
        ? AppColors.primarioClaro
        : AppColors.acentoSuave;
    final fecha = this.fecha;

    return Align(
      alignment: esSoporte ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(13, 10, 13, 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: esSoporte ? 0.12 : 0.16),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(esSoporte ? 4 : 18),
              bottomRight: Radius.circular(esSoporte ? 18 : 4),
            ),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    esSoporte
                        ? Icons.support_agent_rounded
                        : Icons.person_outline_rounded,
                    size: 14,
                    color: colorAutor,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      esSoporte ? 'Soporte · $autor' : autor,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorAutor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (esDescripcion) ...[
                const SizedBox(height: 4),
                const Text(
                  'DESCRIPCIÓN DEL PROBLEMA',
                  style: TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
              const SizedBox(height: 5),
              SelectableText(
                texto,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 14,
                  height: 1.42,
                ),
              ),
              if (alVerAdjunto != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: alVerAdjunto,
                  icon: const Icon(Icons.attach_file_rounded, size: 17),
                  label: const Text('Ver adjunto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.texto,
                    side: BorderSide(color: color.withValues(alpha: 0.5)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
              if (fecha != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    selloLegible(fecha),
                    style: const TextStyle(
                      color: AppColors.textoSecundario,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
