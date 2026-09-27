import 'package:flutter/material.dart';

import '../../../../core/configuracion/en_contexto.dart';
import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../../citas/dominio/reglas_citas.dart';
import '../../../citas/presentacion/estilos_cita.dart';
import '../../../citas/presentacion/widgets/tarjeta_cita.dart';
import '../../providers/agendar_state.dart';

/// Paso 7: todo lo elegido, para revisarlo antes de confirmar.
class PasoResumen extends StatelessWidget {
  final AgendarState state;

  const PasoResumen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final hueco = state.huecoValido ?? state.hueco;
    final medico = state.medico;
    final original = state.original;
    final modalidad = context.modalidad(state.tipo);
    final consejos = consejosPara(context.catalogos, state.tipo);
    final horasMinimas = context.config.agenda.horasMinimasCambio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.errorGuardar != null) ...[
          RecuadroAviso.error(state.errorGuardar!),
          const SizedBox(height: 14),
        ],
        TarjetaTranslucida(
          tinte: modalidad.color,
          child: Column(
            children: [
              FilaDato(
                icono: Icons.person_outline_rounded,
                rotulo: 'Paciente',
                valor: original?.pacienteNombre ?? state.pacienteNombre,
              ),
              FilaDato(
                icono: Icons.medical_information_outlined,
                rotulo: 'Médico',
                valor: medico == null
                    ? null
                    : [
                        if (medico.nombre.isNotEmpty) medico.nombre,
                        ?medico.especialidad,
                      ].join(' · '),
              ),
              FilaDato(
                icono: modalidad.icono,
                rotulo: 'Modalidad',
                valor: '${modalidad.nombre} · ${state.duracion} minutos',
              ),
              if (original != null)
                FilaDato(
                  icono: Icons.history_rounded,
                  rotulo: 'Antes',
                  valor:
                      '${FormatoFecha.diaLargo(original.inicio)}, '
                      '${FormatoFecha.rangoHoras(original.inicio, original.fin)}',
                ),
              FilaDato(
                icono: Icons.event_rounded,
                rotulo: original != null ? 'Ahora' : 'Fecha',
                valor: hueco == null
                    ? null
                    : '${FormatoFecha.diaLargo(hueco.inicio)}, '
                          '${FormatoFecha.rangoHoras(hueco.inicio, hueco.fin)}',
              ),
              if (original == null)
                FilaDato(
                  icono: Icons.notes_rounded,
                  rotulo: 'Motivo',
                  valor: state.motivoLimpio,
                ),
            ],
          ),
        ),
        if (consejos.isNotEmpty) ...[
          const SizedBox(height: 16),
          ConsejosDePreparacion(consejos: consejos),
        ],
        const SizedBox(height: 14),
        Text(
          'Te enviaremos la confirmación a tu correo. Podrás cancelarla o '
          'reprogramarla hasta ${horas(horasMinimas)} antes.',
          style: const TextStyle(
            color: AppColors.textoTenue,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
