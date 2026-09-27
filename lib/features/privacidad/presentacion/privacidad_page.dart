// lib/features/privacidad/presentacion/privacidad_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/configuracion/en_contexto.dart';
import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/providers/auth_bloc.dart';
import '../data/arco_service.dart';
import '../dominio/reglas_arco.dart';
import '../providers/arco_cubit.dart';
import 'nueva_solicitud_arco_page.dart';
import 'widgets/tarjeta_solicitud_arco.dart';

/// Mis derechos sobre mis datos (ARCO, LOPDP): las solicitudes hechas, con su
/// estado, su plazo y la respuesta de la clínica, y el camino a una nueva.
///
/// No es un elemento del menú: está siempre en el perfil, porque es un
/// derecho legal (`/portal/arco` y `/privacidad/solicitudes` en el
/// enrutador, para los avisos).
class PrivacidadPage extends StatelessWidget {
  final ArcoService? servicio;

  const PrivacidadPage({super.key, this.servicio});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ArcoCubit(
        servicio ?? Servicios.arco,
        uid: context.read<AuthBloc>().usuario?.uid ?? '',
      )..cargar(),
      child: const _VistaPrivacidad(),
    );
  }
}

class _VistaPrivacidad extends StatelessWidget {
  const _VistaPrivacidad();

  void _nueva(BuildContext context) {
    final cubit = context.read<ArcoCubit>();

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const NuevaSolicitudArcoPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ArcoCubit>();

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(title: const Text('Mis derechos sobre mis datos')),
      body: FondoDegradado(
        child: RefreshIndicator(
          color: AppColors.acentoClaro,
          backgroundColor: AppColors.superficie,
          onRefresh: cubit.cargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: context.margenDeScroll(),
            children: [
              const AvisoSinConexion(
                queSePuedeHacer:
                    'Ves tus solicitudes guardadas en este teléfono. Para '
                    'enviar una nueva necesitas conexión.',
              ),
              const _Encabezado(),
              const SizedBox(height: 16),
              ConRed(
                builder: (context, hayRed) => BotonPrincipal(
                  key: const Key('nueva-solicitud-arco'),
                  texto: 'Nueva solicitud',
                  icono: Icons.add_rounded,
                  onPressed: hayRed ? () => _nueva(context) : null,
                ),
              ),
              const SizedBox(height: 26),
              const EtiquetaSeccion('Mis solicitudes'),
              const _Solicitudes(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Qué es esto y cuánto tiene la clínica para responder
/// (`general.arcoPlazoDias`).
class _Encabezado extends StatelessWidget {
  const _Encabezado();

  @override
  Widget build(BuildContext context) {
    final config = context.config;

    return TarjetaEncabezado(
      icono: Icons.shield_outlined,
      titulo: 'Tus datos, tus derechos',
      descripcion:
          'La Ley Orgánica de Protección de Datos Personales te da derecho a '
          'saber qué datos tuyos tiene ${config.clinica.nombre} y a decidir '
          'sobre ellos. La clínica tiene '
          '${dias(config.general.arcoPlazoDias)} para responderte: verás la '
          'fecha límite en cada solicitud.',
    );
  }
}

class _Solicitudes extends StatelessWidget {
  const _Solicitudes();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ArcoCubit, ArcoState>(
      builder: (context, state) {
        final error = state.error;

        if (state.cargando && state.solicitudes.isEmpty) {
          return const CargandoCentro(mensaje: 'Buscando tus solicitudes…');
        }

        if (error != null) {
          return EstadoError(
            mensaje: error,
            alReintentar: context.read<ArcoCubit>().cargar,
          );
        }

        if (state.solicitudes.isEmpty) {
          return const EstadoVacio(
            key: Key('sin-solicitudes-arco'),
            icono: Icons.shield_outlined,
            titulo: 'Aún no has hecho solicitudes',
            descripcion:
                'Cuando envíes una, aquí verás su estado, la fecha límite de '
                'respuesta y lo que te contestemos.',
          );
        }

        return Column(
          children: [
            for (final solicitud in ordenarSolicitudes(state.solicitudes)) ...[
              TarjetaSolicitudArco(solicitud: solicitud),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}
