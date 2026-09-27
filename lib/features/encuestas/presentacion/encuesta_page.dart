// lib/features/encuestas/presentacion/encuesta_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/configuracion/en_contexto.dart';
import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/proveedores.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/campos.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../citas/data/models/cita.dart';
import '../../citas/presentacion/estilos_cita.dart';
import '../data/encuestas_service.dart';
import '../dominio/reglas_encuesta.dart';
import '../providers/encuesta_cubit.dart';
import '../providers/encuestas_cubit.dart';
import 'widgets/preguntas_encuesta.dart';

/// La encuesta de satisfacción de una cita atendida
/// (`/portal/encuesta/:citaId`): dos preguntas y un comentario opcional, en
/// diez segundos. Solo para las citas atendidas de los últimos
/// `general.encuestasDiasVentana` días, una vez por cita.
class EncuestaPage extends StatelessWidget {
  final String citaId;
  final EncuestasService? servicio;

  const EncuestaPage({super.key, required this.citaId, this.servicio});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EncuestaCubit(
        servicio ?? Servicios.encuestas,
        citaId: citaId,
        uid: context.read<AuthBloc>().usuario?.uid ?? '',
        pendientes: context.leerSiHay<EncuestasCubit>(),
      )..cargar(),
      child: const _VistaEncuesta(),
    );
  }
}

class _VistaEncuesta extends StatefulWidget {
  const _VistaEncuesta();

  @override
  State<_VistaEncuesta> createState() => _VistaEncuestaState();
}

class _VistaEncuestaState extends State<_VistaEncuesta> {
  final _comentario = TextEditingController();

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  void _enviar() {
    cerrarTeclado();
    context.read<EncuestaCubit>().enviar(comentario: _comentario.text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EncuestaCubit, EncuestaState>(
      // Otra encuesta: el comentario empieza en blanco.
      listenWhen: (antes, ahora) => antes.citaId != ahora.citaId,
      listener: (_, _) => _comentario.clear(),
      builder: (context, state) {
        final formulario = state.etapa == EtapaEncuesta.formulario;

        return Scaffold(
          backgroundColor: AppColors.fondo,
          appBar: AppBar(title: const Text('Encuesta de satisfacción')),
          bottomNavigationBar: formulario
              ? BarraDeAccion(
                  child: ConRed(
                    builder: (context, hayRed) => BotonPrincipal(
                      key: const Key('enviar-encuesta'),
                      texto: 'Enviar respuesta',
                      icono: Icons.send_rounded,
                      cargando: state.enviando,
                      textoCargando: 'Enviando…',
                      onPressed: hayRed ? _enviar : null,
                    ),
                  ),
                )
              : null,
          body: FondoDegradado(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: context.margenDeScroll(),
              children: [
                const AvisoSinConexion(
                  queSePuedeHacer:
                      'Para enviar tu respuesta necesitas conexión.',
                ),
                switch (state.etapa) {
                  EtapaEncuesta.cargando => const CargandoCentro(
                    mensaje: 'Buscando tu cita…',
                  ),
                  EtapaEncuesta.formulario => _Formulario(
                    state: state,
                    comentario: _comentario,
                  ),
                  EtapaEncuesta.noDisponible => _NoDisponible(state: state),
                  EtapaEncuesta.gracias => _Gracias(state: state),
                  EtapaEncuesta.yaRespondida => const _YaRespondida(),
                },
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Formulario extends StatelessWidget {
  final EncuestaState state;
  final TextEditingController comentario;

  const _Formulario({required this.state, required this.comentario});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EncuestaCubit>();
    final cita = state.cita;
    final error = state.error;
    final habilitado = !state.enviando;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '¿Cómo te fue en tu consulta?',
          style: TextStyle(
            color: AppColors.texto,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        if (cita != null)
          _ResumenCita(cita: cita)
        else if (state.sinDatosDeLaCita)
          const RecuadroAviso.alerta(
            'No pudimos cargar los datos de la cita, pero puedes responder '
            'igual.',
          ),
        const SizedBox(height: 22),
        PreguntaEncuesta(
          enunciado: '¿Cómo calificarías la atención que recibiste?',
          error: state.intentado && !state.puntuacionValida
              ? 'Elige de 1 a 5 estrellas.'
              : null,
          respuesta: EstrellasEncuesta(
            valor: state.puntuacion,
            alElegir: habilitado ? cubit.elegirPuntuacion : null,
          ),
        ),
        const SizedBox(height: 24),
        PreguntaEncuesta(
          enunciado:
              '¿Qué tan probable es que recomiendes a '
              '${_elMedico(cita)} a un familiar o amigo?',
          error: state.intentado && !state.recomendacionValida
              ? 'Elige un número del 0 al 10.'
              : null,
          respuesta: EscalaRecomendacion(
            valor: state.recomendaria,
            alElegir: habilitado ? cubit.elegirRecomendacion : null,
          ),
        ),
        const SizedBox(height: 24),
        const EtiquetaCampo('¿Algo que quieras contarnos? (opcional)'),
        CampoCliniq(
          key: const Key('campo-comentario-encuesta'),
          controller: comentario,
          pista: 'Qué te gustó, qué podríamos mejorar…',
          lineas: 4,
          maximo: comentarioEncuestaMaximo,
          habilitado: habilitado,
          teclado: TextInputType.multiline,
          accion: TextInputAction.newline,
          mayusculas: TextCapitalization.sentences,
        ),
        const SizedBox(height: 6),
        const Text(
          'Tu médico verá tu calificación y tu comentario, sin tu nombre.',
          style: TextStyle(color: AppColors.textoTenue, fontSize: 11.5),
        ),
        if (error != null) ...[
          const SizedBox(height: 14),
          RecuadroAviso.error(error),
        ],
        const SizedBox(height: 8),
        Align(
          child: TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textoSecundario,
            ),
            child: const Text('Ahora no'),
          ),
        ),
      ],
    );
  }
}

/// «tu médico», o su nombre si se sabe.
String _elMedico(Cita? cita) {
  final medico = cita?.medico;
  return medico == null || medico.isEmpty ? 'tu médico' : medico;
}

/// La cita que se califica: el día, el médico, la modalidad y para quién.
class _ResumenCita extends StatelessWidget {
  final Cita cita;

  const _ResumenCita({required this.cita});

  @override
  Widget build(BuildContext context) {
    final modalidad = context.modalidad(cita.tipo);
    final especialidad = cita.especialidad;
    final paciente = cita.pacienteNombre;

    return TarjetaTranslucida(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              _elMedico(cita),
              if (especialidad != null && especialidad.isNotEmpty) especialidad,
            ].join(' · '),
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${FormatoFecha.diaLargo(cita.inicio)}, '
            '${FormatoFecha.hora(cita.inicio)}',
            style: const TextStyle(color: AppColors.textoSuave, fontSize: 12.5),
          ),
          if (cita.paraDependiente && paciente != null) ...[
            const SizedBox(height: 3),
            Text(
              'Cita de $paciente',
              style: const TextStyle(color: AppColors.textoTenue, fontSize: 12),
            ),
          ],
          const SizedBox(height: 9),
          Pastilla(
            texto: modalidad.nombre,
            color: modalidad.color,
            icono: modalidad.icono,
          ),
        ],
      ),
    );
  }
}

class _NoDisponible extends StatelessWidget {
  final EncuestaState state;

  const _NoDisponible({required this.state});

  @override
  Widget build(BuildContext context) {
    final ventana = context.config.general.encuestasDiasVentana;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EstadoVacio(
          key: const Key('encuesta-no-disponible'),
          icono: Icons.event_busy_outlined,
          titulo: 'Esta encuesta ya no está disponible',
          descripcion:
              'Puede que ya la hayas respondido o que hayan pasado más de '
              '${dias(ventana)} desde la consulta.',
        ),
        _Siguiente(state: state, texto: 'Responder otra pendiente'),
      ],
    );
  }
}

class _Gracias extends StatelessWidget {
  final EncuestaState state;

  const _Gracias({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EstadoVacio(
          key: const Key('encuesta-gracias'),
          icono: Icons.check_circle_outline_rounded,
          color: AppColors.exito,
          titulo: '¡Gracias por tu opinión!',
          descripcion:
              'Tu respuesta llega a ${_elMedico(state.cita)} y a la clínica, '
              'y nos ayuda a mejorar la atención.',
        ),
        _Siguiente(state: state, texto: 'Responder la siguiente'),
      ],
    );
  }
}

class _YaRespondida extends StatelessWidget {
  const _YaRespondida();

  @override
  Widget build(BuildContext context) {
    return const EstadoVacio(
      key: Key('encuesta-ya-respondida'),
      icono: Icons.info_outline_rounded,
      titulo: 'Ya respondiste esta encuesta',
      descripcion:
          'Solo se responde una vez por cita. ¡Gracias por tomarte el tiempo!',
    );
  }
}

/// Pasar a la siguiente pendiente, si hay.
class _Siguiente extends StatelessWidget {
  final EncuestaState state;
  final String texto;

  const _Siguiente({required this.state, required this.texto});

  @override
  Widget build(BuildContext context) {
    if (state.otras.isEmpty) return const SizedBox.shrink();

    final siguiente = state.otras.first;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: BotonSecundario(
        key: const Key('siguiente-encuesta'),
        texto: texto,
        icono: Icons.arrow_forward_rounded,
        onPressed: () =>
            context.read<EncuestaCubit>().responderOtra(siguiente.id),
      ),
    );
  }
}
