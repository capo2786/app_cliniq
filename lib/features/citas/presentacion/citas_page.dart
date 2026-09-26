// lib/features/citas/presentacion/citas_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/cerrar_sesion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/data/models/usuario.dart';
import '../../auth/providers/auth_bloc.dart';
import '../data/models/cita.dart';
import '../dominio/reglas_citas.dart';
import '../providers/citas_bloc.dart';
import '../providers/citas_event.dart';
import '../providers/citas_state.dart';
import 'widgets/detalle_cita.dart';
import 'widgets/tarjeta_cita.dart';

/// Las citas del paciente y de sus dependientes: próximas e historial.
class CitasPage extends StatelessWidget {
  /// Abre el agendamiento (lo pone el tablero, que es quien navega).
  final VoidCallback? alAgendar;

  const CitasPage({super.key, this.alAgendar});

  Future<void> _refrescar(BuildContext context) async {
    final usuario = context.read<AuthBloc>().usuario;
    if (usuario == null) return;

    final bloc = context.read<CitasBloc>()..add(CitasSolicitadas(usuario.uid));

    await bloc.stream
        .firstWhere((s) => !s.cargando)
        .timeout(const Duration(seconds: 15), onTimeout: () => bloc.state);
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthBloc>().usuario;
    final puedeVer = usuario?.puede(Permisos.misCitas) ?? false;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        appBar: AppBar(
          title: const Text('Mis citas'),
          actions: const [BotonCerrarSesion(), SizedBox(width: 6)],
        ),
        body: FondoDegradado(
          child: !puedeVer
              ? ListView(
                  padding: context.margenDeScroll(),
                  children: const [
                    EstadoVacio(
                      icono: Icons.lock_outline_rounded,
                      titulo: 'Tu cuenta no tiene acceso a citas',
                      descripcion:
                          'Esta sección es para pacientes. Si crees '
                          'que es un error, consúltalo en la clínica.',
                    ),
                  ],
                )
              : BlocListener<CitasBloc, CitasState>(
                  listenWhen: (antes, ahora) =>
                      ahora.accion != null && antes.accion != ahora.accion,
                  listener: (context, state) => mostrarAviso(
                    context,
                    state.accion!.mensaje,
                    error: !state.accion!.exito,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          children: [
                            const AvisoSinConexion(),
                            BlocBuilder<CitasBloc, CitasState>(
                              builder: (context, state) {
                                final proximas = proximasCitas(
                                  state.citas,
                                  Servicios.reloj.ahora(),
                                ).length;

                                return TarjetaEncabezado(
                                  icono: Icons.event_note_rounded,
                                  titulo: 'Tus citas',
                                  descripcion: proximas == 0
                                      ? 'No tienes citas próximas.'
                                      : proximas == 1
                                      ? 'Tienes 1 cita próxima.'
                                      : 'Tienes $proximas citas próximas.',
                                );
                              },
                            ),
                            const SizedBox(height: 14),
                            const _Pestanas(),
                          ],
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _ListaDeCitas(
                              proximas: true,
                              alRefrescar: () => _refrescar(context),
                              alAgendar: alAgendar,
                            ),
                            _ListaDeCitas(
                              proximas: false,
                              alRefrescar: () => _refrescar(context),
                              alAgendar: alAgendar,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

/// Próximas / Historial, como un control segmentado.
class _Pestanas extends StatelessWidget {
  const _Pestanas();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.campo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bordeCampo),
      ),
      child: TabBar(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          gradient: AppGradientes.accion,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textoSecundario,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
        tabs: const [
          Tab(text: 'Próximas'),
          Tab(text: 'Historial'),
        ],
      ),
    );
  }
}

class _ListaDeCitas extends StatelessWidget {
  final bool proximas;
  final Future<void> Function() alRefrescar;
  final VoidCallback? alAgendar;

  const _ListaDeCitas({
    required this.proximas,
    required this.alRefrescar,
    this.alAgendar,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CitasBloc, CitasState>(
      builder: (context, state) {
        final ahora = Servicios.reloj.ahora();
        final citas = proximas
            ? proximasCitas(state.citas, ahora)
            : historialDeCitas(state.citas, ahora);

        return RefreshIndicator(
          color: AppColors.acentoClaro,
          backgroundColor: AppColors.superficie,
          onRefresh: alRefrescar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: context.margenDeScroll(superior: 16),
            children: [
              if (state.desdeCache && state.guardadasEn != null) ...[
                RecuadroAviso.informacion(
                  'Mostramos tus citas guardadas el '
                  '${FormatoFecha.cortaConHora(state.guardadasEn!)}.',
                  icono: Icons.offline_pin_outlined,
                ),
                const SizedBox(height: 12),
              ],
              if (state.error != null && state.citas.isNotEmpty) ...[
                RecuadroAviso.alerta(state.error!),
                const SizedBox(height: 12),
              ],
              if (state.carga == CargaCitas.cargando && state.citas.isEmpty)
                const CargandoCentro(mensaje: 'Trayendo tus citas…')
              else if (state.carga == CargaCitas.error && state.citas.isEmpty)
                EstadoError(
                  mensaje: state.error ?? 'No pudimos traer tus citas.',
                  alReintentar: alRefrescar,
                )
              else if (citas.isEmpty)
                proximas
                    ? EstadoVacio(
                        icono: Icons.event_available_rounded,
                        titulo: 'No tienes citas próximas',
                        descripcion:
                            'Cuando agendes una cita aparecerá aquí, '
                            'con lo que necesitas para prepararte.',
                        accion: alAgendar == null ? null : 'Agendar una cita',
                        alPulsar: alAgendar,
                      )
                    : const EstadoVacio(
                        icono: Icons.history_rounded,
                        titulo: 'Todavía no hay historial',
                        descripcion:
                            'Las citas atendidas, canceladas o '
                            'pasadas se guardan aquí.',
                      )
              else
                for (final cita in citas) ...[
                  _EnLista(cita: cita),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _EnLista extends StatelessWidget {
  final Cita cita;

  const _EnLista({required this.cita});

  @override
  Widget build(BuildContext context) {
    return TarjetaCita(
      cita: cita,
      onTap: () => mostrarDetalleCita(context, cita),
    );
  }
}
