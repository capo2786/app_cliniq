import 'package:flutter/material.dart';

import '../../../../core/configuracion/en_contexto.dart';
import '../../../../core/fechas/fecha_local.dart';
import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../../citas/data/models/cita.dart';
import '../../../citas/dominio/reglas_citas.dart';
import '../../../citas/dominio/videoconsulta.dart';
import '../../../citas/presentacion/estilos_cita.dart';
import '../../../citas/presentacion/widgets/detalle_cita.dart';
import '../../../citas/presentacion/widgets/hoja_calendario.dart';
import '../../../citas/presentacion/widgets/tarjeta_cita.dart';
import '../../../citas/presentacion/widgets/videoconsulta.dart';

/// «Tu próxima cita»: cuándo, con quién, cuánto falta y cómo prepararse.
///
/// Es la respuesta a la pregunta con la que casi todos abren la aplicación,
/// así que va entera en la portada y no detrás de un toque.
class TarjetaProximaCita extends StatelessWidget {
  final Cita cita;
  final DateTime ahora;

  const TarjetaProximaCita({
    super.key,
    required this.cita,
    required this.ahora,
  });

  bool _salaALaVista(VentanaDeSala ventana) =>
      switch (estadoDeSala(cita, ahora, ventana)) {
        EstadoSala.abierta => true,
        EstadoSala.porAbrir => mismoDia(cita.inicio, ahora),
        _ => false,
      };

  @override
  Widget build(BuildContext context) {
    final modalidad = context.modalidad(cita.tipo);
    final consejos = consejosPara(context.catalogos, cita.tipo);
    final medico = cita.medicoVisible;
    final ventana = VentanaDeSala.de(context.config.telemedicina);

    return TarjetaTranslucida(
      tinte: modalidad.color,
      onTap: () => mostrarDetalleCita(context, cita),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HojaCalendario(fecha: cita.inicio, ancho: 70),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      FormatoFecha.diaLargo(cita.inicio),
                      style: const TextStyle(
                        color: AppColors.textoSuave,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      FormatoFecha.rangoHoras(cita.inicio, cita.fin),
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (medico != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        medico,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (cita.especialidad != null)
                      Text(
                        cita.especialidad!,
                        style: const TextStyle(
                          color: AppColors.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pastilla(
                texto: cuentaRegresiva(cita, ahora),
                color: AppColors.acentoClaro,
                icono: Icons.hourglass_bottom_rounded,
              ),
              Pastilla(
                texto: modalidad.nombre,
                color: modalidad.color,
                icono: modalidad.icono,
              ),
              if (cita.paraDependiente)
                Pastilla(
                  texto: 'Para ${cita.pacienteNombre ?? 'un dependiente'}',
                  color: AppColors.menta,
                  icono: Icons.family_restroom_rounded,
                ),
            ],
          ),
          if (consejos.isNotEmpty) ...[
            const SizedBox(height: 14),
            ConsejosDePreparacion(consejos: consejos, color: modalidad.color),
          ],
          // El botón de la sala va aquí mismo el día de la cita: es lo que
          // se busca al abrir la aplicación diez minutos antes.
          if (_salaALaVista(ventana)) ...[
            const SizedBox(height: 14),
            BotonVideoconsulta(cita: cita, compacto: true),
          ],
        ],
      ),
    );
  }
}
