// lib/features/consultas/presentacion/detalle_consulta_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/configuracion/config_publica_cubit.dart';
import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/rutas.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/redactor_de_mensaje.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/providers/auth_bloc.dart';
import '../data/models/campo_formulario.dart';
import '../data/models/consulta.dart';
import '../dominio/reglas_consultas.dart';
import '../providers/consultas_bloc.dart';
import '../providers/consultas_event.dart';
import '../providers/detalle_consulta_bloc.dart';
import '../providers/detalle_consulta_event.dart';
import '../providers/detalle_consulta_state.dart';
import 'estilos_consulta.dart';
import 'widgets/adjuntos.dart';
import 'widgets/burbuja_mensaje.dart';
import 'widgets/cancelar_consulta.dart';

/// Una consulta en línea: en qué va, hasta cuándo responde el médico, lo que
/// se le contó, los archivos y la conversación.
///
/// Mientras se ve, pregunta cada 30 segundos si hay novedades; se apaga al
/// quedar tapada por otra pantalla o con la aplicación en segundo plano, y
/// al volver pregunta enseguida.
class DetalleConsultaPage extends StatelessWidget {
  final String consultaId;

  const DetalleConsultaPage({super.key, required this.consultaId});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthBloc>().usuario?.uid ?? '';

    return BlocProvider(
      create: (_) => DetalleConsultaBloc(
        servicio: Servicios.consultas,
        uid: uid,
        id: consultaId,
        archivos: context.read<ConfigPublicaCubit>().config.archivos,
      ),
      child: const _VistaDetalle(),
    );
  }
}

class _VistaDetalle extends StatefulWidget {
  const _VistaDetalle();

  @override
  State<_VistaDetalle> createState() => _VistaDetalleState();
}

class _VistaDetalleState extends State<_VistaDetalle>
    with WidgetsBindingObserver, RouteAware {
  final ScrollController _desplazamiento = ScrollController();
  final TextEditingController _mensaje = TextEditingController();

  ModalRoute<void>? _ruta;

  DetalleConsultaBloc get _bloc => context.read<DetalleConsultaBloc>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _bloc
      ..add(const DetalleConsultaSolicitado())
      ..add(const DetalleConsultaSondeoCambiado(true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final ruta = ModalRoute.of(context);
    if (ruta != _ruta) {
      if (_ruta != null) observadorDeRutas.unsubscribe(this);
      _ruta = ruta;
      if (ruta != null) observadorDeRutas.subscribe(this, ruta);
    }
  }

  @override
  void dispose() {
    observadorDeRutas.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _desplazamiento.dispose();
    _mensaje.dispose();
    super.dispose();
  }

  // ── Visible o no ───────────────────────────────────────────────────

  void _volverAVer() {
    _bloc
      ..add(const DetalleConsultaSondeoCambiado(true))
      ..add(const DetalleConsultaRefrescado(silencioso: true));
  }

  void _dejarDeVer() => _bloc.add(const DetalleConsultaSondeoCambiado(false));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_ruta?.isCurrent ?? true) _volverAVer();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _dejarDeVer();
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void didPushNext() => _dejarDeVer();

  @override
  void didPopNext() => _volverAVer();

  // ── Acciones ───────────────────────────────────────────────────────

  Future<void> _refrescar() async {
    _bloc.add(const DetalleConsultaRefrescado());

    await _bloc.stream
        .firstWhere((s) => !s.refrescando && s.carga != CargaDetalle.cargando)
        .timeout(const Duration(seconds: 15), onTimeout: () => _bloc.state);
  }

  Future<void> _adjuntar() async {
    final bloc = _bloc;
    final seleccion = await elegirArchivos(context, varios: false);

    if (seleccion != null && !seleccion.vacia) {
      bloc.add(DetalleConsultaAdjuntoElegido(seleccion));
    }
  }

  void _enviar() {
    FocusManager.instance.primaryFocus?.unfocus();
    _bloc.add(DetalleConsultaMensajeEnviado(_mensaje.text));
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
    return MultiBlocListener(
      listeners: [
        // La lista de consultas se entera de cada novedad.
        BlocListener<DetalleConsultaBloc, DetalleConsultaState>(
          listenWhen: (antes, ahora) =>
              ahora.detalle != null && antes.detalle != ahora.detalle,
          listener: (context, state) => context.read<ConsultasBloc>().add(
            ConsultaActualizada(state.detalle!.resumen),
          ),
        ),
        BlocListener<DetalleConsultaBloc, DetalleConsultaState>(
          listenWhen: (antes, ahora) =>
              ahora.aviso != null && antes.aviso != ahora.aviso,
          listener: (context, state) => mostrarAviso(
            context,
            state.aviso!.mensaje,
            error: !state.aviso!.exito,
          ),
        ),
        BlocListener<DetalleConsultaBloc, DetalleConsultaState>(
          listenWhen: (antes, ahora) => antes.enviados != ahora.enviados,
          listener: (context, state) {
            _mensaje.clear();
            _bajarAlFinal();
          },
        ),
        // Al llegar un mensaje nuevo (del médico, por el sondeo), se baja.
        BlocListener<DetalleConsultaBloc, DetalleConsultaState>(
          listenWhen: (antes, ahora) =>
              antes.detalle != null &&
              (ahora.detalle?.mensajes.length ?? 0) >
                  antes.detalle!.mensajes.length,
          listener: (context, state) => _bajarAlFinal(),
        ),
      ],
      child: BlocBuilder<DetalleConsultaBloc, DetalleConsultaState>(
        builder: (context, state) {
          final detalle = state.detalle;

          // El teclado se mide aquí, fuera del Scaffold: dentro del cuerpo
          // ya viene descontado.
          final tecladoAbierto = MediaQuery.viewInsetsOf(context).bottom > 0;

          return Scaffold(
            backgroundColor: AppColors.fondo,
            appBar: AppBar(
              title: Text(
                detalle == null || detalle.codigo.isEmpty
                    ? 'Consulta en línea'
                    : detalle.codigo,
              ),
            ),
            // El redactor va dentro del cuerpo y no como barra inferior: así
            // sube con el teclado en vez de quedar tapado por él.
            body: FondoDegradado(
              child: Column(
                children: [
                  Expanded(child: _cuerpo(context, state)),
                  if (detalle != null && detalle.puedeEscribir)
                    _Redactor(
                      state: state,
                      controlador: _mensaje,
                      tecladoAbierto: tecladoAbierto,
                      alAdjuntar: _adjuntar,
                      alEnviar: _enviar,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _cuerpo(BuildContext context, DetalleConsultaState state) {
    final detalle = state.detalle;

    if (detalle == null) {
      return ListView(
        padding: context.margenDeScroll(),
        children: [
          if (state.carga == CargaDetalle.error)
            EstadoError(
              mensaje: state.error ?? 'No pudimos abrir la consulta.',
              alReintentar: () => _bloc.add(const DetalleConsultaSolicitado()),
            )
          else
            const CargandoCentro(mensaje: 'Abriendo la consulta…'),
        ],
      );
    }

    final ahora = Servicios.reloj.instante();

    return RefreshIndicator(
      color: AppColors.acentoClaro,
      backgroundColor: AppColors.superficie,
      onRefresh: _refrescar,
      child: ListView(
        controller: _desplazamiento,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: context.margenDeScroll(superior: 16, inferior: 24),
        children: [
          const AvisoSinConexion(
            queSePuedeHacer:
                'Mostramos lo último que guardamos de esta consulta. Para '
                'escribir o cancelar necesitas conexión.',
          ),
          if (state.desdeCache && state.guardadaEn != null) ...[
            RecuadroAviso.informacion(
              'Mostramos la copia guardada el '
              '${FormatoFecha.cortaConHora(state.guardadaEn!)}.',
              icono: Icons.offline_pin_outlined,
            ),
            const SizedBox(height: 12),
          ],
          if (state.error != null) ...[
            RecuadroAviso.alerta(state.error!),
            const SizedBox(height: 12),
          ],
          _Encabezado(detalle: detalle, ahora: ahora),
          const SizedBox(height: 12),
          _EstadoYPlazo(detalle: detalle, ahora: ahora),
          const SizedBox(height: 22),
          const EtiquetaSeccion('Tu consulta'),
          _LoQueSeConto(detalle: detalle),
          if (detalle.adjuntos.isNotEmpty) ...[
            const SizedBox(height: 22),
            EtiquetaSeccion(
              detalle.adjuntos.length == 1
                  ? '1 archivo'
                  : '${detalle.adjuntos.length} archivos',
            ),
            for (final archivo in detalle.adjuntos) ...[
              FilaAdjunto(
                nombre: archivo.nombre,
                tamano: archivo.tamano,
                esImagen: archivo.esImagen,
                onTap: () => abrirArchivo(context, archivo),
              ),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 22),
          const EtiquetaSeccion('Conversación'),
          if (detalle.mensajes.isEmpty)
            Text(
              detalle.estado.esperandoRespuesta
                  ? 'Todavía no hay mensajes. Cuando el médico responda, lo '
                        'verás aquí y te avisaremos por correo.'
                  : 'No hay mensajes en esta consulta.',
              style: const TextStyle(
                color: AppColors.textoSecundario,
                fontSize: 12.5,
                height: 1.4,
              ),
            )
          else
            for (final mensaje in detalle.mensajes)
              BurbujaMensaje(mensaje: mensaje),
          if (state.puedeCancelar) ...[
            const SizedBox(height: 22),
            ConRed(
              builder: (context, hayRed) => BotonSecundario(
                key: const Key('boton-cancelar-consulta'),
                texto: 'Cancelar la consulta',
                icono: Icons.cancel_outlined,
                color: AppColors.peligroSuave,
                onPressed: hayRed && !state.cancelando
                    ? () => mostrarCancelarConsulta(context)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Puedes cancelarla mientras el médico todavía no la abre.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textoTenue, fontSize: 11.5),
            ),
          ],
        ],
      ),
    );
  }
}

/// Qué es, con quién y para quién, con su estado y su plazo.
class _Encabezado extends StatelessWidget {
  final ConsultaDetalle detalle;
  final DateTime ahora;

  const _Encabezado({required this.detalle, required this.ahora});

  @override
  Widget build(BuildContext context) {
    final plazo = tiempoRestante(detalle, ahora);
    final estado = context.estadoConsulta(detalle.estado);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppEspaciado.xl),
      decoration: BoxDecoration(
        gradient: AppGradientes.encabezado,
        borderRadius: AppRadio.dePanel,
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: AppColors.sombraSuave,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detalle.motivoNombre.isEmpty
                ? 'Consulta en línea'
                : detalle.motivoNombre,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              ?detalle.medicoVisible,
              if (detalle.especialidad.isNotEmpty) detalle.especialidad,
            ].join(' · '),
            style: const TextStyle(
              color: AppColors.textoSuave,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (detalle.pacienteNombre.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              detalle.paraDependiente
                  ? 'Para ${detalle.pacienteNombre} (dependiente)'
                  : 'Para ${detalle.pacienteNombre}',
              style: const TextStyle(
                color: AppColors.textoSuave,
                fontSize: 12.5,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Pastilla(
                texto: estado.nombre,
                color: estado.color,
                icono: estado.icono,
              ),
              if (plazo != null)
                Pastilla(
                  texto: plazo,
                  color: colorDelPlazo(plazo),
                  icono: Icons.hourglass_bottom_rounded,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// En qué va y qué esperar, en una frase.
class _EstadoYPlazo extends StatelessWidget {
  final ConsultaDetalle detalle;
  final DateTime ahora;

  const _EstadoYPlazo({required this.detalle, required this.ahora});

  @override
  Widget build(BuildContext context) {
    final vence = detalle.venceEn;
    final seguimiento = detalle.seguimientoHasta;
    final explicacion = context.estadoConsulta(detalle.estado).descripcion;

    switch (detalle.estado) {
      case EstadoConsulta.enviada:
      case EstadoConsulta.enRevision:
        if (estaDemorada(detalle, ahora)) {
          return const RecuadroAviso.alerta(
            'Tu consulta está demorada. La clínica ya fue avisada y el médico '
            'te responderá lo antes posible. Si empeoras, no esperes: ve a '
            'la emergencia más cercana.',
            icono: Icons.running_with_errors_rounded,
          );
        }
        final plazo = vence == null
            ? null
            : 'El médico tiene hasta el '
                  '${momentoLegible(vence).toLowerCase()} para responderte.';
        final texto = [
          if (explicacion.isNotEmpty) explicacion,
          ?plazo,
        ].join(' ');
        if (texto.isEmpty) return const SizedBox.shrink();

        return RecuadroAviso.informacion(texto, icono: Icons.schedule_rounded);

      case EstadoConsulta.respondida:
        return RecuadroAviso(
          mensaje: seguimiento == null
              ? 'El médico respondió.'
              : 'El médico respondió. Puedes escribirle hasta el '
                    '${momentoLegible(seguimiento).toLowerCase()}; después la '
                    'consulta se cierra sola.',
          icono: Icons.mark_chat_read_outlined,
          color: AppColors.exito,
          colorTexto: AppColors.texto,
        );

      case EstadoConsulta.cerrada:
        final cerrada = detalle.cerradaEn;
        return RecuadroAviso.informacion(
          cerrada == null
              ? 'Consulta cerrada. Si necesitas algo más, empieza una consulta '
                    'nueva.'
              : 'Consulta cerrada el ${momentoLegible(cerrada).toLowerCase()}. '
                    'Si necesitas algo más, empieza una consulta nueva.',
          icono: Icons.lock_outline_rounded,
        );

      case EstadoConsulta.cancelada:
        final motivo = detalle.motivoCancelacion;
        return RecuadroAviso.informacion(
          motivo == null
              ? 'Cancelaste esta consulta.'
              : 'Cancelaste esta consulta. Motivo: $motivo',
          icono: Icons.cancel_outlined,
        );

      case EstadoConsulta.borrador:
        return explicacion.isEmpty
            ? const SizedBox.shrink()
            : RecuadroAviso.alerta(explicacion);
    }
  }
}

/// La descripción y las respuestas al formulario.
class _LoQueSeConto extends StatelessWidget {
  final ConsultaDetalle detalle;

  const _LoQueSeConto({required this.detalle});

  @override
  Widget build(BuildContext context) {
    final campos = {
      for (final CampoFormulario c in detalle.campos ?? const []) c.clave: c,
    };

    return TarjetaTranslucida(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in detalle.respuestas)
            FilaDato(
              icono: Icons.check_circle_outline_rounded,
              rotulo: r.etiqueta,
              valor: valorLegible(
                r.tipo,
                r.valor,
                unidad: campos[r.clave]?.unidad,
              ),
            ),
          FilaDato(
            icono: Icons.notes_rounded,
            rotulo: 'Lo que le contaste',
            valor: detalle.descripcion,
          ),
        ],
      ),
    );
  }
}

/// Escribir al médico: el texto, un archivo opcional y enviar.
class _Redactor extends StatelessWidget {
  final DetalleConsultaState state;
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
      pista: 'Escríbele al médico',
      maximo: maximoMensaje,
      tecladoAbierto: tecladoAbierto,
      enviando: state.enviando,
      progreso: state.progreso,
      error: state.errorEnvio,
      sinRed: 'Sin conexión: para escribirle al médico necesitas Internet.',
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
                  : () => context.read<DetalleConsultaBloc>().add(
                      const DetalleConsultaAdjuntoQuitado(),
                    ),
            ),
    );
  }
}
