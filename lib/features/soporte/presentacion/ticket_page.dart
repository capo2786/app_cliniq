// lib/features/soporte/presentacion/ticket_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/archivos/archivos_service.dart';
import '../../../core/configuracion/config_publica_cubit.dart';
import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/redactor_de_mensaje.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../consultas/presentacion/widgets/adjuntos.dart';
import '../data/models/ticket.dart';
import '../data/soporte_service.dart';
import '../dominio/reglas_soporte.dart';
import '../providers/ticket_cubit.dart';
import 'widgets/adjunto_por_id.dart';
import 'widgets/burbuja_ticket.dart';
import 'widgets/encabezado_ticket.dart';

/// Un ticket de soporte: en qué va, la conversación con el equipo y
/// escribir (con un archivo, si hace falta).
///
/// Sin conexión enseña la última copia guardada. Un ticket cerrado ya no
/// admite mensajes: se dice y se invita a abrir uno nuevo.
class TicketPage extends StatelessWidget {
  final String id;

  /// El ticket de la lista (sin la conversación): se enseña mientras llega.
  final Ticket? inicial;

  /// Por defecto, `Servicios.soporte`.
  final SoporteService? servicio;

  /// Por defecto, `Servicios.archivos`.
  final ArchivosService? archivos;

  const TicketPage({
    super.key,
    required this.id,
    this.inicial,
    this.servicio,
    this.archivos,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TicketCubit(
        servicio: servicio ?? Servicios.soporte,
        uid: context.read<AuthBloc>().usuario?.uid ?? '',
        id: id,
        archivos: context.read<ConfigPublicaCubit>().config.archivos,
        inicial: inicial,
      )..cargar(),
      child: _VistaTicket(archivos: archivos),
    );
  }
}

class _VistaTicket extends StatefulWidget {
  final ArchivosService? archivos;

  const _VistaTicket({required this.archivos});

  @override
  State<_VistaTicket> createState() => _VistaTicketState();
}

class _VistaTicketState extends State<_VistaTicket>
    with WidgetsBindingObserver {
  final ScrollController _desplazamiento = ScrollController();
  final TextEditingController _mensaje = TextEditingController();

  TicketCubit get _cubit => context.read<TicketCubit>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _desplazamiento.dispose();
    _mensaje.dispose();
    super.dispose();
  }

  /// Al volver a la aplicación se pregunta si soporte respondió.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _cubit.cargar();
  }

  Future<void> _adjuntar() async {
    final cubit = _cubit;
    final seleccion = await elegirArchivos(context, varios: false);

    if (seleccion != null && !seleccion.vacia) cubit.elegirAdjunto(seleccion);
  }

  void _enviar() {
    cerrarTeclado();
    _cubit.enviar(_mensaje.text);
  }

  void _bajarAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_desplazamiento.hasClients) return;

      _desplazamiento.animateTo(
        _desplazamiento.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // El teclado se mide aquí, fuera del Scaffold: dentro del cuerpo ya
    // viene descontado.
    final tecladoAbierto = MediaQuery.viewInsetsOf(context).bottom > 0;

    return MultiBlocListener(
      listeners: [
        BlocListener<TicketCubit, TicketState>(
          listenWhen: (antes, ahora) =>
              ahora.aviso != null && antes.aviso != ahora.aviso,
          listener: (context, state) => mostrarAviso(
            context,
            state.aviso!.mensaje,
            error: !state.aviso!.exito,
          ),
        ),
        BlocListener<TicketCubit, TicketState>(
          listenWhen: (antes, ahora) => antes.enviados != ahora.enviados,
          listener: (context, state) {
            _mensaje.clear();
            _bajarAlFinal();
          },
        ),
        // Al llegar un mensaje nuevo (al refrescar), se baja.
        BlocListener<TicketCubit, TicketState>(
          listenWhen: (antes, ahora) =>
              (ahora.ticket?.mensajes?.length ?? 0) >
              (antes.ticket?.mensajes?.length ?? 0),
          listener: (context, state) => _bajarAlFinal(),
        ),
      ],
      child: BlocBuilder<TicketCubit, TicketState>(
        builder: (context, state) {
          final ticket = state.ticket;

          return Scaffold(
            backgroundColor: AppColors.fondo,
            appBar: AppBar(title: const Text('Ticket de soporte')),
            // El redactor va en el cuerpo y no como barra inferior: así sube
            // con el teclado en vez de quedar tapado por él.
            body: FondoDegradado(
              child: Column(
                children: [
                  Expanded(child: _cuerpo(context, state)),
                  if (ticket != null && state.puedeEscribir)
                    _Redactor(
                      state: state,
                      controlador: _mensaje,
                      tecladoAbierto: tecladoAbierto,
                      alAdjuntar: _adjuntar,
                      alEnviar: _enviar,
                    )
                  else if (ticket != null && ticket.mensajes != null)
                    const _TicketCerrado(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _cuerpo(BuildContext context, TicketState state) {
    final ticket = state.ticket;

    if (ticket == null) {
      return ListView(
        padding: context.margenDeScroll(),
        children: [
          if (state.carga == CargaTicket.error)
            EstadoError(
              mensaje: state.error ?? 'No pudimos abrir el ticket.',
              alReintentar: _cubit.cargar,
            )
          else
            const CargandoCentro(mensaje: 'Abriendo el ticket…'),
        ],
      );
    }

    final mensajes = ticket.mensajes;

    return RefreshIndicator(
      color: AppColors.acentoClaro,
      backgroundColor: AppColors.superficie,
      onRefresh: _cubit.refrescar,
      child: ListView(
        controller: _desplazamiento,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: context.margenDeScroll(superior: 16, inferior: 24),
        children: [
          const AvisoSinConexion(
            queSePuedeHacer:
                'Mostramos lo último que guardamos de este ticket. Para '
                'escribir a soporte necesitas conexión.',
          ),
          if (state.desdeCache && state.guardadoEn != null) ...[
            RecuadroAviso.informacion(
              'Mostramos la copia guardada el '
              '${FormatoFecha.cortaConHora(state.guardadoEn!)}.',
              icono: Icons.offline_pin_outlined,
            ),
            const SizedBox(height: 12),
          ],
          EncabezadoTicket(ticket: ticket),
          const SizedBox(height: 22),
          const EtiquetaSeccion('Conversación'),
          BurbujaTicket(
            key: const ValueKey('descripcion'),
            texto: ticket.descripcion,
            esSoporte: false,
            autor: 'Tú',
            fecha: ticket.creadoEn,
            esDescripcion: true,
          ),
          if (mensajes == null)
            const CargandoCentro(mensaje: 'Cargando la conversación…')
          else
            for (final mensaje in mensajes)
              BurbujaTicket.mensaje(
                mensaje,
                alVerAdjunto: () => abrirAdjuntoPorId(
                  context,
                  mensaje.adjuntoId!,
                  archivos: widget.archivos,
                ),
              ),
        ],
      ),
    );
  }
}

/// Escribir a soporte: el texto, un archivo opcional y enviar (también con
/// la tecla del teclado).
class _Redactor extends StatelessWidget {
  final TicketState state;
  final TextEditingController controlador;
  final bool tecladoAbierto;
  final VoidCallback alAdjuntar;
  final VoidCallback alEnviar;

  const _Redactor({
    required this.state,
    required this.controlador,
    required this.tecladoAbierto,
    required this.alAdjuntar,
    required this.alEnviar,
  });

  @override
  Widget build(BuildContext context) {
    final adjunto = state.adjunto;

    return RedactorDeMensaje(
      controlador: controlador,
      pista: 'Escribe tu mensaje',
      maximo: mensajeMaximo,
      tecladoAbierto: tecladoAbierto,
      enviando: state.enviando,
      progreso: state.progreso,
      error: state.errorEnvio,
      sinRed: 'Sin conexión: para escribir a soporte necesitas Internet.',
      accionDelTeclado: TextInputAction.send,
      alAdjuntar: alAdjuntar,
      alEnviar: alEnviar,
      adjunto: adjunto == null
          ? null
          : FilaAdjunto(
              nombre: adjunto.nombreParaSubir,
              tamano: adjunto.tamano,
              esImagen: adjunto.esImagen,
              nota: state.adjuntoSubido != null
                  ? 'Subido'
                  : 'Va con tu mensaje',
              alQuitar: state.enviando
                  ? null
                  : context.read<TicketCubit>().quitarAdjunto,
            ),
    );
  }
}

/// Al pie de un ticket cerrado, en lugar del redactor.
class _TicketCerrado extends StatelessWidget {
  const _TicketCerrado();

  @override
  Widget build(BuildContext context) {
    return BarraDeAccion(
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.textoSecundario,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Este ticket está cerrado. Si necesitas algo más, abre uno nuevo.',
              key: Key('ticket-cerrado'),
              style: TextStyle(
                color: AppColors.textoSuave,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
