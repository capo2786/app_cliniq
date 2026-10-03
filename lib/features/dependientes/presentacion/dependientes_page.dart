// lib/features/dependientes/presentacion/dependientes_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/cerrar_sesion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../agendar/presentacion/agendar_page.dart';
import '../../auth/data/models/usuario.dart';
import '../../auth/providers/auth_bloc.dart';
import '../data/models/dependiente.dart';
import '../dominio/validaciones.dart';
import '../providers/dependientes_bloc.dart';
import 'formulario_dependiente_page.dart';
import '../../../core/catalogos/catalogo_service.dart';
import '../../../core/configuracion/en_contexto.dart';
import '../../../core/presentacion/widgets/contacto_clinica.dart';
import '../../avisos/presentacion/widgets/boton_campana.dart';
import '../../ayuda/presentacion/widgets/boton_ayuda.dart';

/// Quienes están a cargo del titular: hijos, padres, personas que dependen
/// de él. Se les agenda citas como a uno mismo.
class DependientesPage extends StatelessWidget {
  const DependientesPage({super.key});

  Future<void> _refrescar(BuildContext context) async {
    final usuario = context.read<AuthBloc>().usuario;
    if (usuario == null) return;

    final bloc = context.read<DependientesBloc>()
      ..add(DependientesSolicitados(usuario.uid));

    await bloc.stream
        .firstWhere((s) => s.carga != CargaDependientes.cargando)
        .timeout(const Duration(seconds: 15), onTimeout: () => bloc.state);
  }

  void _abrirFormulario(BuildContext context, [Dependiente? dependiente]) {
    Navigator.of(context).push(
      MaterialPageRoute<Dependiente>(
        builder: (_) => FormularioDependientePage(dependiente: dependiente),
      ),
    );
  }

  Future<void> _quitar(BuildContext context, Dependiente d) async {
    final confirmado = await confirmarAccion(
      context,
      titulo: '¿Quitar a ${d.nombre}?',
      mensaje:
          'Dejará de aparecer en tu cuenta y ya no podrás agendarle '
          'citas. Su historial en la clínica se conserva.',
      confirmar: 'Quitar',
      icono: Icons.person_remove_outlined,
      peligroso: true,
    );

    if (confirmado && context.mounted) {
      context.read<DependientesBloc>().add(DependienteEliminado(d));
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthBloc>().usuario;
    final puede = usuario?.puede(Permisos.dependientes) ?? false;
    final puedeAgendar = usuario?.puede(Permisos.agendar) ?? false;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(
        title: const Text('Dependientes'),
        actions: const [
          BotonAyuda(clave: 'app.dependientes'),
          BotonCampana(),
          BotonCerrarSesion(),
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
                    titulo: 'Tu cuenta no gestiona dependientes',
                    descripcion:
                        'Si necesitas agendar para alguien a tu '
                        'cargo, pide que lo habiliten en la clínica.',
                  ),
                  Center(child: ContactoClinica()),
                ],
              )
            : BlocConsumer<DependientesBloc, DependientesState>(
                // Los avisos de guardar los da el formulario; aquí, solo los
                // de quitar (que no tienen pantalla propia).
                listenWhen: (antes, ahora) =>
                    ahora.operacion != null &&
                    antes.operacion != ahora.operacion &&
                    ahora.operacion!.guardado == null &&
                    ModalRoute.of(context)?.isCurrent != false,
                listener: (context, state) => mostrarAviso(
                  context,
                  state.operacion!.mensaje,
                  error: !state.operacion!.exito,
                ),
                builder: (context, state) {
                  return RefreshIndicator(
                    color: AppColors.acentoClaro,
                    backgroundColor: AppColors.superficie,
                    onRefresh: () => _refrescar(context),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: context.margenDeScroll(),
                      children: [
                        const AvisoSinConexion(),
                        TarjetaEncabezado(
                          icono: Icons.family_restroom_rounded,
                          titulo: 'Quienes están a tu cargo',
                          descripcion:
                              'Agenda citas para ellos; las '
                              'confirmaciones llegan a tu correo.',
                          accesorio: state.lista.isEmpty
                              ? null
                              : Pastilla(
                                  texto: '${state.lista.length}',
                                  color: Colors.white,
                                ),
                        ),
                        const SizedBox(height: 16),
                        ConRed(
                          builder: (context, hayRed) => BotonPrincipal(
                            texto: 'Agregar dependiente',
                            icono: Icons.person_add_alt_1_rounded,
                            onPressed: hayRed
                                ? () => _abrirFormulario(context)
                                : null,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (state.lista.isNotEmpty)
                          const EtiquetaSeccion('Registrados'),
                        if (state.carga == CargaDependientes.cargando &&
                            state.lista.isEmpty)
                          const CargandoCentro(
                            mensaje: 'Cargando dependientes…',
                          )
                        else if (state.carga == CargaDependientes.error &&
                            state.lista.isEmpty)
                          EstadoError(
                            mensaje:
                                state.error ??
                                'No pudimos traer tus dependientes.',
                            alReintentar: () => _refrescar(context),
                          )
                        else if (state.lista.isEmpty)
                          const EstadoVacio(
                            icono: Icons.diversity_1_rounded,
                            titulo: 'Aún no tienes dependientes',
                            descripcion:
                                'Registra a tus hijos, a tus padres '
                                'o a quien esté a tu cargo para agendarles '
                                'citas desde tu cuenta.',
                          )
                        else
                          for (final d in state.lista) ...[
                            _TarjetaDependiente(
                              dependiente: d,
                              ocupado: state.guardando,
                              alEditar: () => _abrirFormulario(context, d),
                              alQuitar: () => _quitar(context, d),
                              alAgendar: puedeAgendar
                                  ? () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) =>
                                            AgendarPage(para: d.uid),
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _TarjetaDependiente extends StatelessWidget {
  final Dependiente dependiente;
  final bool ocupado;
  final VoidCallback alEditar;
  final VoidCallback alQuitar;
  final VoidCallback? alAgendar;

  const _TarjetaDependiente({
    required this.dependiente,
    required this.ocupado,
    required this.alEditar,
    required this.alQuitar,
    this.alAgendar,
  });

  String get _iniciales {
    final partes = dependiente.nombre
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final d = dependiente;
    final anios = edad(d.fechaNacimiento, Servicios.reloj.hoy());

    return TarjetaTranslucida(
      tinte: AppColors.menta,
      onTap: ocupado ? null : alEditar,
      padding: const EdgeInsets.fromLTRB(15, 13, 6, 13),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.menta.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.menta.withValues(alpha: 0.4)),
            ),
            child: Text(
              _iniciales,
              style: const TextStyle(
                color: AppColors.menta,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.nombre,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (d.parentesco != null) d.parentesco!,
                    if (anios != null) '$anios ${anios == 1 ? 'año' : 'años'}',
                    if (d.cedula != null)
                      '${etiquetaDe(context.catalogos, Catalogos.tipoDocumento, d.tipoDocumento)} '
                          '${d.cedula}',
                  ].join(' · '),
                  style: const TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            enabled: !ocupado,
            tooltip: 'Opciones',
            color: AppColors.tarjeta,
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textoSuave,
            ),
            onSelected: (opcion) {
              switch (opcion) {
                case 'agendar':
                  alAgendar?.call();
                case 'editar':
                  alEditar();
                case 'quitar':
                  alQuitar();
              }
            },
            itemBuilder: (_) => [
              if (alAgendar != null)
                const PopupMenuItem(
                  value: 'agendar',
                  child: Text('Agendar una cita'),
                ),
              const PopupMenuItem(value: 'editar', child: Text('Editar datos')),
              const PopupMenuItem(
                value: 'quitar',
                child: Text(
                  'Quitar',
                  style: TextStyle(color: AppColors.peligroSuave),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
