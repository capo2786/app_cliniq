// lib/features/mediciones/presentacion/mis_signos_vitales_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/configuracion/en_contexto.dart';
import '../../../core/formato/fechas.dart';
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
import '../../auth/providers/auth_bloc.dart';
import '../../ayuda/presentacion/widgets/boton_ayuda.dart';
import '../data/cola_mediciones.dart';
import '../data/mediciones_service.dart';
import '../data/models/medicion.dart';
import '../dominio/destinos_medico.dart';
import '../escaner/escaner_page.dart';
import '../providers/mis_signos_vitales_cubit.dart';
import '../providers/tendencias_cubit.dart';
import 'detalle/detalle_medicion_page.dart';
import 'detalle/ficha_medicion.dart';
import 'registrar_medicion_page.dart';
import 'widgets/registro_signos.dart';
import 'widgets/selector_pestana_signos.dart';
import 'widgets/tendencias_signos.dart';

export 'widgets/registro_signos.dart' show nombreDelTipoYValor;

/// «Mis signos vitales»: lo que el paciente midió en casa (y, si la
/// clínica lo activa, con el escáner experimental), en dos pestañas:
/// «Tendencias» (por tipo, en 7 días, 30 días o 3 meses, con el mínimo, el
/// promedio, el máximo y la franja de referencia) y «Registro» (la lista
/// por fecha).
///
/// Se abre desde Mi salud (del titular o del dependiente elegido) y desde
/// el detalle de una cita de telemedicina o de una consulta en línea
/// ([destino]): entonces lo que se registre se puede compartir con ese
/// médico. Sin red enseña la última copia y lo pendiente de enviar; nunca
/// inventa valores.
class MisSignosVitalesPage extends StatelessWidget {
  /// El dependiente, o `null` para el titular.
  final String? pacienteId;
  final String? pacienteNombre;

  /// La cita o la consulta desde la que se abrió, si se abrió desde una.
  final DestinoMedico? destino;

  /// Por defecto, los de `Servicios`.
  final MedicionesService? servicio;
  final ColaMediciones? cola;

  /// El reloj de las tendencias (para las pruebas); por defecto, el real.
  final DateTime Function()? ahora;

  const MisSignosVitalesPage({
    super.key,
    this.pacienteId,
    this.pacienteNombre,
    this.destino,
    this.servicio,
    this.cola,
    this.ahora,
  });

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthBloc>().usuario?.uid ?? '';
    final elServicio = servicio ?? Servicios.mediciones;

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => MisSignosVitalesCubit(
            servicio: elServicio,
            cola: cola ?? Servicios.colaMediciones,
            uid: uid,
            pacienteId: pacienteId,
          )..iniciar(),
        ),
        BlocProvider(
          create: (_) => TendenciasCubit(
            servicio: elServicio,
            uid: uid,
            pacienteId: pacienteId,
            ahora: ahora ?? Servicios.reloj.instante,
          )..cargar(),
        ),
      ],
      child: _VistaSignos(
        pacienteId: pacienteId,
        pacienteNombre: pacienteNombre,
        destino: destino,
        servicio: servicio,
        cola: cola,
      ),
    );
  }
}

class _VistaSignos extends StatefulWidget {
  final String? pacienteId;
  final String? pacienteNombre;
  final DestinoMedico? destino;
  final MedicionesService? servicio;
  final ColaMediciones? cola;

  const _VistaSignos({
    required this.pacienteId,
    required this.pacienteNombre,
    required this.destino,
    required this.servicio,
    required this.cola,
  });

  @override
  State<_VistaSignos> createState() => _VistaSignosState();
}

class _VistaSignosState extends State<_VistaSignos> {
  PestanaSignos _pestana = PestanaSignos.tendencias;

  String? get pacienteId => widget.pacienteId;
  String? get pacienteNombre => widget.pacienteNombre;
  DestinoMedico? get destino => widget.destino;
  ColaMediciones? get cola => widget.cola;

  /// Algo nuevo se guardó: la lista y las tendencias se vuelven a pedir.
  Future<void> _recargar(BuildContext context) async {
    final tendencias = context.read<TendenciasCubit>();
    await context.read<MisSignosVitalesCubit>().cargar();
    await tendencias.cargar();
  }

  Future<void> _registrar(BuildContext context) async {
    final guardo = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegistrarMedicionPage(
          pacienteId: pacienteId,
          pacienteNombre: pacienteNombre,
          destino: destino,
          cola: cola,
        ),
      ),
    );
    if (guardo == true && context.mounted) await _recargar(context);
  }

  /// Abre «Detalle de la medición»; si vuelve con `true` (se eliminó o ya
  /// no existe), la lista y las tendencias se vuelven a pedir.
  Future<void> _abrir(BuildContext context, DetalleMedicionPage pagina) async {
    final cambio = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => pagina));
    if (cambio == true && context.mounted) await _recargar(context);
  }

  void _abrirMedicion(BuildContext context, Medicion m) => _abrir(
    context,
    DetalleMedicionPage(
      medicionId: m.id,
      medicion: m,
      companera: companeraDe(
        m,
        context.read<MisSignosVitalesCubit>().state.mediciones,
      ),
      pacienteNombre: pacienteNombre,
      servicio: widget.servicio,
      cola: cola,
    ),
  );

  void _abrirPendiente(BuildContext context, EnvioPendiente envio) => _abrir(
    context,
    DetalleMedicionPage.pendiente(
      envio,
      pacienteNombre: pacienteNombre,
      servicio: widget.servicio,
      cola: cola,
    ),
  );

  Future<void> _medir(BuildContext context) async {
    final guardo = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EscanerPage(
          pacienteId: pacienteId,
          pacienteNombre: pacienteNombre,
          destino: destino,
          cola: cola,
        ),
      ),
    );
    if (guardo == true && context.mounted) await _recargar(context);
  }

  @override
  Widget build(BuildContext context) {
    final reglas = context.config.telemedicina;

    return BlocListener<MisSignosVitalesCubit, MisSignosVitalesState>(
      listenWhen: (antes, ahora) =>
          ahora.aviso != null && antes.aviso != ahora.aviso,
      listener: (context, state) => mostrarAviso(
        context,
        state.aviso!.mensaje,
        error: !state.aviso!.exito,
      ),
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        appBar: AppBar(
          title: const Text('Mis signos vitales'),
          actions: const [
            BotonAyuda(clave: 'app.mediciones'),
            BotonCerrarSesion(),
            SizedBox(width: 6),
          ],
        ),
        body: FondoDegradado(
          child: BlocBuilder<MisSignosVitalesCubit, MisSignosVitalesState>(
            builder: (context, state) {
              final cubit = context.read<MisSignosVitalesCubit>();
              final ahora = Servicios.reloj.instante();

              return RefreshIndicator(
                color: AppColors.acentoClaro,
                backgroundColor: AppColors.superficie,
                onRefresh: () => _recargar(context),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: context.margenDeScroll(inferior: 28),
                  children: [
                    const AvisoSinConexion(
                      queSePuedeHacer:
                          'Mostramos lo último que guardamos en este teléfono. '
                          'Lo que registres quedará pendiente y se enviará '
                          'cuando vuelva la conexión.',
                    ),
                    TarjetaEncabezado(
                      icono: Icons.monitor_heart_outlined,
                      titulo: pacienteNombre == null
                          ? 'Mis signos vitales'
                          : 'Signos vitales de $pacienteNombre',
                      descripcion:
                          'Los valores de tus aparatos de casa: presión, '
                          'pulso, saturación, temperatura, glucosa y peso. '
                          'Tu médico los ve en tu consulta.',
                    ),
                    if (destino != null) ...[
                      const SizedBox(height: 12),
                      RecuadroAviso.informacion(
                        'Lo que registres aquí puede compartirse con tu médico '
                        'de: ${destino!.titulo}.',
                        icono: Icons.link_rounded,
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (reglas.medicionesPacienteActiva) ...[
                      BotonPrincipal(
                        key: const Key('signos-registrar'),
                        texto: 'Registrar',
                        icono: Icons.add_rounded,
                        onPressed: () => _registrar(context),
                      ),
                      if (reglas.escanerDisponible) ...[
                        const SizedBox(height: 10),
                        BotonSecundario(
                          key: const Key('signos-camara'),
                          texto: 'Medir con la cámara (experimental)',
                          icono: Icons.monitor_heart_outlined,
                          onPressed: () => _medir(context),
                        ),
                      ],
                    ] else
                      const RecuadroAviso.alerta(
                        'La clínica no tiene activado el registro de '
                        'mediciones desde la aplicación.',
                      ),
                    const SizedBox(height: 20),
                    if (state.desdeCache && state.guardadaEn != null) ...[
                      RecuadroAviso.informacion(
                        'Mostramos la copia guardada el '
                        '${FormatoFecha.cortaConHora(state.guardadaEn!)}.',
                        icono: Icons.offline_pin_outlined,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (state.error != null && state.hayAlgo) ...[
                      RecuadroAviso.alerta(state.error!),
                      const SizedBox(height: 12),
                    ],
                    if (!state.hayAlgo)
                      switch (state.carga) {
                        CargaSignos.error => EstadoError(
                          mensaje:
                              state.error ??
                              'No pudimos cargar tus signos vitales.',
                          alReintentar: cubit.cargar,
                        ),
                        CargaSignos.lista => const EstadoVacio(
                          icono: Icons.monitor_heart_outlined,
                          titulo: 'Aún no registras mediciones',
                          descripcion:
                              'Toca «Registrar» y anota lo que marque tu '
                              'tensiómetro, oxímetro, termómetro, glucómetro '
                              'o balanza. Tu médico lo verá en tu consulta.',
                        ),
                        _ => const CargandoCentro(
                          mensaje: 'Cargando tus signos vitales…',
                        ),
                      }
                    else ...[
                      SelectorDePestanaSignos(
                        elegida: _pestana,
                        alElegir: (p) => setState(() => _pestana = p),
                      ),
                      const SizedBox(height: 14),
                      switch (_pestana) {
                        PestanaSignos.tendencias => TendenciasSignos(
                          respaldo: state.mediciones,
                        ),
                        PestanaSignos.registro => RegistroSignos(
                          state: state,
                          ahora: ahora,
                          alAbrir: (m) => _abrirMedicion(context, m),
                          alAbrirPendiente: (e) => _abrirPendiente(context, e),
                        ),
                      },
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
