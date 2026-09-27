import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/servicios.dart';
import '../../../../core/tema/tokens.dart';
import '../../../agendar/presentacion/widgets/opcion_seleccionable.dart';
import '../../../dependientes/data/models/dependiente.dart';
import '../../../dependientes/dominio/validaciones.dart';
import '../../../dependientes/presentacion/formulario_dependiente_page.dart';
import '../../providers/nueva_consulta_bloc.dart';
import '../../providers/nueva_consulta_event.dart';
import '../../providers/nueva_consulta_state.dart';

/// Paso 1: ¿para quién es la consulta? Para uno mismo o para un dependiente.
class PasoPacienteConsulta extends StatelessWidget {
  final NuevaConsultaState state;

  const PasoPacienteConsulta({super.key, required this.state});

  Future<void> _agregarDependiente(BuildContext context) async {
    final bloc = context.read<NuevaConsultaBloc>();

    final nuevo = await Navigator.of(context).push<Dependiente>(
      MaterialPageRoute(builder: (_) => const FormularioDependientePage()),
    );

    if (nuevo != null) {
      bloc.add(NuevaConsultaDependientesRecargados(elegir: nuevo.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NuevaConsultaBloc>();
    final hoy = Servicios.reloj.hoy();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Escríbele a un médico sin ir a la clínica: le cuentas qué pasa, '
          'adjuntas fotos o exámenes y te responde por aquí en menos de 48 '
          'horas. Puede ser para ti o para alguien a tu cargo.',
          style: TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        OpcionSeleccionable(
          titulo: 'Para mí',
          descripcion: state.nombreTitular,
          icono: Icons.person_rounded,
          color: AppColors.acentoClaro,
          elegida: state.para == consultaParaMi,
          onTap: () => bloc.add(const NuevaConsultaParaElegido(consultaParaMi)),
        ),
        if (state.dependientes.isNotEmpty) ...[
          const SizedBox(height: 22),
          const EtiquetaSeccion('Tus dependientes'),
          for (final d in state.dependientes) ...[
            OpcionSeleccionable(
              titulo: d.nombre,
              descripcion: [
                if (d.parentesco != null) d.parentesco!,
                if (edad(d.fechaNacimiento, hoy) != null)
                  '${edad(d.fechaNacimiento, hoy)} años',
              ].join(' · '),
              icono: Icons.family_restroom_rounded,
              color: AppColors.menta,
              elegida: state.para == d.uid,
              onTap: () => bloc.add(NuevaConsultaParaElegido(d.uid)),
            ),
            const SizedBox(height: 10),
          ],
        ],
        const SizedBox(height: 16),
        BotonSecundario(
          texto: 'Agregar dependiente',
          icono: Icons.person_add_alt_1_rounded,
          onPressed: () => _agregarDependiente(context),
        ),
      ],
    );
  }
}
