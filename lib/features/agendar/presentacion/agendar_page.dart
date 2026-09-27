// lib/features/agendar/presentacion/agendar_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/catalogos/catalogos_cubit.dart';
import '../../../core/configuracion/config_publica_cubit.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/contacto_clinica.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/data/models/usuario.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../citas/data/models/cita.dart';
import '../../citas/providers/citas_bloc.dart';
import '../../citas/providers/citas_event.dart';
import '../dominio/reglas_agendamiento.dart';
import '../providers/agendar_bloc.dart';
import '../providers/agendar_event.dart';
import '../providers/agendar_state.dart';
import 'pasos/paso_filtros.dart';
import 'pasos/paso_horario.dart';
import 'pasos/paso_listo.dart';
import 'pasos/paso_medico.dart';
import 'pasos/paso_modalidad.dart';
import 'pasos/paso_motivo.dart';
import 'pasos/paso_paciente.dart';
import 'pasos/paso_resumen.dart';

/// Agendar (o reprogramar) una cita, paso a paso.
///
/// En el web todo va en una página que se completa de arriba abajo; en un
/// teléfono eso es un formulario interminable. Aquí cada pregunta tiene su
/// pantalla, con un solo botón para seguir y el progreso arriba, y el botón
/// «atrás» del sistema vuelve un paso en vez de tirar todo lo elegido.
///
/// Crea su propio bloc en cada visita: los médicos y sus turnos libres
/// tienen que llegar frescos cada vez que alguien va a agendar.
class AgendarPage extends StatelessWidget {
  final Cita? reprogramar;
  final String? para;

  const AgendarPage({super.key, this.reprogramar, this.para});

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<AuthBloc>().usuario;
    final catalogos = context.read<CatalogosCubit>().state;

    return BlocProvider(
      create: (_) => AgendarBloc(
        portal: Servicios.portal,
        dependientes: Servicios.dependientes,
        uid: usuario?.uid ?? '',
        nombreTitular: usuario?.nombre ?? '',
        reglas: ReglasAgendamiento.de(
          context.read<ConfigPublicaCubit>().config.agenda,
        ),
        ciudades: catalogos.ciudades,
        puedeDependientes: usuario?.puede(Permisos.dependientes) ?? false,
        reloj: Servicios.reloj,
      )..add(AgendarIniciado(reprogramar: reprogramar, para: para)),
      child: const _VistaAgendar(),
    );
  }
}

class _VistaAgendar extends StatelessWidget {
  const _VistaAgendar();

  /// Atrás: un paso, o salir si ya es el primero (o ya terminó).
  void _atras(BuildContext context, AgendarState state) {
    if (state.paso != PasoAgendar.listo &&
        AgendarBloc.pasoAnterior(state) != null &&
        !state.guardando) {
      context.read<AgendarBloc>().add(const AgendarRetrocedido());
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final puedeAgendar =
        context.read<AuthBloc>().usuario?.puede(Permisos.agendar) ?? false;

    return BlocConsumer<AgendarBloc, AgendarState>(
      listenWhen: (antes, ahora) =>
          antes.agendada == null && ahora.agendada != null,
      listener: (context, state) {
        // La lista de citas y los recordatorios se enteran enseguida.
        context.read<CitasBloc>().add(CitaActualizada(state.agendada!));
      },
      builder: (context, state) {
        return PopScope(
          canPop:
              state.paso == PasoAgendar.listo ||
              AgendarBloc.pasoAnterior(state) == null,
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
                state.reprogramando ? 'Reprogramar cita' : 'Agendar cita',
              ),
            ),
            body: FondoDegradado(
              child: !puedeAgendar
                  ? ListView(
                      padding: context.margenDeScroll(),
                      children: const [
                        EstadoVacio(
                          icono: Icons.lock_outline_rounded,
                          titulo: 'Tu cuenta no puede agendar',
                          descripcion:
                              'Agendar desde la aplicación es para '
                              'pacientes. Si crees que es un error, '
                              'consúltalo en la clínica.',
                        ),
                        Center(child: ContactoClinica()),
                      ],
                    )
                  : _cuerpo(context, state),
            ),
            bottomNavigationBar: puedeAgendar
                ? _BarraDeAccion(state: state)
                : null,
          ),
        );
      },
    );
  }

  Widget _cuerpo(BuildContext context, AgendarState state) {
    if (state.cargando) {
      return const Center(child: CargandoCentro(mensaje: 'Buscando médicos…'));
    }

    final error = state.error;
    if (error != null) {
      return ListView(
        padding: context.margenDeScroll(),
        children: [
          EstadoError(
            mensaje: error,
            alReintentar: state.reprogramando
                ? null
                : () =>
                      context.read<AgendarBloc>().add(const AgendarIniciado()),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (state.paso != PasoAgendar.listo) _Progreso(state: state),
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
                  if (state.paso != PasoAgendar.listo) const AvisoSinConexion(),
                  _paso(state),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _paso(AgendarState state) {
    return switch (state.paso) {
      PasoAgendar.paciente => PasoPaciente(state: state),
      PasoAgendar.filtros => PasoFiltros(state: state),
      PasoAgendar.medico => PasoMedico(state: state),
      PasoAgendar.modalidad => PasoModalidad(state: state),
      PasoAgendar.horario => PasoHorario(state: state),
      PasoAgendar.motivo => PasoMotivo(state: state),
      PasoAgendar.resumen => PasoResumen(state: state),
      PasoAgendar.listo => PasoListo(state: state),
    };
  }
}

/// «Paso 3 de 7 · Elige al médico», con su barra.
class _Progreso extends StatelessWidget {
  final AgendarState state;

  const _Progreso({required this.state});

  @override
  Widget build(BuildContext context) {
    final pasos = PasoAgendar.values
        .where(
          (p) =>
              p != PasoAgendar.listo &&
              p.index >= state.primerPaso.index &&
              !(state.reprogramando &&
                  (p == PasoAgendar.motivo ||
                      p == PasoAgendar.modalidad ||
                      p == PasoAgendar.medico)),
        )
        .toList();

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

/// El botón para seguir, siempre al pie y al alcance del pulgar.
class _BarraDeAccion extends StatelessWidget {
  final AgendarState state;

  const _BarraDeAccion({required this.state});

  @override
  Widget build(BuildContext context) {
    // Los pasos que avanzan al tocar una opción no necesitan botón.
    final sinBoton =
        state.cargando ||
        state.error != null ||
        state.paso == PasoAgendar.filtros ||
        state.paso == PasoAgendar.medico ||
        state.paso == PasoAgendar.modalidad ||
        state.paso == PasoAgendar.listo;

    if (sinBoton) return const SizedBox.shrink();

    final bloc = context.read<AgendarBloc>();
    final resumen = state.paso == PasoAgendar.resumen;

    return BarraDeAccion(
      child: ConRed(
        builder: (context, hayRed) => BotonPrincipal(
          texto: resumen
              ? (state.reprogramando ? 'Confirmar el cambio' : 'Confirmar cita')
              : 'Continuar',
          icono: resumen
              ? Icons.check_circle_outline_rounded
              : Icons.arrow_forward_rounded,
          cargando: state.guardando,
          textoCargando: state.reprogramando ? 'Reprogramando…' : 'Agendando…',
          onPressed: (resumen && !hayRed) || !AgendarBloc.pasoCompleto(state)
              ? null
              : () {
                  cerrarTeclado();
                  bloc.add(
                    resumen
                        ? const AgendarConfirmado()
                        : const AgendarContinuado(),
                  );
                },
        ),
      ),
    );
  }
}
