// lib/features/clinicas/presentacion/aviso_de_clinica_no_disponible.dart

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/presentacion/avisos.dart';
import '../providers/clinica_cubit.dart';
import 'logo_de_clinica_publica.dart';

/// Avisa, una vez, que la clínica guardada ya no está disponible y que la
/// aplicación sigue con la predeterminada (ver
/// `ClinicaCubit.alNoEstarDisponible`): «La clínica «demo» no está
/// disponible por ahora. Consulta con tu clínica.»
///
/// Va debajo de `MaterialApp`, que es quien tiene el `ScaffoldMessenger`.
/// Sin [ClinicaCubit] (una pantalla suelta en una prueba) no hace nada.
class AvisoDeClinicaNoDisponible extends StatelessWidget {
  final Widget child;

  const AvisoDeClinicaNoDisponible({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (clinicaCubitSiHay(context) == null) return child;

    return BlocListener<ClinicaCubit, ClinicaState>(
      listenWhen: (antes, ahora) =>
          ahora.noDisponible != null &&
          ahora.noDisponible != antes.noDisponible,
      listener: (context, state) => mostrarAviso(
        context,
        mensajeDeClinicaNoDisponible(state.noDisponible!),
        error: true,
      ),
      child: child,
    );
  }
}
