import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../../citas/presentacion/estilos_cita.dart';
import '../../data/models/medico_portal.dart';
import '../../dominio/horarios.dart';
import '../../dominio/huecos.dart';
import '../../providers/agendar_bloc.dart';
import '../../providers/agendar_event.dart';
import '../../providers/agendar_state.dart';

/// Paso 3: el médico. Cada tarjeta dice qué modalidades ofrece, cuándo
/// atiende y cuál es su primera fecha libre.
class PasoMedico extends StatelessWidget {
  final AgendarState state;

  const PasoMedico({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AgendarBloc>();
    final medicos = state.medicosFiltrados;

    if (medicos.isEmpty) {
      return EstadoVacio(
        icono: Icons.person_search_rounded,
        titulo: 'Ningún médico coincide',
        descripcion:
            'No encontramos médicos con esos filtros. Cambia la '
            'especialidad, la ciudad o la modalidad.',
        accion: 'Cambiar filtros',
        alPulsar: () =>
            bloc.add(const AgendarPasoCambiado(PasoAgendar.filtros)),
      );
    }

    return Column(
      children: [
        for (final medico in medicos) ...[
          _TarjetaMedico(
            medico: medico,
            ahora: state.ahora,
            elegido: state.medicoId == medico.uid,
            onTap: () => bloc.add(AgendarMedicoElegido(medico.uid)),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _TarjetaMedico extends StatelessWidget {
  final MedicoPortal medico;
  final DateTime ahora;
  final bool elegido;
  final VoidCallback onTap;

  const _TarjetaMedico({
    required this.medico,
    required this.ahora,
    required this.elegido,
    required this.onTap,
  });

  String get _iniciales {
    final partes = medico.nombre
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final modalidades = medico.modalidadesOfrecidas;
    final proxima = proximaFecha(
      medico,
      duracionDe(medico, modalidades.first),
      ahora,
    );
    final sinFechas = proxima == 'Sin fechas próximas';

    return TarjetaTranslucida(
      onTap: onTap,
      tinte: elegido ? AppColors.acento : null,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppGradientes.encabezado,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _iniciales,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medico.nombreVisible,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        medico.especialidad ?? 'Medicina',
                        if (medico.ciudad != null) medico.ciudad!,
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppColors.textoSecundario,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textoSecundario,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tipo in modalidades)
                Pastilla(
                  texto: tipo.nombre,
                  color: tipo.color,
                  icono: tipo.icono,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 15,
                color: AppColors.primarioClaro,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  resumenHorario(medico.horariosAtencion),
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.event_available_rounded,
                size: 15,
                color: sinFechas ? AppColors.textoTenue : AppColors.exito,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sinFechas ? proxima : 'Próxima fecha: $proxima',
                  style: TextStyle(
                    color: sinFechas ? AppColors.textoTenue : AppColors.exito,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
