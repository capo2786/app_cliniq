// lib/features/mediciones/escaner/escaner_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/configuracion/en_contexto.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/barra_de_accion.dart';
import '../../../core/presentacion/widgets/botones.dart';
import '../../../core/presentacion/widgets/chip_opcion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/red/estado_de_la_red.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../ayuda/presentacion/widgets/boton_ayuda.dart';
import '../../citas/providers/citas_bloc.dart';
import '../../consultas/providers/consultas_bloc.dart';
import '../data/cola_mediciones.dart';
import '../data/models/medicion.dart';
import '../dominio/destinos_medico.dart';
import '../dominio/reglas_mediciones.dart';
import 'analizador_de_medicion.dart';
import 'aviso_experimental.dart';
import 'escaner_cubit.dart';
import 'fuente_camara.dart';
import 'fuente_de_cuadros.dart';
import 'motor_signos_camara.dart';
import 'serie_senal.dart';
import 'widgets/dibujos_escaner.dart';

/// La línea de privacidad del escáner, en cada pantalla donde se mide.
const String lineaDePrivacidad =
    'Ninguna imagen de la cámara se guarda ni se envía: cada cuadro se '
    'convierte aquí mismo en números, y solo números salen del teléfono.';

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
    final segundos = context.config.telemedicina.escanerSegundos ?? 30;
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
                    PasoEscaner.aviso => const _Aviso(),
                    PasoEscaner.modo => _ElegirModo(
                      pacienteNombre: widget.pacienteNombre,
                    ),
                    PasoEscaner.instrucciones => _Instrucciones(
                      modo: state.modo,
                      segundos: state.segundos,
                    ),
                    PasoEscaner.midiendo => _Midiendo(state: state),
                    PasoEscaner.analizando => const Center(
                      child: CargandoCentro(mensaje: 'Calculando tu pulso…'),
                    ),
                    PasoEscaner.resultado => _Resultado(
                      state: state,
                      destinos: _destinos(context),
                    ),
                    PasoEscaner.fallo => _Fallo(state: state),
                    PasoEscaner.guardado => _Guardado(state: state),
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
class _ConBoton extends StatelessWidget {
  final List<Widget> children;
  final Widget? boton;

  const _ConBoton({required this.children, this.boton});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: context.margenDeScroll(superior: 16, inferior: 24),
            children: children,
          ),
        ),
        if (boton != null) BarraDeAccion(child: boton!),
      ],
    );
  }
}

class _LineaPrivacidad extends StatelessWidget {
  const _LineaPrivacidad();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline_rounded, color: AppColors.textoTenue, size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            lineaDePrivacidad,
            key: Key('escaner-privacidad'),
            style: TextStyle(
              color: AppColors.textoTenue,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

// ── El aviso ───────────────────────────────────────────────────────────

class _Aviso extends StatelessWidget {
  const _Aviso();

  @override
  Widget build(BuildContext context) {
    final emergencia = context.config.clinica.telefonoEmergencia;

    return _ConBoton(
      boton: BotonPrincipal(
        key: const Key('escaner-entiendo'),
        texto: 'Entiendo',
        icono: Icons.check_rounded,
        onPressed: () => context.read<EscanerCubit>().aceptarAviso(),
      ),
      children: [
        const TarjetaEncabezado(
          icono: Icons.science_outlined,
          titulo: 'Función experimental',
          descripcion: 'Antes de usarla, lee esto con calma.',
        ),
        const SizedBox(height: 18),
        RecuadroAviso.alerta(
          'Función experimental: no es un dispositivo médico. Los valores '
          'son referenciales; no la uses para decidir tratamientos. Ante '
          'síntomas de alarma llama al $emergencia.',
          icono: Icons.warning_amber_rounded,
        ),
        const SizedBox(height: 14),
        const TarjetaTranslucida(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Qué mide y qué no',
                style: TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Mide tu pulso (frecuencia cardiaca) con la cámara y, si la '
                'señal es muy buena, tus respiraciones por minuto de forma '
                'aproximada.\n\nLa presión arterial, la saturación de '
                'oxígeno, la temperatura y la glucosa no se pueden medir con '
                'la cámara: regístralas desde tus aparatos de casa en «Mis '
                'signos vitales».',
                style: TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const _LineaPrivacidad(),
      ],
    );
  }
}

// ── Elegir el modo ─────────────────────────────────────────────────────

class _ElegirModo extends StatelessWidget {
  final String? pacienteNombre;

  const _ElegirModo({required this.pacienteNombre});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EscanerCubit>();

    Widget opcion({
      required Key key,
      required IconData icono,
      required String titulo,
      required String etiqueta,
      required Color color,
      required String descripcion,
      required ModoEscaner modo,
    }) => TarjetaTranslucida(
      key: key,
      tinte: color,
      onTap: () => cubit.elegirModo(modo),
      child: Row(
        children: [
          Icon(icono, color: color, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Pastilla(texto: etiqueta, color: color),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: const TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textoTenue),
        ],
      ),
    );

    return _ConBoton(
      children: [
        TarjetaEncabezado(
          icono: Icons.monitor_heart_outlined,
          titulo: 'Medir con la cámara',
          descripcion: pacienteNombre == null
              ? 'Tu pulso con la cámara del teléfono. Experimental y '
                    'referencial.'
              : 'El pulso de $pacienteNombre con la cámara del teléfono. '
                    'Experimental y referencial.',
        ),
        const SizedBox(height: 20),
        const EtiquetaSeccion('¿Cómo quieres medir?'),
        opcion(
          key: const Key('modo-dedo'),
          icono: Icons.fingerprint_rounded,
          titulo: 'Dedo',
          etiqueta: 'Recomendado',
          color: AppColors.exito,
          descripcion:
              'La yema sobre la cámara trasera, con el flash encendido. Es '
              'la forma más confiable.',
          modo: ModoEscaner.dedo,
        ),
        const SizedBox(height: 12),
        opcion(
          key: const Key('modo-rostro'),
          icono: Icons.face_retouching_natural_rounded,
          titulo: 'Rostro',
          etiqueta: 'Beta',
          color: AppColors.alerta,
          descripcion:
              'Tu cara frente a la cámara frontal. Menos precisa: necesita '
              'buena luz y que estés quieto.',
          modo: ModoEscaner.rostro,
        ),
        const _LineaPrivacidad(),
      ],
    );
  }
}

// ── Instrucciones ──────────────────────────────────────────────────────

class _Instrucciones extends StatelessWidget {
  final ModoEscaner modo;
  final int segundos;

  const _Instrucciones({required this.modo, required this.segundos});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EscanerCubit>();
    final pasos = switch (modo) {
      ModoEscaner.dedo => [
        'Siéntate y apoya la mano en una mesa.',
        'Cubre la cámara trasera y el flash con la yema del dedo índice, sin '
            'apretar.',
        'No muevas el dedo durante $segundos segundos. El flash se calienta '
            'un poco: es normal.',
      ],
      ModoEscaner.rostro => [
        'Busca una luz pareja de frente (una ventana); evita el sol directo '
            'y la luz de atrás.',
        'Pon tu rostro dentro del óvalo, sin lentes de sol ni gorra.',
        'Quédate quieto y sin hablar durante $segundos segundos.',
      ],
    };

    return _ConBoton(
      boton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotonPrincipal(
            key: const Key('escaner-empezar'),
            texto: 'Empezar a medir',
            icono: Icons.play_arrow_rounded,
            onPressed: cubit.empezar,
          ),
          TextButton(
            onPressed: cubit.volverAModos,
            child: const Text(
              'Cambiar de modo',
              style: TextStyle(color: AppColors.textoSecundario),
            ),
          ),
        ],
      ),
      children: [
        Center(
          child: modo == ModoEscaner.dedo
              ? const DibujoDedo()
              : const DibujoRostro(),
        ),
        const SizedBox(height: 18),
        EtiquetaSeccion(
          modo == ModoEscaner.dedo ? 'Con el dedo' : 'Con el rostro (beta)',
        ),
        for (final (i, paso) in pasos.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.acento.withValues(alpha: 0.25),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    paso,
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const _LineaPrivacidad(),
      ],
    );
  }
}

// ── Midiendo ───────────────────────────────────────────────────────────

Color _colorDeCalidad(double? calidad) => calidad == null
    ? AppColors.textoTenue
    : switch (nivelDeCalidad(calidad)) {
        NivelCalidad.buena => AppColors.exito,
        NivelCalidad.regular => AppColors.alerta,
        NivelCalidad.baja => AppColors.peligroSuave,
      };

class _Midiendo extends StatelessWidget {
  final EscanerState state;

  const _Midiendo({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EscanerCubit>();
    final calidad = state.lectura.calidad;
    final color = _colorDeCalidad(calidad);

    return _ConBoton(
      boton: BotonSecundario(
        key: const Key('escaner-cancelar'),
        texto: 'Cancelar',
        icono: Icons.stop_rounded,
        color: AppColors.peligroSuave,
        onPressed: cubit.cancelar,
      ),
      children: [
        if (state.modo == ModoEscaner.rostro)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                height: 300,
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: AppColors.lente,
                        child: cubit.fuente.vistaPrevia(context),
                      ),
                      OvaloDelRostro(color: color),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          Center(child: LatidoDelDedo(color: AppColors.acento)),
        const SizedBox(height: 20),
        Center(
          child: Text(
            '${state.segundosRestantes} s',
            key: const Key('escaner-cuenta'),
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 40,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: state.avance,
            minHeight: 6,
            color: AppColors.acentoClaro,
            backgroundColor: AppColors.bordeCampo,
          ),
        ),
        const SizedBox(height: 18),
        TarjetaTranslucida(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OndaEnVivo(
                key: const Key('escaner-onda'),
                onda: state.lectura.onda,
                color: AppColors.acentoClaro,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.circle, color: color, size: 12),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      calidad == null
                          ? 'Midiendo la calidad de la señal…'
                          : 'Señal: ${nombreDelNivel(nivelDeCalidad(calidad)).replaceFirst('Calidad ', '')}',
                      key: const Key('escaner-calidad'),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (state.lectura.consejo != null) ...[
          const SizedBox(height: 12),
          RecuadroAviso.alerta(
            state.lectura.consejo!,
            key: const Key('escaner-consejo'),
            icono: Icons.tips_and_updates_outlined,
          ),
        ],
        const _LineaPrivacidad(),
      ],
    );
  }
}

// ── Resultado ──────────────────────────────────────────────────────────

class _Resultado extends StatelessWidget {
  final EscanerState state;
  final List<DestinoMedico> destinos;

  const _Resultado({required this.state, required this.destinos});

  Future<void> _enviarAlMedico(BuildContext context) async {
    final cubit = context.read<EscanerCubit>();
    final destino = destinos.length == 1
        ? destinos.single
        : await showModalBottomSheet<DestinoMedico>(
            context: context,
            backgroundColor: AppColors.superficie,
            showDragHandle: true,
            builder: (contexto) => SafeArea(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  const Text(
                    '¿A cuál de tus atenciones la adjuntamos?',
                    style: TextStyle(
                      color: AppColors.texto,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final d in destinos)
                    ListTile(
                      key: Key('destino-${d.citaId ?? d.consultaId}'),
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        d.citaId != null
                            ? Icons.videocam_outlined
                            : Icons.forum_outlined,
                        color: AppColors.primarioClaro,
                      ),
                      title: Text(
                        d.titulo,
                        style: const TextStyle(color: AppColors.texto),
                      ),
                      subtitle: d.detalle == null || d.detalle!.isEmpty
                          ? null
                          : Text(
                              d.detalle!,
                              style: const TextStyle(
                                color: AppColors.textoSecundario,
                              ),
                            ),
                      onTap: () => Navigator.of(contexto).pop(d),
                    ),
                ],
              ),
            ),
          );
    if (destino != null) await cubit.guardar(destino: destino);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EscanerCubit>();
    final r = state.resultado!;
    final color = _colorDeCalidad(r.calidad);
    final contextos = contextosDelTipo(TipoMedicion.fc);

    return _ConBoton(
      boton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotonPrincipal(
            key: const Key('escaner-guardar'),
            texto: 'Guardar en mis signos vitales',
            icono: Icons.save_alt_rounded,
            cargando: state.guardando,
            textoCargando: 'Guardando…',
            onPressed: () => cubit.guardar(),
          ),
          const SizedBox(height: 10),
          BotonSecundario(
            key: const Key('escaner-enviar-medico'),
            texto: 'Enviar a mi médico',
            icono: Icons.send_rounded,
            onPressed: destinos.isEmpty || state.guardando
                ? null
                : () => _enviarAlMedico(context),
          ),
          TextButton(
            key: const Key('escaner-descartar'),
            onPressed: state.guardando ? null : cubit.descartar,
            child: const Text(
              'Descartar',
              style: TextStyle(color: AppColors.textoSecundario),
            ),
          ),
        ],
      ),
      children: [
        TarjetaTranslucida(
          tinte: color,
          child: Column(
            children: [
              Text(
                '${r.fc} lpm',
                key: const Key('escaner-fc'),
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'Pulso (frecuencia cardiaca)',
                style: TextStyle(color: AppColors.textoSuave, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  Pastilla(
                    key: const Key('escaner-nivel'),
                    texto: nombreDelNivel(r.nivel),
                    color: color,
                    icono: Icons.signal_cellular_alt_rounded,
                  ),
                  const Pastilla(
                    texto: 'Experimental · referencial',
                    color: AppColors.alerta,
                    icono: Icons.science_outlined,
                  ),
                ],
              ),
              if (r.fr != null) ...[
                const SizedBox(height: 14),
                Text(
                  'Respiraciones: ${r.fr} por minuto (aproximado)',
                  key: const Key('escaner-fr'),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (r.vfc != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Variabilidad del pulso: SDNN ${r.vfc!.sdnn.round()} ms · '
                  'RMSSD ${r.vfc!.rmssd.round()} ms',
                  key: const Key('escaner-vfc'),
                  style: const TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                r.origen == OrigenAnalisis.servidor
                    ? 'Analizado en el servidor (experimental)'
                    : 'Calculado en el teléfono',
                key: const Key('escaner-origen'),
                style: const TextStyle(
                  color: AppColors.textoTenue,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        if (r.nivel == NivelCalidad.baja) ...[
          const SizedBox(height: 12),
          const RecuadroAviso.alerta(
            'La señal no fue buena: toma este valor con mucha cautela y, si '
            'puedes, repite la medición.',
          ),
        ],
        for (final advertencia in r.advertencias) ...[
          const SizedBox(height: 10),
          RecuadroAviso.informacion(advertencia, icono: Icons.info_outline),
        ],
        const SizedBox(height: 20),
        const EtiquetaSeccion('¿Cómo estabas?'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in contextos)
              ChipDeOpcion(
                key: Key('contexto-${c.codigo}'),
                texto: nombreDelContexto(c),
                elegido: state.contexto == c,
                onTap: () =>
                    cubit.elegirContexto(state.contexto == c ? null : c),
              ),
          ],
        ),
        if (destinos.isEmpty) ...[
          const SizedBox(height: 14),
          const Text(
            'Para enviarla a tu médico necesitas una cita de telemedicina '
            'próxima o una consulta en línea abierta.',
            key: Key('escaner-sin-destino'),
            style: TextStyle(color: AppColors.textoTenue, fontSize: 12),
          ),
        ],
        if (state.errorAlGuardar != null) ...[
          const SizedBox(height: 12),
          RecuadroAviso.error(state.errorAlGuardar!),
        ],
        const _LineaPrivacidad(),
      ],
    );
  }
}

// ── No se pudo medir ───────────────────────────────────────────────────

class _Fallo extends StatelessWidget {
  final EscanerState state;

  const _Fallo({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EscanerCubit>();

    return _ConBoton(
      boton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotonPrincipal(
            key: const Key('escaner-reintentar'),
            texto: 'Reintentar',
            icono: Icons.refresh_rounded,
            onPressed: cubit.empezar,
          ),
          if (state.fallaPorPermiso) ...[
            const SizedBox(height: 10),
            BotonSecundario(
              texto: 'Abrir ajustes',
              icono: Icons.settings_outlined,
              onPressed: cubit.abrirAjustes,
            ),
          ],
          TextButton(
            onPressed: cubit.volverAModos,
            child: const Text(
              'Cambiar de modo',
              style: TextStyle(color: AppColors.textoSecundario),
            ),
          ),
        ],
      ),
      children: [
        EstadoVacio(
          icono: Icons.heart_broken_outlined,
          titulo: 'No pudimos medir esta vez',
          descripcion:
              state.fallo ?? ConsejosEscaner.paraElMotivo(null, state.modo),
          color: AppColors.alerta,
        ),
        const _LineaPrivacidad(),
      ],
    );
  }
}

// ── Guardado ───────────────────────────────────────────────────────────

class _Guardado extends StatelessWidget {
  final EscanerState state;

  const _Guardado({required this.state});

  @override
  Widget build(BuildContext context) {
    final pendiente = state.registro is RegistroPendiente;
    final destino = state.enviadaA;

    final titulo = pendiente
        ? 'Quedó guardada en este teléfono'
        : destino == null
        ? 'Guardada en tus signos vitales'
        : 'Enviada a tu médico';
    final descripcion = pendiente
        ? 'No hay conexión. La enviaremos sola en cuanto vuelva; mientras '
              'tanto la verás como «Pendiente de enviar».'
        : destino == null
        ? 'La verás en «Mis signos vitales», marcada como medida con la '
              'cámara (experimental).'
        : 'Quedó adjunta a: ${destino.titulo}. Tu médico decide si la usa.';

    return _ConBoton(
      boton: BotonPrincipal(
        key: const Key('escaner-listo'),
        texto: 'Listo',
        icono: Icons.check_rounded,
        onPressed: () => Navigator.of(context).pop(true),
      ),
      children: [
        EstadoVacio(
          icono: pendiente
              ? Icons.cloud_upload_outlined
              : Icons.check_circle_outline_rounded,
          titulo: titulo,
          descripcion: descripcion,
          color: pendiente ? AppColors.alerta : AppColors.exito,
        ),
      ],
    );
  }
}
