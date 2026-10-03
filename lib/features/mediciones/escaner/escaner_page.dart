// lib/features/mediciones/escaner/escaner_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/configuracion/en_contexto.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/red/estado_de_la_red.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../ayuda/presentacion/widgets/boton_ayuda.dart';
import '../../citas/providers/citas_bloc.dart';
import '../../consultas/providers/consultas_bloc.dart';
import '../data/cola_mediciones.dart';
import '../dominio/destinos_medico.dart';
import 'analizador_de_medicion.dart';
import 'aviso_experimental.dart';
import 'escaner_cubit.dart';
import 'fuente_camara.dart';
import 'fuente_de_cuadros.dart';
import 'motor_signos_camara.dart';
import 'widgets/paso_aviso.dart';
import 'widgets/paso_midiendo.dart';
import 'widgets/paso_resultado.dart';
import 'widgets/pasos_finales.dart';
import 'widgets/pasos_preparacion.dart';

export 'widgets/pasos_comunes.dart' show lineaDePrivacidad;

/// El escáner experimental de signos vitales.
///
/// Mide la frecuencia cardiaca (y, con buena calidad, la respiratoria
/// aproximada) con la cámara: la yema sobre la cámara trasera con el flash
/// (recomendado) o el rostro frente a la frontal (beta). **Nunca** presión,
/// saturación, temperatura ni glucosa: esas no se pueden medir con la
/// cámara y se registran desde los aparatos de casa.
///
/// La primera vez enseña el aviso de función experimental. El resultado se
/// guarda en «Mis signos vitales» o se envía al médico (adjunto a la
/// próxima cita de telemedicina o a una consulta en línea abierta). Al
/// salir con algo guardado devuelve `true`.
class EscanerPage extends StatelessWidget {
  /// El dependiente, o `null` para el titular.
  final String? pacienteId;
  final String? pacienteNombre;

  /// Si se abrió desde una cita o una consulta: el único destino de
  /// «Enviar a mi médico».
  final DestinoMedico? destino;

  /// Para las pruebas: por defecto la cámara, el motor del teléfono con el
  /// análisis del servidor, la cola de `Servicios` y el aviso en la caché.
  final FuenteDeCuadros? fuente;
  final AnalizadorDeMedicion? analizador;
  final ColaMediciones? cola;
  final AvisoDelEscaner? aviso;

  const EscanerPage({
    super.key,
    this.pacienteId,
    this.pacienteNombre,
    this.destino,
    this.fuente,
    this.analizador,
    this.cola,
    this.aviso,
  });

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthBloc>().usuario?.uid ?? '';
    final reglas = context.config.telemedicina;
    final segundos = reglas.escanerSegundos ?? 30;
    const motor = MotorInterno();

    return BlocProvider(
      create: (_) => EscanerCubit(
        fuente: fuente ?? FuenteCamara(),
        motor: motor,
        analizador:
            analizador ??
            AnalizadorDeMedicion(
              local: motor,
              servidor: Servicios.analisisEnServidor,
              hayRed: () => SondeoDeRed().hayRed,
            ),
        cola: cola ?? Servicios.colaMediciones,
        aviso: aviso ?? AvisoDelEscaner(Servicios.cache),
        uid: uid,
        pacienteId: pacienteId,
        segundos: segundos,
        dedoActivo: reglas.escanerDedoActivo,
      )..iniciar(),
      child: _VistaEscaner(
        destinoFijo: destino,
        pacienteId: pacienteId,
        pacienteNombre: pacienteNombre,
      ),
    );
  }
}

class _VistaEscaner extends StatefulWidget {
  final DestinoMedico? destinoFijo;
  final String? pacienteId;
  final String? pacienteNombre;

  const _VistaEscaner({
    required this.destinoFijo,
    required this.pacienteId,
    required this.pacienteNombre,
  });

  @override
  State<_VistaEscaner> createState() => _VistaEscanerState();
}

class _VistaEscanerState extends State<_VistaEscaner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // En segundo plano la cámara se suelta: una medición a medias no sirve.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      context.read<EscanerCubit>().interrumpir();
    }
  }

  /// Las opciones de «Enviar a mi médico».
  List<DestinoMedico> _destinos(BuildContext context) {
    final fijo = widget.destinoFijo;
    if (fijo != null) return [fijo];

    try {
      return destinosParaElMedico(
        citas: context.read<CitasBloc>().state.citas,
        consultas: context.read<ConsultasBloc>().state.consultas,
        uid: context.read<AuthBloc>().usuario?.uid ?? '',
        pacienteId: widget.pacienteId,
        ahora: Servicios.reloj.ahora(),
      );
    } on ProviderNotFoundException {
      return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EscanerCubit, EscanerState>(
      builder: (context, state) {
        final cubit = context.read<EscanerCubit>();
        final guardado = state.paso == PasoEscaner.guardado;

        return PopScope(
          canPop:
              state.paso != PasoEscaner.midiendo &&
              state.paso != PasoEscaner.analizando,
          onPopInvokedWithResult: (salio, _) {
            if (!salio && state.paso == PasoEscaner.midiendo) cubit.cancelar();
          },
          child: Scaffold(
            backgroundColor: AppColors.fondo,
            appBar: AppBar(
              title: const Text('Escáner experimental'),
              leading: IconButton(
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close_rounded),
                onPressed: () async {
                  final navegador = Navigator.of(context);
                  await cubit.cancelar();
                  navegador.pop(guardado);
                },
              ),
              actions: const [
                BotonAyuda(clave: 'app.escaner'),
                SizedBox(width: 6),
              ],
            ),
            body: FondoDegradado(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(state.paso),
                  child: switch (state.paso) {
                    PasoEscaner.cargando ||
                    PasoEscaner.abriendo => const Center(
                      child: CargandoCentro(mensaje: 'Preparando la cámara…'),
                    ),
                    PasoEscaner.aviso => const PasoAviso(),
                    PasoEscaner.modo => PasoElegirModo(
                      pacienteNombre: widget.pacienteNombre,
                    ),
                    PasoEscaner.instrucciones => PasoInstrucciones(
                      modo: state.modo,
                      segundos: state.segundos,
                    ),
                    PasoEscaner.midiendo => PasoMidiendo(state: state),
                    PasoEscaner.analizando => const Center(
                      child: CargandoCentro(mensaje: 'Calculando tu pulso…'),
                    ),
                    PasoEscaner.resultado => PasoResultado(
                      state: state,
                      destinos: _destinos(context),
                    ),
                    PasoEscaner.fallo => PasoFallo(state: state),
                    PasoEscaner.guardado => PasoGuardado(state: state),
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Un cuerpo desplazable con el botón abajo.
