import 'package:flutter/material.dart';

import '../../../../core/tema/tokens.dart';
import '../../data/models/consulta.dart';
import '../../dominio/reglas_consultas.dart';
import 'adjuntos.dart';

/// Un mensaje de la conversación, como en cualquier chat: los del paciente a
/// la derecha, los del médico a la izquierda y con otro color.
class BurbujaMensaje extends StatelessWidget {
  final MensajeConsulta mensaje;

  const BurbujaMensaje({super.key, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    final medico = mensaje.esMedico;
    final color = medico ? AppColors.primarioClaro : AppColors.acento;
    final adjunto = mensaje.adjunto;
    final fecha = mensaje.fecha;

    final autor = medico
        ? (mensaje.autorNombre.isEmpty
              ? 'Médico'
              : 'Dr(a). ${mensaje.autorNombre}')
        : (mensaje.autorNombre.isEmpty ? 'Tú' : mensaje.autorNombre);

    return Align(
      alignment: medico ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(13, 10, 13, 9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: medico ? 0.12 : 0.16),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(medico ? 4 : 18),
              bottomRight: Radius.circular(medico ? 18 : 4),
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
                    medico
                        ? Icons.medical_information_outlined
                        : Icons.person_outline_rounded,
                    size: 14,
                    color: medico
                        ? AppColors.primarioClaro
                        : AppColors.acentoSuave,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      autor,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: medico
                            ? AppColors.primarioClaro
                            : AppColors.acentoSuave,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              SelectableText(
                mensaje.texto,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 14,
                  height: 1.42,
                ),
              ),
              if (adjunto != null) ...[
                const SizedBox(height: 8),
                FilaAdjunto(
                  nombre: adjunto.nombre,
                  tamano: adjunto.tamano,
                  esImagen: adjunto.esImagen,
                  onTap: () => abrirArchivo(context, adjunto),
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
