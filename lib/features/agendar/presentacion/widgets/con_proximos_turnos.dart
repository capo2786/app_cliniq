import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/estados.dart';
import '../../providers/agendar_bloc.dart';
import '../../providers/agendar_event.dart';
import '../../providers/agendar_state.dart';

/// Lo que depende de los próximos turnos (las especialidades y los médicos):
/// mientras se piden, la rueda; si no se pudieron pedir, el error con
/// «Reintentar»; si llegaron, [child].
///
/// Sin red no se enseña ninguna lista vieja ni inventada.
class ConProximosTurnos extends StatelessWidget {
  final AgendarState state;
  final Widget child;

  const ConProximosTurnos({
    super.key,
    required this.state,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (state.cargandoProximos) {
      return const CargandoCentro(mensaje: 'Buscando turnos disponibles…');
    }

    final error = state.errorProximos;
    if (error != null) {
      return EstadoError(
        mensaje: error,
        alReintentar: () => context.read<AgendarBloc>().add(
          const AgendarProximosReintentados(),
        ),
      );
    }

    return child;
  }
}
