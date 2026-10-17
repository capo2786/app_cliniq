// lib/features/clinicas/presentacion/cambiar_de_clinica.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/tema/tokens.dart';
import '../providers/clinica_cubit.dart';
import 'hoja_codigo_de_clinica.dart';
import 'logo_de_clinica_publica.dart';

/// «Cambiar de clínica», debajo de la marca en el acceso y en el registro.
///
/// La marca de arriba ya es la de la clínica guardada (su configuración
/// pública sale con su `X-Empresa`); esto es para quien es de otra. Sin
/// clínica guardada se ofrece escribir el código que dio la clínica. Sin
/// [ClinicaCubit] (una pantalla suelta en una prueba) no se ve.
class BotonCambiarDeClinica extends StatelessWidget {
  /// Se llama cuando la clínica cambió, por si la pantalla tiene que volver
  /// a pedir algo suyo (el registro, sus documentos legales).
  final VoidCallback? alCambiar;

  final bool habilitado;

  const BotonCambiarDeClinica({
    super.key,
    this.alCambiar,
    this.habilitado = true,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = clinicaCubitSiHay(context);
    if (cubit == null) return const SizedBox.shrink();

    return BlocBuilder<ClinicaCubit, ClinicaState>(
      bloc: cubit,
      builder: (context, state) {
        final hayClinica = state.clinica != null;

        return TextButton.icon(
          key: const Key('boton-cambiar-clinica'),
          onPressed: habilitado
              ? () async {
                  final cambio = await cambiarDeClinica(context, cubit);
                  if (cambio) alCambiar?.call();
                }
              : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.acentoSuave,
            minimumSize: const Size(0, 40),
          ),
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: Text(
            hayClinica ? 'Cambiar de clínica' : '¿Tu clínica te dio un código?',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }
}
