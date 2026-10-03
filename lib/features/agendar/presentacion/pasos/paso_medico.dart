import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/tema/tokens.dart';
import '../../dominio/huecos.dart';
import '../../providers/agendar_bloc.dart';
import '../../providers/agendar_event.dart';
import '../../providers/agendar_state.dart';
import '../widgets/buscador_medicos.dart';
import '../widgets/con_proximos_turnos.dart';
import '../widgets/tarjeta_medico.dart';
import '../widgets/tarjeta_primer_turno.dart';
import '../../../ayuda/presentacion/widgets/boton_ayuda.dart';

/// Paso 3: el médico.
///
/// Arriba, «El primer turno disponible» de la especialidad: con un toque
/// deja elegidos ese médico y ese turno y pasa al motivo. Debajo, un
/// buscador por nombre y los médicos con turnos libres, cada uno con su
/// próximo turno.
class PasoMedico extends StatelessWidget {
  final AgendarState state;

  const PasoMedico({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ConProximosTurnos(
      state: state,
      child: state.medicosDeLaEspecialidad.isEmpty
          ? _SinMedicos(especialidad: state.filtroEspecialidad)
          : _ListaDeMedicos(state: state),
    );
  }
}

class _SinMedicos extends StatelessWidget {
  final String especialidad;

  const _SinMedicos({required this.especialidad});

  @override
  Widget build(BuildContext context) {
    return EstadoVacio(
      icono: Icons.person_search_rounded,
      titulo: 'Ningún médico disponible',
      descripcion: especialidad.isEmpty
          ? 'Por ahora ningún médico tiene turnos libres con esos filtros.'
          : 'Por ahora ningún médico de $especialidad tiene turnos libres. '
                'Prueba con otra especialidad.',
      accion: 'Cambiar especialidad',
      alPulsar: () => context.read<AgendarBloc>().add(
        const AgendarPasoCambiado(PasoAgendar.filtros),
      ),
    );
  }
}

class _ListaDeMedicos extends StatelessWidget {
  final AgendarState state;

  const _ListaDeMedicos({required this.state});

  /// Cierra el teclado del buscador antes de elegir.
  void _elegir(BuildContext context, AgendarEvent evento) {
    cerrarTeclado();
    context.read<AgendarBloc>().add(evento);
  }

  void _buscar(BuildContext context, String texto) =>
      context.read<AgendarBloc>().add(AgendarBusquedaCambiada(texto));

  @override
  Widget build(BuildContext context) {
    final especialidad = state.filtroEspecialidad;
    final medicos = state.medicosFiltrados;
    // Mientras se busca a alguien por nombre, la tarjeta de otro estorba.
    final primero = state.busqueda.trim().isEmpty ? state.primerTurno : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            especialidad.isEmpty ? 'Todas las especialidades' : especialidad,
            '${cantidadDeMedicos(state.medicosDeLaEspecialidad.length)} con '
                'turnos libres',
          ].join(' · '),
          style: const TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        if (primero != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TarjetaPrimerTurno(
                  primero: primero,
                  ahora: state.ahora,
                  confirmando: state.confirmandoPrimerTurno,
                  onTap: () => _elegir(
                    context,
                    AgendarPrimerTurnoElegido(primero.turno),
                  ),
                ),
              ),
              const BotonAyuda(clave: 'app.agendar.primerTurno', enLinea: true),
            ],
          ),
          const SizedBox(height: 18),
        ],
        BuscadorMedicos(
          texto: state.busqueda,
          alCambiar: (texto) => _buscar(context, texto),
        ),
        const SizedBox(height: 14),
        if (medicos.isEmpty)
          EstadoVacio(
            icono: Icons.person_search_rounded,
            titulo: 'Ningún médico se llama así',
            descripcion:
                'No encontramos a «${state.busqueda.trim()}» entre los '
                'médicos con turnos libres.',
            accion: 'Borrar búsqueda',
            alPulsar: () => _buscar(context, ''),
          )
        else
          for (final medico in medicos) ...[
            TarjetaMedico(
              medico: medico,
              ahora: state.ahora,
              elegido: state.medicoId == medico.uid,
              onTap: () => _elegir(context, AgendarMedicoElegido(medico.uid)),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}
