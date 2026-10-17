// lib/features/clinicas/presentacion/sincronizar_clinica.dart

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/catalogos/catalogos_cubit.dart';
import '../../../core/configuracion/config_publica_cubit.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../auth/providers/auth_state.dart';
import '../dominio/clinica.dart';
import '../providers/clinica_cubit.dart';

/// Mantiene la clínica de la aplicación de acuerdo con lo demás.
///
/// - **Al entrar**, la clínica de la cuenta queda guardada (la del perfil,
///   `empresaSesion`, o la que dice el token).
/// - **Al cambiar de clínica**, se vuelven a pedir la configuración pública
///   y los catálogos: ahora salen con la otra `X-Empresa`, y con ellos la
///   marca, el logotipo y los colores de la nueva. También cuando la
///   guardada se olvida porque ya no está disponible: entonces salen de la
///   predeterminada.
/// - **Con cada configuración**, el nombre, el logotipo y los colores se
///   copian en la clínica guardada.
class SincronizarClinica extends StatelessWidget {
  /// El token vigente, para leer de él la clínica si el perfil no la trae.
  final String? Function() leerToken;

  final Widget child;

  const SincronizarClinica({
    super.key,
    required this.leerToken,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listenWhen: (antes, ahora) =>
              ahora is AuthAutenticado &&
              (antes is! AuthAutenticado || antes.usuario != ahora.usuario),
          listener: (context, state) {
            final usuario = (state as AuthAutenticado).usuario;
            unawaited(
              context.read<ClinicaCubit>().alEntrar(
                usuario.clinicaDeLaSesion ?? clinicaDelToken(leerToken()),
              ),
            );
          },
        ),
        BlocListener<ClinicaCubit, ClinicaState>(
          listenWhen: (antes, ahora) => antes.cambios != ahora.cambios,
          listener: (context, _) {
            unawaited(context.read<ConfigPublicaCubit>().recargar());
            unawaited(context.read<CatalogosCubit>().recargar());
          },
        ),
        BlocListener<ConfigPublicaCubit, ConfigPublicaState>(
          listenWhen: (antes, ahora) =>
              ahora.config != null &&
              antes.config?.clinica != ahora.config?.clinica,
          listener: (context, state) {
            final clinica = state.config!.clinica;
            final logo = clinica.logo ?? '';

            unawaited(
              context.read<ClinicaCubit>().actualizarMarca(
                nombre: clinica.nombre,
                // Un data URL (de un servidor anterior) no se copia: es la
                // imagen entera, y ya va en la configuración guardada.
                logoUrl: logo.startsWith('http') ? logo : null,
                colorPrimario: clinica.colorPrimario,
                colorAcento: clinica.colorAcento,
              ),
            );
          },
        ),
      ],
      child: child,
    );
  }
}
