// lib/features/soporte/presentacion/soporte_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/archivos/archivos_service.dart';
import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/cerrar_sesion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/providers/auth_bloc.dart';
import '../data/models/ticket.dart';
import '../data/soporte_service.dart';
import '../providers/soporte_cubit.dart';
import 'nuevo_ticket_page.dart';
import 'ticket_page.dart';
import 'widgets/tarjeta_ticket.dart';

/// Soporte: mis tickets, abrir uno nuevo y conversar con el equipo.
///
/// Con [nuevoTicket] abre directamente el formulario del ticket nuevo (así
/// llega desde un artículo de ayuda: «¿No resolviste tu duda?»). Sin
/// conexión enseña los tickets guardados; sin copia, lo dice con
/// «Reintentar».
class SoportePage extends StatelessWidget {
  /// Abrir el formulario de un ticket nuevo al entrar.
  final bool nuevoTicket;

  /// Por defecto, `Servicios.soporte`.
  final SoporteService? servicio;

  /// Por defecto, `Servicios.archivos`.
  final ArchivosService? archivos;

  const SoportePage({
    super.key,
    this.nuevoTicket = false,
    this.servicio,
    this.archivos,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SoporteCubit(
        servicio: servicio ?? Servicios.soporte,
        uid: context.read<AuthBloc>().usuario?.uid ?? '',
      )..cargar(),
      child: _VistaSoporte(nuevoTicket: nuevoTicket, archivos: archivos),
    );
  }
}

class _VistaSoporte extends StatefulWidget {
  final bool nuevoTicket;
  final ArchivosService? archivos;

  const _VistaSoporte({required this.nuevoTicket, required this.archivos});

  @override
  State<_VistaSoporte> createState() => _VistaSoporteState();
}

class _VistaSoporteState extends State<_VistaSoporte> {
  SoporteCubit get _cubit => context.read<SoporteCubit>();

  @override
  void initState() {
    super.initState();

    if (widget.nuevoTicket) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nuevo();
      });
    }
  }

  Future<void> _nuevo() async {
    final cubit = _cubit;

    final creado = await Navigator.of(context).push<Ticket>(
      MaterialPageRoute(
        builder: (_) => NuevoTicketPage(servicio: cubit.servicio),
      ),
    );

    if (creado == null || !mounted) return;

    cubit.recordar(creado);
    await _abrir(creado);
  }

  Future<void> _abrir(Ticket ticket) async {
    final cubit = _cubit;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TicketPage(
          id: ticket.id,
          inicial: ticket,
          servicio: cubit.servicio,
          archivos: widget.archivos,
        ),
      ),
    );

    // Al volver, la lista al día: pudo llegar una respuesta o escribirse.
    if (mounted) await cubit.cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Soporte'),
        actions: const [BotonCerrarSesion(), SizedBox(width: 6)],
      ),
      body: FondoDegradado(
        child: BlocBuilder<SoporteCubit, SoporteState>(
          builder: (context, state) => RefreshIndicator(
            color: AppColors.acentoClaro,
            backgroundColor: AppColors.superficie,
            onRefresh: _cubit.cargar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: context.margenDeScroll(inferior: 28),
              children: [
                const AvisoSinConexion(
                  queSePuedeHacer:
                      'Mostramos tus tickets guardados. Para escribir a '
                      'soporte necesitas conexión.',
                ),
                const TarjetaEncabezado(
                  icono: Icons.support_agent_rounded,
                  titulo: 'Soporte',
                  descripcion:
                      '¿Algo no funciona o tienes una duda? Escríbenos y te '
                      'responde una persona del equipo.',
                ),
                const SizedBox(height: 16),
                ConRed(
                  builder: (context, hayRed) => BotonPrincipal(
                    key: const Key('boton-nuevo-ticket'),
                    texto: 'Nuevo ticket',
                    icono: Icons.add_comment_outlined,
                    onPressed: hayRed ? _nuevo : null,
                  ),
                ),
                const SizedBox(height: 20),
                ..._lista(state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _lista(SoporteState state) {
    if (state.tickets.isEmpty) {
      return [
        switch (state.carga) {
          CargaTickets.error => EstadoError(
            mensaje: state.error ?? 'No pudimos cargar tus tickets.',
            alReintentar: _cubit.cargar,
          ),
          CargaTickets.lista => EstadoVacio(
            icono: Icons.support_agent_rounded,
            titulo: 'Aún no tienes tickets',
            descripcion:
                'Cuando nos escribas, aquí verás la conversación con soporte '
                'y el estado de tu caso.',
            accion: 'Escribir a soporte',
            alPulsar: _nuevo,
          ),
          _ => const CargandoCentro(mensaje: 'Cargando tus tickets…'),
        },
      ];
    }

    return [
      if (state.desdeCache && state.guardadosEn != null) ...[
        RecuadroAviso.informacion(
          'Mostramos tus tickets guardados el '
          '${FormatoFecha.cortaConHora(state.guardadosEn!)}.',
          icono: Icons.offline_pin_outlined,
        ),
        const SizedBox(height: 12),
      ],
      if (state.error != null) ...[
        RecuadroAviso.alerta(state.error!),
        const SizedBox(height: 12),
      ],
      const EtiquetaSeccion('Mis tickets'),
      for (final ticket in state.tickets) ...[
        TarjetaTicket(
          key: Key('ticket-${ticket.id}'),
          ticket: ticket,
          onTap: () => _abrir(ticket),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}
