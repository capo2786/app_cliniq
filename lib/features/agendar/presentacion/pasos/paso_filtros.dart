import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/campos.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/tema/tokens.dart';
import '../../../citas/data/models/cita.dart';
import '../../../citas/presentacion/estilos_cita.dart';
import '../../providers/agendar_bloc.dart';
import '../../providers/agendar_event.dart';
import '../../providers/agendar_state.dart';

/// Paso 2: especialidad, ciudad y modalidad. Todos opcionales.
class PasoFiltros extends StatelessWidget {
  final AgendarState state;

  const PasoFiltros({super.key, required this.state});

  static const String _cualquiera = '';

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AgendarBloc>();
    final especialidades = state.especialidadesConMedicos;
    final ciudades = state.ciudades;
    final coinciden = state.medicosFiltrados.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filtra si ya sabes qué necesitas. Si no, sigue y verás a todos los '
          'médicos.',
          style: TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        const EtiquetaCampo('Especialidad'),
        SelectorCliniq<String>(
          key: ValueKey('esp-${state.filtroEspecialidad}'),
          valor: state.filtroEspecialidad,
          opciones: [_cualquiera, ...especialidades],
          etiqueta: (e) => e.isEmpty ? 'Cualquier especialidad' : e,
          pista: 'Cualquier especialidad',
          icono: Icons.medical_services_outlined,
          onChanged: (valor) => bloc.add(
            AgendarFiltrosCambiados(especialidad: valor ?? _cualquiera),
          ),
        ),
        const SizedBox(height: 16),
        const EtiquetaCampo('Ciudad'),
        SelectorCliniq<String>(
          key: ValueKey('ciudad-${state.filtroCiudad}'),
          valor: state.filtroCiudad,
          opciones: [_cualquiera, ...ciudades],
          etiqueta: (c) => c.isEmpty ? 'Cualquier ciudad' : c,
          pista: 'Cualquier ciudad',
          icono: Icons.location_city_rounded,
          onChanged: (valor) =>
              bloc.add(AgendarFiltrosCambiados(ciudad: valor ?? _cualquiera)),
        ),
        const SizedBox(height: 16),
        const EtiquetaCampo('Modalidad'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(
              texto: 'Cualquiera',
              icono: Icons.all_inclusive_rounded,
              color: AppColors.primarioClaro,
              elegido: state.filtroModalidad == null,
              onTap: () => bloc.add(
                const AgendarFiltrosCambiados(quitarModalidad: true),
              ),
            ),
            for (final tipo in TipoCita.values)
              _Chip(
                texto: tipo.nombre,
                icono: tipo.icono,
                color: tipo.color,
                elegido: state.filtroModalidad == tipo,
                onTap: () => bloc.add(AgendarFiltrosCambiados(modalidad: tipo)),
              ),
          ],
        ),
        const SizedBox(height: 22),
        coinciden == 0
            ? const RecuadroAviso.alerta(
                'Ningún médico coincide con esos filtros. Prueba quitando '
                'alguno.',
              )
            : RecuadroAviso.informacion(
                coinciden == 1
                    ? '1 médico coincide.'
                    : '$coinciden médicos coinciden.',
                icono: Icons.groups_2_outlined,
              ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Color color;
  final bool elegido;
  final VoidCallback onTap;

  const _Chip({
    required this.texto,
    required this.icono,
    required this.color,
    required this.elegido,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: elegido,
      onSelected: (_) => onTap(),
      avatar: Icon(icono, size: 17, color: elegido ? Colors.white : color),
      label: Text(texto),
      showCheckmark: false,
      labelStyle: TextStyle(
        color: elegido ? Colors.white : AppColors.textoSuave,
        fontWeight: FontWeight.w700,
      ),
      selectedColor: AppColors.acento,
      backgroundColor: AppColors.tarjetaPlana,
      side: BorderSide(
        color: elegido ? AppColors.acentoClaro : AppColors.bordeCampo,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
