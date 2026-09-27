import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/configuracion/en_contexto.dart';
import '../../../../core/presentacion/widgets/campos.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../../citas/data/models/cita.dart';
import '../../../citas/presentacion/estilos_cita.dart';
import '../../dominio/huecos.dart';
import '../../providers/agendar_bloc.dart';
import '../../providers/agendar_event.dart';
import '../../providers/agendar_state.dart';
import '../widgets/con_proximos_turnos.dart';
import '../widgets/opcion_seleccionable.dart';

/// Paso 2: la especialidad. Cada una dice cuántos médicos tienen turnos
/// libres y cuándo es el primero; al tocarla se pasa a sus médicos. Arriba,
/// la ciudad y la modalidad, opcionales, que vuelven a pedir los turnos.
///
/// Solo aparecen las especialidades con algún médico disponible: en un
/// teléfono, elegir una sin turnos es un callejón sin salida.
class PasoFiltros extends StatelessWidget {
  final AgendarState state;

  const PasoFiltros({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final hayCiudades =
        state.ciudades.length > 1 || state.filtroCiudad.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Elige la especialidad. Cada una dice cuántos médicos tienen turnos '
          'libres y cuándo es el primero.',
          style: TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        if (hayCiudades) ...[
          _FiltroCiudad(state: state),
          const SizedBox(height: 16),
        ],
        _FiltroModalidad(elegida: state.filtroModalidad),
        const SizedBox(height: 22),
        ConProximosTurnos(
          state: state,
          child: state.medicos.isEmpty
              ? _SinTurnos(state: state)
              : _Especialidades(state: state),
        ),
      ],
    );
  }
}

class _FiltroCiudad extends StatelessWidget {
  final AgendarState state;

  const _FiltroCiudad({required this.state});

  static const String _cualquiera = '';

  @override
  Widget build(BuildContext context) {
    final elegida = state.filtroCiudad;
    final ciudades = state.ciudades;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EtiquetaCampo('Ciudad'),
        SelectorCliniq<String>(
          key: ValueKey('ciudad-$elegida'),
          valor: elegida,
          opciones: [
            _cualquiera,
            ...ciudades,
            if (elegida.isNotEmpty && !ciudades.contains(elegida)) elegida,
          ],
          etiqueta: (c) => c.isEmpty ? 'Cualquier ciudad' : c,
          pista: 'Cualquier ciudad',
          icono: Icons.location_city_rounded,
          onChanged: (valor) => context.read<AgendarBloc>().add(
            AgendarFiltrosCambiados(ciudad: valor ?? _cualquiera),
          ),
        ),
      ],
    );
  }
}

class _FiltroModalidad extends StatelessWidget {
  final TipoCita? elegida;

  const _FiltroModalidad({required this.elegida});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AgendarBloc>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EtiquetaCampo('Modalidad'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Chip(
              texto: 'Cualquiera',
              icono: Icons.all_inclusive_rounded,
              color: AppColors.primarioClaro,
              elegido: elegida == null,
              onTap: () => bloc.add(
                const AgendarFiltrosCambiados(quitarModalidad: true),
              ),
            ),
            for (final tipo in modalidadesDelCatalogo(context.catalogos))
              Builder(
                builder: (context) {
                  final estilo = context.modalidad(tipo);

                  return _Chip(
                    texto: estilo.nombre,
                    icono: estilo.icono,
                    color: estilo.color,
                    elegido: elegida == tipo,
                    onTap: () =>
                        bloc.add(AgendarFiltrosCambiados(modalidad: tipo)),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// Ningún médico con turnos libres: con filtros, se ofrece quitarlos.
class _SinTurnos extends StatelessWidget {
  final AgendarState state;

  const _SinTurnos({required this.state});

  @override
  Widget build(BuildContext context) {
    final conFiltros =
        state.filtroCiudad.isNotEmpty || state.filtroModalidad != null;
    final dias = state.reglas.diasHorizonte;

    return EstadoVacio(
      icono: Icons.event_busy_rounded,
      titulo: 'Sin turnos disponibles',
      descripcion: conFiltros
          ? 'Ningún médico tiene turnos libres con esos filtros. Prueba '
                'quitando alguno.'
          : 'Por ahora ningún médico tiene turnos libres en los próximos '
                '${dias == 1 ? 'día' : '$dias días'}. Vuelve a intentarlo '
                'más tarde.',
      accion: conFiltros ? 'Quitar filtros' : 'Reintentar',
      alPulsar: () => context.read<AgendarBloc>().add(
        conFiltros
            ? const AgendarFiltrosCambiados(ciudad: '', quitarModalidad: true)
            : const AgendarProximosReintentados(),
      ),
    );
  }
}

class _Especialidades extends StatelessWidget {
  final AgendarState state;

  const _Especialidades({required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AgendarBloc>();
    final general = state.primerTurnoGeneral;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EtiquetaSeccion('Especialidades'),
        OpcionSeleccionable(
          key: const ValueKey('especialidad-todas'),
          titulo: 'Todas las especialidades',
          descripcion: resumenDisponibilidad(
            state.medicos.length,
            general?.turno.inicio,
            state.ahora,
          ),
          icono: Icons.groups_2_outlined,
          elegida: false,
          onTap: () => bloc.add(const AgendarEspecialidadElegida('')),
        ),
        const SizedBox(height: 10),
        for (final especialidad in state.especialidades) ...[
          OpcionSeleccionable(
            key: ValueKey('especialidad-${especialidad.nombre}'),
            titulo: especialidad.nombre,
            descripcion: resumenDisponibilidad(
              especialidad.medicos,
              especialidad.proximo?.inicio,
              state.ahora,
            ),
            icono: Icons.medical_services_outlined,
            elegida: state.especialidadElegida == especialidad,
            onTap: () =>
                bloc.add(AgendarEspecialidadElegida(especialidad.nombre)),
          ),
          const SizedBox(height: 10),
        ],
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
