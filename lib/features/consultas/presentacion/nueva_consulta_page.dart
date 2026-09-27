// lib/features/consultas/presentacion/nueva_consulta_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/configuracion/config_publica_cubit.dart';
import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/data/models/usuario.dart';
import '../../auth/providers/auth_bloc.dart';
import '../providers/consultas_bloc.dart';
import '../providers/consultas_event.dart';
import '../providers/nueva_consulta_bloc.dart';
import '../providers/nueva_consulta_event.dart';
import '../providers/nueva_consulta_state.dart';
import 'pasos/paso_enviada.dart';
import 'pasos/paso_especialidad.dart';
import 'pasos/paso_formulario.dart';
import 'pasos/paso_medico.dart';
import 'pasos/paso_motivo.dart';
import 'pasos/paso_paciente.dart';
import 'pasos/paso_resumen.dart';

/// Una consulta en línea nueva (o un borrador que se retoma), paso a paso.
///
/// Como el agendamiento: una pregunta por pantalla, el progreso arriba, el
/// botón para seguir abajo, y el «atrás» del sistema vuelve un paso. Crea su
/// propio bloc en cada visita para que las opciones lleguen frescas.
class NuevaConsultaPage extends StatelessWidget {
  /// El borrador que se retoma, o `null` para empezar una nueva.
  final String? borradorId;

  /// Un dependiente preelegido.
  final String? para;

  const NuevaConsultaPage({super.key, this.borradorId, this.para});

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<AuthBloc>().usuario;
    final config = context.read<ConfigPublicaCubit>().config;

    return BlocProvider(
      create: (_) => NuevaConsultaBloc(
        consultas: Servicios.consultas,
        dependientes: Servicios.dependientes,
        uid: usuario?.uid ?? '',
        nombreTitular: usuario?.nombre ?? '',
        maximoAdjuntos: config.telemedicina.maxArchivosConsulta,
        archivos: config.archivos,
        puedeDependientes: usuario?.puede(Permisos.dependientes) ?? false,
      )..add(NuevaConsultaIniciada(borradorId: borradorId, para: para)),
      child: _VistaNuevaConsulta(borradorId: borradorId, para: para),
    );
  }
}

/// Qué hacer al salir con cosas escritas.
enum _AlSalir { guardar, descartar, seguir }

class _VistaNuevaConsulta extends StatelessWidget {
  /// Lo mismo con que se abrió, para reintentar la carga igual.
  final String? borradorId;
  final String? para;

  const _VistaNuevaConsulta({this.borradorId, this.para});

  Future<void> _salir(BuildContext context, NuevaConsultaState state) async {
    final navegador = Navigator.of(context);
    final bloc = context.read<NuevaConsultaBloc>();

    if (!state.cambiosSinGuardar) {
      navegador.pop();
      return;
    }

    final decision = await showDialog<_AlSalir>(
      context: context,
      builder: (contexto) => AlertDialog(
        backgroundColor: AppColors.superficie,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Guardar la consulta?',
          style: TextStyle(
            color: AppColors.texto,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'Si la guardas como borrador, la sigues después desde Consultas en '
          'línea. El médico no la verá hasta que la envíes.',
          style: TextStyle(color: AppColors.textoSuave, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(_AlSalir.descartar),
            child: const Text(
              'Salir sin guardar',
              style: TextStyle(color: AppColors.peligroSuave),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(_AlSalir.seguir),
            child: const Text(
              'Seguir',
              style: TextStyle(color: AppColors.textoSecundario),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(_AlSalir.guardar),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.acento,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar borrador'),
          ),
        ],
      ),
    );

    switch (decision) {
      case _AlSalir.descartar:
        navegador.pop();
      case _AlSalir.guardar:
        bloc.add(const NuevaConsultaBorradorGuardado());

        try {
          final despues = await bloc.stream
              .firstWhere((s) => !s.guardando)
              .timeout(const Duration(minutes: 5), onTimeout: () => bloc.state);

          // Si no se pudo guardar, se queda: el error está a la vista.
          if (despues.errorGuardar == null && navegador.mounted) {
            navegador.pop();
          }
        } catch (_) {
          // La pantalla ya se cerró por otro lado.
        }
      case _AlSalir.seguir:
      case null:
        return;
    }
  }

  /// Atrás: un paso, o salir si ya es el primero (o ya terminó).
  void _atras(BuildContext context, NuevaConsultaState state) {
    if (state.guardando) return;

    if (state.paso != PasoConsulta.enviada &&
        NuevaConsultaBloc.pasoAnterior(state) != null) {
      context.read<NuevaConsultaBloc>().add(const NuevaConsultaRetrocedida());
      return;
    }

    _salir(context, state);
  }

  Future<void> _descartar(BuildContext context) async {
    final bloc = context.read<NuevaConsultaBloc>();

    final seguro = await confirmarAccion(
      context,
      titulo: '¿Descartar la consulta?',
      mensaje: bloc.state.borrador == null
          ? 'Se perderá lo que escribiste.'
          : 'Se borrará el borrador con sus archivos. No se puede deshacer.',
      confirmar: 'Descartar',
      icono: Icons.delete_outline_rounded,
      peligroso: true,
    );

    if (seguro) bloc.add(const NuevaConsultaDescartada());
  }

  @override
  Widget build(BuildContext context) {
    final puede =
        context.read<AuthBloc>().usuario?.puede(Permisos.consultas) ?? false;

    return BlocConsumer<NuevaConsultaBloc, NuevaConsultaState>(
      listenWhen: (antes, ahora) =>
          antes.borrador != ahora.borrador ||
          antes.eliminada != ahora.eliminada ||
          (ahora.aviso != null && antes.aviso != ahora.aviso),
      listener: (context, state) {
        final lista = context.read<ConsultasBloc>();

        // La lista de consultas se entera enseguida de cada cambio.
        final borrador = state.borrador;
        if (borrador != null) lista.add(ConsultaActualizada(borrador.resumen));

        if (state.eliminada) {
          if (borrador != null) lista.add(ConsultaQuitada(borrador.id));
          Navigator.of(context).pop();
          return;
        }

        final aviso = state.aviso;
        if (aviso != null) {
          mostrarAviso(context, aviso.mensaje, error: !aviso.exito);
        }
      },
      builder: (context, state) {
        final editable =
            !state.cargando &&
            state.error == null &&
            state.paso != PasoConsulta.enviada &&
            state.motivo != null &&
            state.medico != null;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (salio, _) {
            if (!salio) _atras(context, state);
          },
          child: Scaffold(
            backgroundColor: AppColors.fondo,
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Atrás',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _atras(context, state),
              ),
              title: Text(
                state.fijada && state.paso != PasoConsulta.enviada
                    ? 'Tu borrador'
                    : 'Consulta en línea',
              ),
              actions: [
                if (editable)
                  PopupMenuButton<String>(
                    tooltip: 'Más opciones',
                    color: AppColors.tarjeta,
                    enabled: !state.guardando,
                    onSelected: (opcion) {
                      if (opcion == 'guardar') {
                        context.read<NuevaConsultaBloc>().add(
                          const NuevaConsultaBorradorGuardado(),
                        );
                      } else {
                        _descartar(context);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'guardar',
                        child: Text('Guardar borrador'),
                      ),
                      PopupMenuItem(
                        value: 'descartar',
                        child: Text('Descartar'),
                      ),
                    ],
                  ),
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
                              'Si crees que es un error, consúltalo en la '
                              'clínica.',
                        ),
                      ],
                    )
                  : _cuerpo(context, state),
            ),
            bottomNavigationBar: puede ? _BarraDeAccion(state: state) : null,
          ),
        );
      },
    );
  }

  Widget _cuerpo(BuildContext context, NuevaConsultaState state) {
    if (state.cargando) {
      return const Center(
        child: CargandoCentro(mensaje: 'Buscando médicos y motivos…'),
      );
    }

    final error = state.error;
    if (error != null) {
      return ListView(
        padding: context.margenDeScroll(),
        children: [
          EstadoError(
            mensaje: error,
            alReintentar: () => context.read<NuevaConsultaBloc>().add(
              NuevaConsultaIniciada(borradorId: borradorId, para: para),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (state.paso != PasoConsulta.enviada) _Progreso(state: state),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (hijo, animacion) => FadeTransition(
              opacity: animacion,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(animacion),
                child: hijo,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(state.paso),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: context.margenDeScroll(superior: 12, inferior: 24),
                children: [
                  if (state.paso != PasoConsulta.enviada)
                    const AvisoSinConexion(
                      queSePuedeHacer:
                          'Puedes preparar la consulta, pero para guardarla o '
                          'enviarla necesitas conexión.',
                    ),
                  _paso(state),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _paso(NuevaConsultaState state) {
    return switch (state.paso) {
      PasoConsulta.paciente => PasoPacienteConsulta(state: state),
      PasoConsulta.especialidad => PasoEspecialidad(state: state),
      PasoConsulta.motivo => PasoMotivoConsulta(state: state),
      PasoConsulta.medico => PasoMedicoConsulta(state: state),
      PasoConsulta.formulario => PasoFormulario(state: state),
      PasoConsulta.resumen => PasoResumenConsulta(state: state),
      PasoConsulta.enviada => PasoEnviada(state: state),
    };
  }
}

/// «Paso 3 de 6 · ¿Cuál es el motivo?», con su barra.
class _Progreso extends StatelessWidget {
  final NuevaConsultaState state;

  const _Progreso({required this.state});

  @override
  Widget build(BuildContext context) {
    final pasos = state.pasosDelRecorrido;
    final indice = pasos.indexOf(state.paso);
    final numero = indice < 0 ? 1 : indice + 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PASO $numero DE ${pasos.length}',
            style: const TextStyle(
              color: AppColors.textoSecundario,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            state.paso.titulo,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: numero / pasos.length),
              duration: const Duration(milliseconds: 320),
              builder: (context, valor, _) => LinearProgressIndicator(
                value: valor,
                minHeight: 6,
                color: AppColors.acento,
                backgroundColor: AppColors.bordeCampo,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// El botón para seguir, siempre al pie.
class _BarraDeAccion extends StatelessWidget {
  final NuevaConsultaState state;

  const _BarraDeAccion({required this.state});

  @override
  Widget build(BuildContext context) {
    // Los pasos que avanzan al tocar una opción no necesitan botón.
    final sinBoton =
        state.cargando ||
        state.error != null ||
        state.paso == PasoConsulta.especialidad ||
        state.paso == PasoConsulta.motivo ||
        state.paso == PasoConsulta.medico ||
        state.paso == PasoConsulta.enviada;

    if (sinBoton) return const SizedBox.shrink();

    final bloc = context.read<NuevaConsultaBloc>();
    final resumen = state.paso == PasoConsulta.resumen;
    final formulario = state.paso == PasoConsulta.formulario;

    return BarraDeAccion(
      child: ConRed(
        builder: (context, hayRed) => BotonPrincipal(
          key: const Key('boton-seguir-consulta'),
          texto: resumen ? 'Enviar consulta' : 'Continuar',
          icono: resumen ? Icons.send_rounded : Icons.arrow_forward_rounded,
          cargando: state.guardando,
          textoCargando: state.progreso ?? 'Guardando…',
          // En el formulario el botón siempre se puede tocar: si falta algo,
          // tocarlo es lo que marca qué.
          onPressed: resumen
              ? (hayRed && state.lista
                    ? () {
                        cerrarTeclado();
                        bloc.add(const NuevaConsultaConfirmada());
                      }
                    : null)
              : (formulario || NuevaConsultaBloc.pasoCompleto(state))
              ? () {
                  cerrarTeclado();
                  bloc.add(const NuevaConsultaContinuada());
                }
              : null,
        ),
      ),
    );
  }
}
