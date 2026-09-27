import 'package:flutter/material.dart';

import '../../../../core/configuracion/en_contexto.dart';
import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/servicios.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/cita.dart';
import '../../dominio/videoconsulta.dart';
import '../estilos_cita.dart';
import 'hoja_calendario.dart';

/// Una cita en una lista: cuándo, con quién, cómo y para quién.
class TarjetaCita extends StatelessWidget {
  final Cita cita;
  final VoidCallback? onTap;

  /// La hora de la clínica, para saber si la sala de video está abierta
  /// (con la misma ventana que el botón para entrar, ver `estadoDeSala`).
  /// Sin ella se usa la de ahora.
  final DateTime? ahora;

  const TarjetaCita({super.key, required this.cita, this.onTap, this.ahora});

  @override
  Widget build(BuildContext context) {
    final apagada = !cita.pendiente;
    final modalidad = context.modalidad(cita.tipo);
    final estado = context.estadoCita(cita.estado);
    final medico = cita.medicoVisible;
    final sala = estadoDeSala(
      cita,
      ahora ?? Servicios.reloj.ahora(),
      VentanaDeSala.de(context.config.telemedicina),
    );

    return TarjetaTranslucida(
      onTap: onTap,
      tinte: apagada ? null : modalidad.color,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HojaCalendario(
            fecha: cita.inicio,
            color: apagada ? AppColors.bordeCampo : AppColors.acento,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FormatoFecha.rangoHoras(cita.inicio, cita.fin),
                  style: TextStyle(
                    color: apagada
                        ? AppColors.textoSecundario
                        : AppColors.texto,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (medico != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    medico,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (cita.especialidad != null)
                  Text(
                    cita.especialidad!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pastilla(
                      texto: modalidad.nombre,
                      color: modalidad.color,
                      icono: modalidad.icono,
                    ),
                    Pastilla(
                      texto: estado.nombre,
                      color: estado.color,
                      icono: estado.icono,
                    ),
                    if (cita.paraDependiente)
                      Pastilla(
                        texto:
                            'Para ${cita.pacienteNombre ?? 'un dependiente'}',
                        color: AppColors.acentoClaro,
                        icono: Icons.family_restroom_rounded,
                      ),
                    if (sala == EstadoSala.abierta)
                      const Pastilla(
                        texto: 'Sala abierta',
                        color: AppColors.exito,
                        icono: Icons.videocam_rounded,
                      ),
                  ],
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
    );
  }
}

/// Los consejos para prepararse, en un recuadro.
class ConsejosDePreparacion extends StatelessWidget {
  final List<String> consejos;
  final Color color;

  const ConsejosDePreparacion({
    super.key,
    required this.consejos,
    this.color = AppColors.acentoClaro,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates_outlined, color: color, size: 17),
              const SizedBox(width: 7),
              Text(
                'Cómo prepararte',
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          for (final consejo in consejos)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: Icon(
                      Icons.circle,
                      size: 5,
                      color: AppColors.textoSuave,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      consejo,
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
