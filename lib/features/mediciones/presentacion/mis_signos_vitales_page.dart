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
import '../dominio/reglas_mediciones.dart';
import '../escaner/escaner_page.dart';
import '../providers/mis_signos_vitales_cubit.dart';
import 'registrar_medicion_page.dart';
import 'widgets/grafico_evolucion.dart';
import 'widgets/partes_mediciones.dart';

/// «Mis signos vitales»: lo que el paciente midió en casa (y, si la
/// clínica lo activa, con el escáner experimental), por fecha, con la
/// evolución del pulso y de la presión.
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

  const MisSignosVitalesPage({
    super.key,
    this.pacienteId,
    this.pacienteNombre,
    this.destino,
    this.servicio,
    this.cola,
  });

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthBloc>().usuario?.uid ?? '';

    return BlocProvider(
      create: (_) => MisSignosVitalesCubit(
        servicio: servicio ?? Servicios.mediciones,
        cola: cola ?? Servicios.colaMediciones,
        uid: uid,
        pacienteId: pacienteId,
      )..iniciar(),
      child: _VistaSignos(
        pacienteId: pacienteId,
        pacienteNombre: pacienteNombre,
        destino: destino,
        cola: cola,
      ),
    );
  }
}

class _VistaSignos extends StatelessWidget {
  final String? pacienteId;
  final String? pacienteNombre;
  final DestinoMedico? destino;
  final ColaMediciones? cola;

  const _VistaSignos({
    required this.pacienteId,
    required this.pacienteNombre,
    required this.destino,
    required this.cola,
  });

  Future<void> _registrar(BuildContext context) async {
    final cubit = context.read<MisSignosVitalesCubit>();
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
    if (guardo == true) await cubit.cargar();
  }

  Future<void> _medir(BuildContext context) async {
    final cubit = context.read<MisSignosVitalesCubit>();
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
    if (guardo == true) await cubit.cargar();
  }

  Future<void> _eliminar(BuildContext context, Medicion m) async {
    final cubit = context.read<MisSignosVitalesCubit>();
    final si = await confirmarAccion(
      context,
      titulo: '¿Eliminar esta medición?',
      mensaje:
          'Se borra «${nombreDelTipoYValor(m)}» de tus signos vitales. Tu '
          'médico ya no la verá.',
      confirmar: 'Eliminar',
      icono: Icons.delete_outline_rounded,
      peligroso: true,
    );
    if (si) await cubit.eliminar(m.id);
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
                onRefresh: cubit.cargar,
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
                    if (state.pendientes.isNotEmpty) ...[
                      const EtiquetaSeccion('Pendientes de enviar'),
                      for (final envio in state.pendientes) ...[
                        TarjetaPendiente(
                          envio: envio,
                          alDescartar: () =>
                              cubit.descartarPendiente(envio.idLocal),
                        ),
                        const SizedBox(height: 10),
                      ],
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
                      _Evolucion(mediciones: state.mediciones),
                      ..._porDia(context, state, ahora),
                      if (state.hayMas) ...[
                        const SizedBox(height: 6),
                        BotonSecundario(
                          key: const Key('signos-ver-mas'),
                          texto: state.cargandoMas
                              ? 'Cargando…'
                              : 'Ver mediciones anteriores',
                          icono: Icons.history_rounded,
                          onPressed: state.cargandoMas ? null : cubit.verMas,
                        ),
                      ],
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

  List<Widget> _porDia(
    BuildContext context,
    MisSignosVitalesState state,
    DateTime ahora,
  ) {
    final ordenadas = [...state.mediciones]
      ..sort((a, b) => b.medidoEn.compareTo(a.medidoEn));
    final widgets = <Widget>[];
    String? diaAnterior;
    for (final m in ordenadas) {
      final dia = diaDeLaMedicion(m.medidoEn, ahora);
      if (dia != diaAnterior) {
        if (diaAnterior != null) widgets.add(const SizedBox(height: 8));
        widgets.add(EtiquetaSeccion(dia));
        diaAnterior = dia;
      }
      widgets
        ..add(
          TarjetaMedicion(
            key: Key('medicion-${m.id}'),
            medicion: m,
            eliminando: state.eliminandoId == m.id,
            alEliminar: () => _eliminar(context, m),
          ),
        )
        ..add(const SizedBox(height: 10));
    }
    return widgets;
  }
}

/// «Presión arterial 120/80 mmHg».
String nombreDelTipoYValor(Medicion m) =>
    '${nombreDelTipo(m.tipo)} ${valorDeMedicion(m)}';

/// La evolución del pulso y de la presión, si hay dos puntos o más.
class _Evolucion extends StatelessWidget {
  final List<Medicion> mediciones;

  const _Evolucion({required this.mediciones});

  @override
  Widget build(BuildContext context) {
    final graficos = [
      for (final tipo in const [TipoMedicion.pa, TipoMedicion.fc])
        if (serieDelTipo(mediciones, tipo) case final serie
            when serie.length >= 2)
          GraficoEvolucion(
            key: Key('grafico-${tipo.codigo}'),
            tipo: tipo,
            serie: serie,
          ),
    ];
    if (graficos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EtiquetaSeccion('Evolución'),
          TarjetaTranslucida(
            child: Column(
              children: [
                for (final (i, g) in graficos.indexed) ...[
                  if (i > 0) const SizedBox(height: 22),
                  g,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
