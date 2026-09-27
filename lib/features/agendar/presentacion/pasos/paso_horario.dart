import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/fechas/fecha_local.dart';
import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/tema/tokens.dart';
import '../../dominio/huecos.dart';
import '../../providers/agendar_bloc.dart';
import '../../providers/agendar_event.dart';
import '../../providers/agendar_state.dart';
import '../widgets/pastilla_modalidad.dart';

/// Paso 5: el día en una tira con los días que tienen turnos libres, y los
/// turnos de ese día en fichas agrupadas por mañana, tarde y noche.
///
/// Los turnos son los que calcula la API (`/portal/turnos/:doctorId`): aquí
/// no se calcula ninguno.
class PasoHorario extends StatelessWidget {
  final AgendarState state;

  const PasoHorario({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final medico = state.medico;
    final original = state.original;

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
                child: PastillaModalidad(
                  tipo: state.tipo,
                  detalle: '${state.duracion} min',
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
    final fecha = state.fecha;

    if (dias.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dias.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _DiaDeLaTira(
          dia: dias[i],
          hoy: mismoDia(dias[i], state.ahora),
          elegido: fecha != null && mismoDia(fecha, dias[i]),
        ),
      ),
    );
  }
}

/// Un día de la tira: «Lun», «28», «SEP».
class _DiaDeLaTira extends StatelessWidget {
  final DateTime dia;
  final bool hoy;
  final bool elegido;

  const _DiaDeLaTira({
    required this.dia,
    required this.hoy,
    required this.elegido,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle estilo(Color color, double tamano, FontWeight peso) => TextStyle(
      color: elegido ? Colors.white : color,
      fontSize: tamano,
      fontWeight: peso,
    );

    return Semantics(
      button: true,
      selected: elegido,
      label: FormatoFecha.diaLargo(dia),
      child: InkWell(
        onTap: () => context.read<AgendarBloc>().add(AgendarFechaElegida(dia)),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 64,
          decoration: BoxDecoration(
            gradient: elegido ? AppGradientes.accion : null,
            color: elegido ? null : AppColors.tarjetaPlana,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: elegido ? AppColors.acentoClaro : AppColors.bordeCampo,
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
                style: estilo(AppColors.textoSecundario, 12, FontWeight.w700),
              ),
              Text(
                '${dia.day}',
                style: estilo(AppColors.texto, 22, FontWeight.w900),
              ),
              Text(
                FormatoFecha.mesCortoMayusculas(dia),
                style: estilo(
                  AppColors.textoTenue,
                  10,
                  FontWeight.w800,
                ).copyWith(letterSpacing: 0.8),
              ),
            ],
          ),
        ),
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

    // El siguiente con turnos; si no hay, el primero de la tira.
    final siguiente =
        dias.where((d) => d.isAfter(fecha)).firstOrNull ??
        dias.where((d) => !mismoDia(d, fecha)).firstOrNull;
    if (siguiente != null) {
      context.read<AgendarBloc>().add(AgendarFechaElegida(siguiente));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AgendarBloc>();
    final fecha = state.fecha;

    switch (state.estadoDia) {
      case EstadoDia.sinMedico:
        return const SizedBox.shrink();
      case EstadoDia.cargando:
        return const CargandoCentro(mensaje: 'Buscando turnos libres…');
      case EstadoDia.error:
        return EstadoError(
          mensaje: state.errorTurnos ?? 'No pudimos ver los turnos libres.',
          alReintentar: () => bloc.add(const AgendarTurnosReintentados()),
        );
      case EstadoDia.sinTurnos:
        final dias = state.reglas.diasHorizonte;
        return EstadoVacio(
          icono: Icons.event_busy_rounded,
          titulo: 'Sin turnos libres',
          descripcion:
              '${_quien(state.medico?.nombre)} no tiene turnos libres en '
              'los próximos ${dias == 1 ? 'día' : '$dias días'}'
              '${state.reprogramando ? '.' : '. Prueba con otro médico.'}',
          accion: state.reprogramando ? null : 'Elegir otro médico',
          alPulsar: state.reprogramando
              ? null
              : () => bloc.add(const AgendarPasoCambiado(PasoAgendar.medico)),
        );
      case EstadoDia.sinFecha:
        return const RecuadroAviso.informacion(
          'Elige un día de la tira para ver sus turnos.',
          icono: Icons.touch_app_outlined,
        );
      case EstadoDia.diaSinTurnos:
        return EstadoVacio(
          icono: Icons.hourglass_disabled_rounded,
          titulo: 'No quedan turnos libres',
          descripcion: fecha == null
              ? 'Elige otro día.'
              : 'El ${FormatoFecha.diaLargo(fecha).toLowerCase()} ya no '
                    'tiene turnos libres.',
          accion: 'Ver el siguiente día',
          alPulsar: () => _siguienteDia(context),
        );
      case EstadoDia.ok:
        break;
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
            _EncabezadoPeriodo(periodo: grupo.key),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hueco in grupo.value)
                  _FichaHorario(
                    hueco: hueco,
                    elegida: elegido?.mismoHorario(hueco) ?? false,
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

/// «MAÑANA», «TARDE» o «NOCHE», con su icono.
class _EncabezadoPeriodo extends StatelessWidget {
  final Periodo periodo;

  const _EncabezadoPeriodo({required this.periodo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          switch (periodo) {
            Periodo.manana => Icons.wb_sunny_outlined,
            Periodo.tarde => Icons.wb_twilight_rounded,
            Periodo.noche => Icons.nights_stay_outlined,
          },
          size: 17,
          color: AppColors.primarioClaro,
        ),
        const SizedBox(width: 7),
        Text(
          periodo.titulo.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textoSuave,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
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
    return Semantics(
      button: true,
      selected: elegida,
      label: hueco.hora,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 76,
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: elegida ? AppGradientes.accion : null,
            color: elegida ? null : AppColors.tarjetaPlana,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: elegida ? AppColors.acentoClaro : AppColors.bordeCampo,
            ),
          ),
          child: Text(
            hueco.hora,
            style: TextStyle(
              color: elegida ? Colors.white : AppColors.texto,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
