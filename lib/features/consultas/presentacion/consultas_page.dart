// lib/features/consultas/presentacion/consultas_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/data/models/usuario.dart';
import '../../auth/providers/auth_bloc.dart';
import '../data/models/consulta.dart';
import '../dominio/reglas_consultas.dart';
import '../providers/consultas_bloc.dart';
import '../providers/consultas_event.dart';
import '../providers/consultas_state.dart';
import 'detalle_consulta_page.dart';
import 'nueva_consulta_page.dart';
import 'widgets/tarjeta_consulta.dart';
import '../../../core/configuracion/en_contexto.dart';
import '../../../core/presentacion/widgets/contacto_clinica.dart';
import '../../avisos/presentacion/widgets/boton_campana.dart';
import '../../ayuda/presentacion/widgets/boton_ayuda.dart';

/// Consultas en línea: las del paciente y las de sus dependientes, con los
/// borradores arriba, las abiertas después y las terminadas al final.
///
/// Se abre encima de las pestañas, desde el inicio. La lista vive en el
/// bloc de la raíz: se pide fresca al entrar y el plazo de cada consulta se
/// vuelve a calcular cada minuto.
class ConsultasPage extends StatefulWidget {
  const ConsultasPage({super.key});

  @override
  State<ConsultasPage> createState() => _ConsultasPageState();
}

class _ConsultasPageState extends State<ConsultasPage> {
  Timer? _reloj;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _pedir());

    // «Quedan 3 h» tiene que avanzar solo con la pantalla abierta.
    _reloj = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  void _pedir() {
    if (!mounted) return;

    final usuario = context.read<AuthBloc>().usuario;
    if (usuario == null) return;

    context.read<ConsultasBloc>().add(ConsultasSolicitadas(usuario.uid));
  }

  Future<void> _refrescar() async {
    final bloc = context.read<ConsultasBloc>();
    _pedir();

    await bloc.stream
        .firstWhere((s) => !s.cargando)
        .timeout(const Duration(seconds: 15), onTimeout: () => bloc.state);
  }

  Future<void> _nueva() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NuevaConsultaPage()));

    _pedir();
  }

  Future<void> _abrir(ConsultaResumen consulta) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => consulta.estado == EstadoConsulta.borrador
            ? NuevaConsultaPage(borradorId: consulta.id)
            : DetalleConsultaPage(consultaId: consulta.id),
      ),
    );

    _pedir();
  }

  Future<void> _eliminar(ConsultaResumen consulta) async {
    final bloc = context.read<ConsultasBloc>();

    final seguro = await confirmarAccion(
      context,
      titulo: '¿Eliminar el borrador?',
      mensaje:
          'Se borrará «${consulta.motivoNombre}» con sus archivos. No se '
          'puede deshacer.',
      confirmar: 'Eliminar',
      icono: Icons.delete_outline_rounded,
      peligroso: true,
    );

    if (seguro) bloc.add(ConsultaBorradorEliminado(consulta));
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthBloc>().usuario;
    final puede = usuario?.puede(Permisos.consultas) ?? false;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Consultas en línea'),
        actions: const [
          BotonAyuda(clave: 'app.consultas'),
          BotonCampana(),
          SizedBox(width: 6),
        ],
      ),
      body: FondoDegradado(
        child: !puede
            ? ListView(
                padding: context.margenDeScroll(),
                children: const [
                  EstadoVacio(
                    icono: Icons.lock_outline_rounded,
                    titulo: 'Tu cuenta no tiene consultas en línea',
                    descripcion:
                        'Esta sección es para pacientes. Si crees que es un '
                        'error, consúltalo en la clínica.',
                  ),
                  Center(child: ContactoClinica()),
                ],
              )
            : BlocConsumer<ConsultasBloc, ConsultasState>(
                listenWhen: (antes, ahora) =>
                    ahora.aviso != null && antes.aviso != ahora.aviso,
                listener: (context, state) => mostrarAviso(
                  context,
                  state.aviso!.mensaje,
                  error: !state.aviso!.exito,
                ),
                builder: (context, state) => _lista(context, state),
              ),
      ),
    );
  }

  Widget _lista(BuildContext context, ConsultasState state) {
    final ahora = Servicios.reloj.instante();
    final enBorrador = borradores(state.consultas);
    final abiertas = consultasEnCurso(state.consultas);
    final terminadas = consultasTerminadas(state.consultas);

    return RefreshIndicator(
      color: AppColors.acentoClaro,
      backgroundColor: AppColors.superficie,
      onRefresh: _refrescar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: context.margenDeScroll(superior: 20, inferior: 28),
        children: [
          const AvisoSinConexion(
            queSePuedeHacer:
                'Mostramos tus consultas guardadas. Para enviar una consulta '
                'o escribirle al médico necesitas conexión.',
          ),
          TarjetaEncabezado(
            icono: Icons.forum_outlined,
            titulo: 'Consultas en línea',
            descripcion: descripcionDeConsultas(context.config.telemedicina),
          ),
          const SizedBox(height: 16),
          ConRed(
            builder: (context, hayRed) => BotonPrincipal(
              key: const Key('boton-nueva-consulta'),
              texto: 'Nueva consulta',
              icono: Icons.add_comment_outlined,
              onPressed: hayRed ? _nueva : null,
            ),
          ),
          const SizedBox(height: 20),
          if (state.desdeCache && state.guardadasEn != null) ...[
            RecuadroAviso.informacion(
              'Mostramos tus consultas guardadas el '
              '${FormatoFecha.cortaConHora(state.guardadasEn!)}.',
              icono: Icons.offline_pin_outlined,
            ),
            const SizedBox(height: 12),
          ],
          if (state.error != null && state.consultas.isNotEmpty) ...[
            RecuadroAviso.alerta(state.error!),
            const SizedBox(height: 12),
          ],
          if (state.cargando && state.consultas.isEmpty)
            const CargandoCentro(mensaje: 'Trayendo tus consultas…')
          else if (state.carga == CargaConsultas.error &&
              state.consultas.isEmpty)
            EstadoError(
              mensaje: state.error ?? 'No pudimos traer tus consultas.',
              alReintentar: _refrescar,
            )
          else if (state.consultas.isEmpty)
            const EstadoVacio(
              icono: Icons.forum_outlined,
              titulo: 'Todavía no tienes consultas',
              descripcion:
                  'Cuéntale a un médico qué te pasa, adjunta fotos o '
                  'exámenes y te responde por aquí. Para una emergencia, ve '
                  'a la emergencia más cercana.',
            )
          else ...[
            if (enBorrador.isNotEmpty) ...[
              const EtiquetaSeccion('Borradores'),
              for (final consulta in enBorrador) ...[
                TarjetaConsulta(
                  consulta: consulta,
                  ahora: ahora,
                  onTap: () => _abrir(consulta),
                  acciones: _AccionesBorrador(
                    eliminando: state.eliminandoId == consulta.id,
                    alSeguir: () => _abrir(consulta),
                    alEliminar: () => _eliminar(consulta),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 10),
            ],
            if (abiertas.isNotEmpty) ...[
              const EtiquetaSeccion('En curso'),
              for (final consulta in abiertas) ...[
                TarjetaConsulta(
                  consulta: consulta,
                  ahora: ahora,
                  onTap: () => _abrir(consulta),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 10),
            ],
            if (terminadas.isNotEmpty) ...[
              const EtiquetaSeccion('Anteriores'),
              for (final consulta in terminadas) ...[
                TarjetaConsulta(
                  consulta: consulta,
                  ahora: ahora,
                  onTap: () => _abrir(consulta),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

/// Seguir o eliminar un borrador.
class _AccionesBorrador extends StatelessWidget {
  final bool eliminando;
  final VoidCallback alSeguir;
  final VoidCallback alEliminar;

  const _AccionesBorrador({
    required this.eliminando,
    required this.alSeguir,
    required this.alEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return ConRed(
      builder: (context, hayRed) => Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: alSeguir,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Seguir'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.acentoSuave,
              ),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: hayRed && !eliminando ? alEliminar : null,
              icon: eliminando
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.peligroSuave,
                      ),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 17),
              label: const Text('Eliminar'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.peligroSuave,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
