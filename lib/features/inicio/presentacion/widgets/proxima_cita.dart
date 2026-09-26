import 'package:flutter/material.dart';

import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../../citas/data/models/cita.dart';
import '../../../citas/dominio/reglas_citas.dart';
import '../../../citas/presentacion/estilos_cita.dart';
import '../../../citas/presentacion/widgets/detalle_cita.dart';
import '../../../citas/presentacion/widgets/hoja_calendario.dart';
import '../../../citas/presentacion/widgets/tarjeta_cita.dart';

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

  @override
  Widget build(BuildContext context) {
    return TarjetaTranslucida(
      tinte: cita.tipo.color,
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
                    const SizedBox(height: 5),
                    Text(
                      cita.medicoVisible,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                texto: cita.tipo.nombre,
                color: cita.tipo.color,
                icono: cita.tipo.icono,
              ),
              if (cita.paraDependiente)
                Pastilla(
                  texto: 'Para ${cita.pacienteNombre ?? 'un dependiente'}',
                  color: AppColors.menta,
                  icono: Icons.family_restroom_rounded,
                ),
            ],
          ),
          const SizedBox(height: 14),
          ConsejosDePreparacion(
            consejos: consejosPara(cita.tipo),
            color: cita.tipo.color,
          ),
        ],
      ),
    );
  }
}
