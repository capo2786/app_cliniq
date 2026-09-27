import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../dominio/reglas_consultas.dart';
import '../../providers/nueva_consulta_bloc.dart';
import '../../providers/nueva_consulta_event.dart';
import '../../providers/nueva_consulta_state.dart';
import '../widgets/adjuntos.dart';
import '../../../../core/configuracion/en_contexto.dart';
import '../../../../core/presentacion/widgets/contacto_clinica.dart';
import '../../../citas/dominio/reglas_citas.dart' show horas;

/// Paso 6: todo lo que va a leer el médico, para revisarlo antes de enviar.
class PasoResumenConsulta extends StatelessWidget {
  final NuevaConsultaState state;

  const PasoResumenConsulta({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NuevaConsultaBloc>();
    final respondidas = [
      for (final campo in state.campos)
        if (!valorVacio(state.respuestas[campo.clave])) campo,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.errorGuardar != null) ...[
          RecuadroAviso.error(state.errorGuardar!),
          const SizedBox(height: 14),
        ],
        TarjetaTranslucida(
          tinte: AppColors.acentoClaro,
          child: Column(
            children: [
              FilaDato(
                icono: Icons.person_outline_rounded,
                rotulo: 'Paciente',
                valor: state.pacienteNombre,
              ),
              FilaDato(
                icono: Icons.medical_services_outlined,
                rotulo: 'Especialidad',
                valor: state.especialidad,
              ),
              FilaDato(
                icono: Icons.assignment_outlined,
                rotulo: 'Motivo',
                valor: state.motivo?.nombre,
              ),
              FilaDato(
                icono: Icons.medical_information_outlined,
                rotulo: 'Médico',
                valor: state.medico?.nombre,
              ),
            ],
          ),
        ),
        if (respondidas.isNotEmpty) ...[
          const SizedBox(height: 20),
          const EtiquetaSeccion('Tus respuestas'),
          TarjetaTranslucida(
            child: Column(
              children: [
                for (final campo in respondidas)
                  FilaDato(
                    icono: Icons.check_circle_outline_rounded,
                    rotulo: campo.etiqueta,
                    valor: valorLegible(
                      campo.tipo,
                      state.respuestas[campo.clave],
                      unidad: campo.unidad,
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        const EtiquetaSeccion('Lo que le cuentas'),
        TarjetaTranslucida(
          child: Text(
            state.descripcionLimpia,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
        if (state.adjuntos.isNotEmpty) ...[
          const SizedBox(height: 20),
          EtiquetaSeccion(
            state.adjuntos.length == 1
                ? '1 archivo'
                : '${state.adjuntos.length} archivos',
          ),
          for (final adjunto in state.adjuntos) ...[
            FilaAdjunto(
              nombre: adjunto.nombre,
              tamano: adjunto.tamano,
              esImagen: adjunto.esImagen,
              nota: adjunto is AdjuntoPendiente ? 'Se sube al enviar' : null,
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: state.guardando
                ? null
                : () => bloc.add(
                    const NuevaConsultaPasoCambiado(PasoConsulta.formulario),
                  ),
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: const Text('Cambiar algo'),
            style: TextButton.styleFrom(foregroundColor: AppColors.acentoSuave),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Al enviarla, el médico tiene '
          '${horas(context.config.telemedicina.horasRespuesta)} para '
          'responderte y te avisaremos por correo. Si es una emergencia, no '
          'esperes: ve a la emergencia más cercana o llama al '
          '${context.config.clinica.telefonoEmergencia}.',
          style: const TextStyle(
            color: AppColors.textoTenue,
            fontSize: 12,
            height: 1.4,
          ),
        ),
        const BotonEmergencia(),
      ],
    );
  }
}
