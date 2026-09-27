// lib/features/soporte/presentacion/nuevo_ticket_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/archivos/archivo_local.dart';
import '../../../core/catalogos/catalogo_service.dart';
import '../../../core/catalogos/catalogos_cubit.dart';
import '../../../core/configuracion/config_publica_cubit.dart';
import '../../../core/configuracion/en_contexto.dart';
import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/enlaces.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/visual_del_servidor.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/campos.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../agendar/presentacion/widgets/opcion_seleccionable.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../consultas/presentacion/widgets/adjuntos.dart';
import '../data/models/ticket.dart';
import '../data/soporte_service.dart';
import '../dominio/reglas_soporte.dart';
import '../providers/nuevo_ticket_cubit.dart';

/// Abrir un ticket de soporte: sobre qué es (las categorías de la clínica),
/// cuánto afecta (las severidades con sus horas de respuesta), el asunto, la
/// descripción y, si ayuda, una captura.
///
/// Se cierra devolviendo el ticket creado.
class NuevoTicketPage extends StatelessWidget {
  /// Por defecto, `Servicios.soporte`.
  final SoporteService? servicio;

  const NuevoTicketPage({super.key, this.servicio});

  @override
  Widget build(BuildContext context) {
    final catalogos = context.read<CatalogosCubit>().state;

    return BlocProvider(
      create: (_) => NuevoTicketCubit(
        servicio: servicio ?? Servicios.soporte,
        uid: context.read<AuthBloc>().usuario?.uid ?? '',
        archivos: context.read<ConfigPublicaCubit>().config.archivos,
        categoria: categoriaInicial(catalogos.items(Catalogos.categoriaTicket)),
        severidad: severidadInicial(
          severidadesOfrecidas(catalogos.items(Catalogos.severidadTicket)),
        ),
      ),
      child: const _VistaNuevoTicket(),
    );
  }
}

class _VistaNuevoTicket extends StatefulWidget {
  const _VistaNuevoTicket();

  @override
  State<_VistaNuevoTicket> createState() => _VistaNuevoTicketState();
}

class _VistaNuevoTicketState extends State<_VistaNuevoTicket> {
  final TextEditingController _asunto = TextEditingController();
  final TextEditingController _descripcion = TextEditingController();

  NuevoTicketCubit get _cubit => context.read<NuevoTicketCubit>();

  @override
  void dispose() {
    _asunto.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  void _enviar() {
    cerrarTeclado();
    _cubit.enviar(asunto: _asunto.text, descripcion: _descripcion.text);
  }

  Future<void> _adjuntar() async {
    final cubit = _cubit;
    final seleccion = await elegirArchivos(context, varios: false);

    if (seleccion != null && !seleccion.vacia) cubit.elegirAdjunto(seleccion);
  }

  void _alTerminar(BuildContext context, NuevoTicketState state) {
    final problema = state.problemaDelAdjunto;
    mostrarAviso(
      context,
      problema ?? 'Ticket enviado. Te avisaremos cuando soporte responda.',
      error: problema != null,
    );
    Navigator.of(context).pop<Ticket>(state.creado);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<NuevoTicketCubit, NuevoTicketState>(
          listenWhen: (antes, ahora) =>
              ahora.aviso != null && antes.aviso != ahora.aviso,
          listener: (context, state) => mostrarAviso(
            context,
            state.aviso!.mensaje,
            error: !state.aviso!.exito,
          ),
        ),
        BlocListener<NuevoTicketCubit, NuevoTicketState>(
          listenWhen: (antes, ahora) =>
              antes.creado == null && ahora.creado != null,
          listener: _alTerminar,
        ),
      ],
      child: BlocBuilder<NuevoTicketCubit, NuevoTicketState>(
        builder: (context, state) => Scaffold(
          backgroundColor: AppColors.fondo,
          appBar: AppBar(title: const Text('Nuevo ticket')),
          bottomNavigationBar: BarraDeAccion(
            child: ConRed(
              builder: (context, hayRed) => BotonPrincipal(
                key: const Key('boton-enviar-ticket'),
                texto: 'Enviar ticket',
                icono: Icons.send_rounded,
                cargando: state.enviando,
                textoCargando: state.progreso,
                onPressed: hayRed ? _enviar : null,
              ),
            ),
          ),
          body: FondoDegradado(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: context.margenDeScroll(superior: 16, inferior: 24),
              children: [
                const AvisoSinConexion(
                  queSePuedeHacer: 'Para enviar el ticket necesitas conexión.',
                ),
                const Text(
                  'Cuéntanos qué pasa: mientras más detalle, más rápido lo '
                  'resolvemos. Te responde una persona del equipo.',
                  style: TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                const EtiquetaSeccion('¿Sobre qué es?'),
                _Categorias(state: state),
                const SizedBox(height: 22),
                const EtiquetaSeccion('¿Cuánto te afecta?'),
                _Severidades(
                  elegida: state.severidad,
                  enviando: state.enviando,
                ),
                const SizedBox(height: 22),
                const EtiquetaCampo('Asunto'),
                CampoCliniq(
                  key: const Key('campo-asunto'),
                  controller: _asunto,
                  pista: 'No puedo reprogramar mi cita del lunes',
                  icono: Icons.subject_rounded,
                  maximo: asuntoMaximo,
                  accion: TextInputAction.next,
                  mayusculas: TextCapitalization.sentences,
                  habilitado: !state.enviando,
                ),
                _ErrorDeCampo(state.errorAsunto),
                const SizedBox(height: 14),
                const EtiquetaCampo('Descripción'),
                CampoCliniq(
                  key: const Key('campo-descripcion'),
                  controller: _descripcion,
                  pista:
                      'Qué intentabas hacer, qué pasó y, si hubo un mensaje de '
                      'error, qué decía.',
                  lineas: 5,
                  maximo: descripcionMaxima,
                  teclado: TextInputType.multiline,
                  accion: TextInputAction.newline,
                  mayusculas: TextCapitalization.sentences,
                  habilitado: !state.enviando,
                ),
                _ErrorDeCampo(state.errorDescripcion),
                const SizedBox(height: 22),
                const EtiquetaSeccion('Adjunto (opcional)'),
                _Adjunto(
                  adjunto: state.adjunto,
                  enviando: state.enviando,
                  alAdjuntar: _adjuntar,
                  alQuitar: _cubit.quitarAdjunto,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Las categorías de `CATEGORIA_TICKET`, con su icono, color y descripción.
/// Si es la médica, el aviso de que una urgencia no se atiende aquí.
class _Categorias extends StatelessWidget {
  final NuevoTicketState state;

  const _Categorias({required this.state});

  @override
  Widget build(BuildContext context) {
    final catalogos = context.catalogos;
    final categorias = catalogos.items(Catalogos.categoriaTicket);

    if (categorias.isEmpty) {
      return catalogos.tiene(Catalogos.categoriaTicket)
          ? const RecuadroAviso.alerta(
              'La clínica todavía no tiene categorías de soporte activas. '
              'Comunícate con ella por teléfono o correo.',
            )
          : EstadoError(
              mensaje: mensajeSinCatalogos,
              alReintentar: () => context.read<CatalogosCubit>().cargar(),
            );
    }

    final cubit = context.read<NuevoTicketCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final categoria in categorias) ...[
          OpcionSeleccionable(
            key: Key('categoria-${categoria.codigo}'),
            titulo: categoria.nombre,
            descripcion: categoria.descripcion.isEmpty
                ? null
                : categoria.descripcion,
            icono: iconoDelServidor(categoria.icono),
            color: colorDelServidor(categoria.color),
            elegida: state.categoria == categoria.codigo,
            onTap: state.enviando
                ? null
                : () => cubit.elegirCategoria(categoria.codigo),
          ),
          const SizedBox(height: 8),
        ],
        _ErrorDeCampo(state.errorCategoria),
        if (state.categoria == categoriaMedica) const _AvisoDeUrgencia(),
      ],
    );
  }
}

/// «Si es una urgencia médica, no esperes respuesta aquí»: con el número de
/// emergencias de la clínica, para tocarlo.
class _AvisoDeUrgencia extends StatelessWidget {
  const _AvisoDeUrgencia();

  @override
  Widget build(BuildContext context) {
    final numero = context.config.clinica.telefonoEmergencia;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RecuadroAviso.alerta(
            'Si es una urgencia médica, no esperes respuesta aquí: llama al '
            '$numero o acude a emergencias.',
            icono: Icons.emergency_outlined,
          ),
          TextButton.icon(
            key: const Key('llamar-emergencias'),
            onPressed: () => llamar(context, numero),
            icon: const Icon(Icons.phone_in_talk_outlined, size: 18),
            label: Text('Llamar al $numero'),
            style: TextButton.styleFrom(foregroundColor: AppColors.alerta),
          ),
        ],
      ),
    );
  }
}

/// Las severidades activas de `SEVERIDAD_TICKET`, en su orden, con las
/// horas de respuesta de la clínica (`general.soporteHorasSla`).
class _Severidades extends StatelessWidget {
  final String elegida;
  final bool enviando;

  const _Severidades({required this.elegida, required this.enviando});

  @override
  Widget build(BuildContext context) {
    final catalogos = context.catalogos;
    final horas = context.config.general.soporteHorasSla;
    final cubit = context.read<NuevoTicketCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final codigo in severidadesOfrecidas(
          catalogos.items(Catalogos.severidadTicket),
        )) ...[
          _OpcionSeveridad(
            codigo: codigo,
            item: catalogos.porCodigo(Catalogos.severidadTicket, codigo),
            horas: horas[codigo],
            elegida: elegida == codigo,
            onTap: enviando ? null : () => cubit.elegirSeveridad(codigo),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _OpcionSeveridad extends StatelessWidget {
  final String codigo;
  final ItemCatalogo? item;
  final int? horas;
  final bool elegida;
  final VoidCallback? onTap;

  const _OpcionSeveridad({
    required this.codigo,
    required this.item,
    required this.horas,
    required this.elegida,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final descripcion = [
      if (item?.descripcion.isNotEmpty ?? false) item!.descripcion,
      if (horas != null) 'Respuesta en hasta $horas h',
    ].join(' · ');

    return OpcionSeleccionable(
      key: Key('severidad-$codigo'),
      titulo: item?.nombre ?? codigo,
      descripcion: descripcion.isEmpty ? null : descripcion,
      icono: iconoDelServidor(item?.icono),
      color: colorDelServidor(item?.color),
      elegida: elegida,
      onTap: onTap,
    );
  }
}

/// El archivo elegido (con «quitar») o el botón para elegir uno.
class _Adjunto extends StatelessWidget {
  final ArchivoLocal? adjunto;
  final bool enviando;
  final VoidCallback alAdjuntar;
  final VoidCallback alQuitar;

  const _Adjunto({
    required this.adjunto,
    required this.enviando,
    required this.alAdjuntar,
    required this.alQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final adjunto = this.adjunto;
    final reglas = context.config.archivos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (adjunto != null) ...[
          FilaAdjunto(
            nombre: adjunto.nombreParaSubir,
            tamano: adjunto.tamano,
            esImagen: adjunto.esImagen,
            nota: 'Se sube al enviar',
            alQuitar: enviando ? null : alQuitar,
          ),
          const SizedBox(height: 8),
        ],
        BotonSecundario(
          key: const Key('boton-adjuntar-ticket'),
          texto: adjunto == null ? 'Adjuntar un archivo' : 'Cambiar el archivo',
          icono: Icons.attach_file_rounded,
          onPressed: enviando ? null : alAdjuntar,
        ),
        const SizedBox(height: 8),
        Text(
          'Una captura de pantalla ayuda mucho. '
          '${loQueSePuedeAdjuntar(reglas)}.',
          style: const TextStyle(color: AppColors.textoTenue, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _ErrorDeCampo extends StatelessWidget {
  final String? error;

  const _ErrorDeCampo(this.error);

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    if (error == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
      child: Text(
        error,
        style: const TextStyle(
          color: AppColors.errorTexto,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
