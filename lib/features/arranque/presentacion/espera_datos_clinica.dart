// lib/features/arranque/presentacion/espera_datos_clinica.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/catalogos/catalogos_cubit.dart';
import '../../../core/configuracion/config_publica_cubit.dart';
import '../../../core/presentacion/widgets/entrada_animada.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/logo_clinica.dart';
import '../../../core/tema/tokens.dart';
import 'arranque_page.dart';

/// No deja pasar a ninguna pantalla sin la configuración y los catálogos de
/// la clínica.
///
/// Con una copia guardada pasa enseguida (y los datos se refrescan por
/// detrás). La primera vez espera la respuesta del servidor; si no llega y
/// no hay copia, lo dice y ofrece «Reintentar». La aplicación no trae
/// valores de respaldo: sin datos de la clínica no sabe ni cómo se llama.
class EsperaDatosDeLaClinica extends StatelessWidget {
  final Widget child;

  const EsperaDatosDeLaClinica({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigPublicaCubit>().state;
    final catalogos = context.watch<CatalogosCubit>().state;

    if (config.lista && catalogos.completos) return child;

    final error = config.error ?? catalogos.error;
    final cargando = config.cargando || catalogos.cargando;

    if (error != null && !cargando) {
      return PantallaSinDatosDeLaClinica(
        mensaje: error,
        alReintentar: () {
          context.read<ConfigPublicaCubit>().cargar();
          context.read<CatalogosCubit>().cargar();
        },
      );
    }

    return const ArranquePage();
  }
}

/// «No pudimos cargar los datos de la clínica», con «Reintentar».
class PantallaSinDatosDeLaClinica extends StatelessWidget {
  final String mensaje;
  final VoidCallback alReintentar;

  const PantallaSinDatosDeLaClinica({
    super.key,
    required this.mensaje,
    required this.alReintentar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('sin-datos-de-la-clinica'),
      backgroundColor: AppColors.fondoProfundo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: EntradaAnimada(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LogoDeLaClinica(tamano: 88, insignia: true),
                  const SizedBox(height: 24),
                  EstadoError(mensaje: mensaje, alReintentar: alReintentar),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
