import 'package:flutter/material.dart';

import '../../../../core/fechas/instante.dart';
import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/consulta.dart';
import '../../dominio/reglas_consultas.dart';
import '../estilos_consulta.dart';

/// Una consulta en una lista: qué, con quién, en qué va y cuánto falta.
class TarjetaConsulta extends StatelessWidget {
  final ConsultaResumen consulta;

  /// El instante de ahora, para el plazo.
  final DateTime ahora;

  final VoidCallback? onTap;

  /// Acciones al pie (en los borradores: seguir y eliminar).
  final Widget? acciones;

  const TarjetaConsulta({
    super.key,
    required this.consulta,
    required this.ahora,
    this.onTap,
    this.acciones,
  });

  @override
  Widget build(BuildContext context) {
    final estado = consulta.estado;
    final plazo = tiempoRestante(consulta, ahora);
    final apagada = estado.terminada;
    final actividad = consulta.ultimaActividad;

    return TarjetaTranslucida(
      onTap: onTap,
      tinte: apagada ? null : estado.color,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: estado.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(estado.icono, color: estado.color, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consulta.motivoNombre.isEmpty
                          ? 'Consulta en línea'
                          : consulta.motivoNombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: apagada
                            ? AppColors.textoSecundario
                            : AppColors.texto,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        consulta.medicoVisible,
                        if (consulta.especialidad.isNotEmpty)
                          consulta.especialidad,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (actividad != null || consulta.codigo.isNotEmpty)
                      Text(
                        [
                          if (consulta.codigo.isNotEmpty) consulta.codigo,
                          if (actividad != null)
                            FormatoFecha.cortaConHora(
                              enHoraDeLaClinica(actividad),
                            ),
                        ].join(' · '),
                        style: const TextStyle(
                          color: AppColors.textoSecundario,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 6, top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textoSecundario,
                  ),
                ),
            ],
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
              if (plazo != null)
                Pastilla(
                  texto: plazo,
                  color: colorDelPlazo(plazo),
                  icono: plazo == 'Demorada'
                      ? Icons.running_with_errors_rounded
                      : Icons.hourglass_bottom_rounded,
                ),
              if (consulta.respuestaPorLeer)
                const Pastilla(
                  texto: 'Respuesta del médico',
                  color: AppColors.exito,
                  icono: Icons.mark_unread_chat_alt_outlined,
                ),
              if (consulta.paraDependiente)
                Pastilla(
                  texto:
                      'Para ${consulta.pacienteNombre.isEmpty ? 'un dependiente' : consulta.pacienteNombre}',
                  color: AppColors.menta,
                  icono: Icons.family_restroom_rounded,
                ),
            ],
          ),
          if (acciones != null) ...[const SizedBox(height: 10), acciones!],
        ],
      ),
    );
  }
}
