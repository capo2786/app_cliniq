import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/fechas/fecha_local.dart';
import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../../citas/presentacion/estilos_cita.dart';
import '../../dominio/huecos.dart';
import '../../providers/agendar_bloc.dart';
import '../../providers/agendar_event.dart';
import '../../providers/agendar_state.dart';

/// Paso 5: el día en una tira que empieza en el primer día con atención, y
/// los horarios en fichas agrupadas por mañana, tarde y noche.
class PasoHorario extends StatelessWidget {
  final AgendarState state;

  const PasoHorario({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final medico = state.medico;
    final original = state.original;
    final modalidad = context.modalidad(state.tipo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (medico != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  medico.nombre,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Pastilla(
                  texto: '${modalidad.nombre} · ${state.duracion} min',
                  color: modalidad.color,
                  icono: modalidad.icono,
                ),
              ),
            ],
          ),
        if (original != null) ...[
          const SizedBox(height: 12),
          RecuadroAviso.informacion(
            'Hoy está agendada el ${FormatoFecha.diaLargo(original.inicio)} a '
            'las ${FormatoFecha.hora(original.inicio)}. Elige el nuevo día y '
            'hora.',
            icono: Icons.edit_calendar_rounded,
          ),
        ],
        if (state.aviso != null) ...[
          const SizedBox(height: 12),
          RecuadroAviso.alerta(state.aviso!, icono: Icons.event_busy_rounded),
        ],
        const SizedBox(height: 16),
        _TiraDeDias(state: state),
        const SizedBox(height: 18),
        _Horarios(state: state),
      ],
    );
  }
}

class _TiraDeDias extends StatelessWidget {
  final AgendarState state;

  const _TiraDeDias({required this.state});

  @override
  Widget build(BuildContext context) {
    final dias = state.diasDisponibles;
    final bloc = context.read<AgendarBloc>();

    if (dias.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dias.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final dia = dias[i];
          final elegido = state.fecha != null && mismoDia(state.fecha!, dia);
          final hoy = mismoDia(dia, state.ahora);

          return Semantics(
            button: true,
            selected: elegido,
            label: FormatoFecha.diaLargo(dia),
            child: InkWell(
              onTap: () => bloc.add(AgendarFechaElegida(dia)),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 64,
                decoration: BoxDecoration(
                  gradient: elegido ? AppGradientes.accion : null,
                  color: elegido ? null : AppColors.tarjetaPlana,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: elegido
                        ? AppColors.acentoClaro
                        : AppColors.bordeCampo,
                  ),
                  boxShadow: elegido
                      ? [
                          BoxShadow(
                            color: AppColors.acento.withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hoy ? 'Hoy' : FormatoFecha.diaCorto(dia),
                      style: TextStyle(
                        color: elegido
                            ? Colors.white
                            : AppColors.textoSecundario,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${dia.day}',
                      style: TextStyle(
                        color: elegido ? Colors.white : AppColors.texto,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      FormatoFecha.mesCortoMayusculas(dia),
                      style: TextStyle(
                        color: elegido ? Colors.white : AppColors.textoTenue,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Horarios extends StatelessWidget {
  final AgendarState state;

  const _Horarios({required this.state});

  static String _quien(String? nombre) =>
      nombre == null || nombre.trim().isEmpty ? 'El médico' : nombre;

  void _siguienteDia(BuildContext context) {
    final dias = state.diasDisponibles;
    final fecha = state.fecha;
    if (fecha == null) return;

    final siguiente = dias.where((d) => d.isAfter(fecha)).firstOrNull;
    if (siguiente != null) {
      context.read<AgendarBloc>().add(AgendarFechaElegida(siguiente));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AgendarBloc>();
    final fecha = state.fecha;
    final medico = state.medico;

    switch (state.estadoDia) {
      case EstadoDia.sinMedico:
        return const SizedBox.shrink();
      case EstadoDia.sinFecha:
        final dias = state.reglas.diasHorizonte;
        return EstadoVacio(
          icono: Icons.event_busy_rounded,
          titulo: 'Sin fechas disponibles',
          descripcion:
              'Este médico no tiene días de atención en los próximos '
              '${dias == 1 ? 'día' : '$dias días'}. Prueba con otro médico.',
        );
      case EstadoDia.pasado:
        return const RecuadroAviso.alerta('Ese día ya pasó. Elige otro.');
      case EstadoDia.bloqueado:
        final motivo = state.bloqueo?.motivo ?? '';
        return EstadoVacio(
          icono: Icons.beach_access_rounded,
          titulo: 'Ese día no atiende',
          descripcion: motivo.isEmpty
              ? '${_quien(medico?.nombre)} no atiende ese día.'
              : '${_quien(medico?.nombre)} no atiende ese día: $motivo.',
          accion: 'Ver el siguiente día',
          alPulsar: () => _siguienteDia(context),
        );
      case EstadoDia.noAtiende:
        return EstadoVacio(
          icono: Icons.event_busy_rounded,
          titulo: 'Ese día no hay atención',
          descripcion: 'Elige otro día de la tira.',
          accion: 'Ver el siguiente día',
          alPulsar: () => _siguienteDia(context),
        );
      case EstadoDia.cargando:
        return const CargandoCentro(mensaje: 'Viendo qué horarios quedan…');
      case EstadoDia.error:
        return EstadoError(
          mensaje: state.errorOcupados ?? 'No pudimos ver los horarios.',
          alReintentar: () => bloc.add(const AgendarOcupadosReintentados()),
        );
      case EstadoDia.limite:
        return EstadoVacio(
          icono: Icons.event_busy_rounded,
          titulo: 'Agenda completa',
          descripcion: 'El médico ya completó sus citas de ese día.',
          accion: 'Ver el siguiente día',
          alPulsar: () => _siguienteDia(context),
        );
      case EstadoDia.ok:
        break;
    }

    if (state.libres == 0) {
      return EstadoVacio(
        icono: Icons.hourglass_disabled_rounded,
        titulo: 'No quedan horarios libres',
        descripcion: fecha == null
            ? 'Elige otro día.'
            : 'El ${FormatoFecha.diaLargo(fecha).toLowerCase()} ya está '
                  'ocupado.',
        accion: 'Ver el siguiente día',
        alPulsar: () => _siguienteDia(context),
      );
    }

    final elegido = state.huecoValido;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.libres == 1
              ? '1 horario libre'
              : '${state.libres} horarios libres',
          style: const TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        for (final grupo in state.grupos.entries)
          if (grupo.value.isNotEmpty) ...[
            Row(
              children: [
                Icon(
                  switch (grupo.key) {
                    Periodo.manana => Icons.wb_sunny_outlined,
                    Periodo.tarde => Icons.wb_twilight_rounded,
                    Periodo.noche => Icons.nights_stay_outlined,
                  },
                  size: 17,
                  color: AppColors.primarioClaro,
                ),
                const SizedBox(width: 7),
                Text(
                  grupo.key.titulo.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hueco in grupo.value)
                  _FichaHorario(
                    hueco: hueco,
                    elegida: elegido?.hora == hueco.hora,
                    onTap: () => bloc.add(AgendarHuecoElegido(hueco)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],
      ],
    );
  }
}

class _FichaHorario extends StatelessWidget {
  final Hueco hueco;
  final bool elegida;
  final VoidCallback onTap;

  const _FichaHorario({
    required this.hueco,
    required this.elegida,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ocupado = hueco.ocupado;

    return Semantics(
      button: !ocupado,
      selected: elegida,
      label: ocupado ? '${hueco.hora}, ocupado' : hueco.hora,
      child: InkWell(
        onTap: ocupado ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 76,
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: elegida ? AppGradientes.accion : null,
            color: elegida
                ? null
                : ocupado
                ? AppColors.campo.withValues(alpha: 0.4)
                : AppColors.tarjetaPlana,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: elegida
                  ? AppColors.acentoClaro
                  : ocupado
                  ? AppColors.bordeDeshabilitado
                  : AppColors.bordeCampo,
            ),
          ),
          child: Text(
            hueco.hora,
            style: TextStyle(
              color: elegida
                  ? Colors.white
                  : ocupado
                  ? AppColors.textoTenue
                  : AppColors.texto,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              decoration: ocupado ? TextDecoration.lineThrough : null,
              decorationColor: AppColors.textoTenue,
            ),
          ),
        ),
      ),
    );
  }
}
