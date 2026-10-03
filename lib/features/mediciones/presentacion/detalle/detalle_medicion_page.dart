// lib/features/mediciones/presentacion/detalle/detalle_medicion_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/avisos.dart';
import '../../../../core/presentacion/margenes.dart';
import '../../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/cerrar_sesion.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/fondo_app.dart';
import '../../../../core/servicios.dart';
import '../../../../core/tema/tokens.dart';
import '../../../auth/providers/auth_bloc.dart';
import '../../../ayuda/presentacion/widgets/boton_ayuda.dart';
import '../../data/cola_mediciones.dart';
import '../../data/mediciones_service.dart';
import '../../data/models/medicion.dart';
import '../../providers/detalle_medicion_cubit.dart';
import '../widgets/registro_signos.dart';
import 'cabecera_medicion.dart';
import 'cuerpo_detalle.dart';

/// «Detalle de la medición»: lo que se abre al tocar una medición en
/// «Registro», o con la ruta `/portal/mediciones/:id` (también la de un
/// dependiente: el servidor decide si es de quien pregunta).
///
/// Arriba, la cabecera; debajo, las tarjetas y las gráficas del resultado
/// del escáner si es el pulso de la cámara con su detalle, o los datos si
/// es de un aparato; al final, «Eliminar». Una medición pendiente de envío
/// se abre con los datos de la cola, detalle incluido.
///
/// Vuelve con `true` si la lista tiene que refrescarse (se eliminó, o ya
/// no existe).
class DetalleMedicionPage extends StatelessWidget {
  final String medicionId;

  /// La de la lista, si se abrió desde ella: se enseña sin esperar.
  final Medicion? medicion;

  /// La otra medición del mismo escaneo (la FR del pulso o al revés).
  final Medicion? companera;

  /// Un envío de la cola.
  final EnvioPendiente? pendiente;

  /// El dependiente, si es de uno.
  final String? pacienteNombre;

  /// Por defecto, los de `Servicios`.
  final MedicionesService? servicio;
  final ColaMediciones? cola;

  const DetalleMedicionPage({
    super.key,
    required this.medicionId,
    this.medicion,
    this.companera,
    this.pacienteNombre,
    this.servicio,
    this.cola,
  }) : pendiente = null;

  DetalleMedicionPage.pendiente(
    EnvioPendiente envio, {
    super.key,
    this.pacienteNombre,
    this.servicio,
    this.cola,
  }) : medicionId = envio.idLocal,
       pendiente = envio,
       medicion = null,
       companera = null;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthBloc>().usuario?.uid ?? '';
    final elServicio = servicio ?? Servicios.mediciones;
    final laCola = cola ?? Servicios.colaMediciones;
    final envio = pendiente;

    return BlocProvider(
      create: (_) => envio != null
          ? DetalleMedicionCubit.pendiente(
              servicio: elServicio,
              cola: laCola,
              uid: uid,
              envio: envio,
            )
          : (DetalleMedicionCubit(
              servicio: elServicio,
              cola: laCola,
              uid: uid,
              medicionId: medicionId,
              medicion: medicion,
              companera: companera,
            )..cargar()),
      child: _VistaDetalle(pacienteNombre: pacienteNombre),
    );
  }
}

class _VistaDetalle extends StatelessWidget {
  final String? pacienteNombre;

  const _VistaDetalle({required this.pacienteNombre});

  Future<void> _eliminar(BuildContext context, DetalleMedicionState s) async {
    final cubit = context.read<DetalleMedicionCubit>();
    final si = s.pendiente
        ? await confirmarAccion(
            context,
            titulo: '¿Descartar esta medición?',
            mensaje: 'Se borra de este teléfono y no se enviará a la clínica.',
            confirmar: 'Descartar',
            icono: Icons.delete_outline_rounded,
            peligroso: true,
          )
        : await confirmarEliminarMedicion(context, s.medicion!);
    if (si) await cubit.eliminar();
  }

  void _alCambiar(BuildContext context, DetalleMedicionState s) {
    if (s.eliminada) {
      mostrarAviso(
        context,
        s.pendiente ? 'Medición descartada.' : 'Medición eliminada.',
      );
      Navigator.of(context).pop(true);
    } else if (s.aviso != null) {
      mostrarAviso(context, s.aviso!.mensaje, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DetalleMedicionCubit, DetalleMedicionState>(
      listenWhen: (antes, ahora) =>
          (ahora.eliminada && !antes.eliminada) ||
          (ahora.aviso != null && ahora.aviso != antes.aviso),
      listener: _alCambiar,
      builder: (context, state) {
        final noExiste = state.carga == CargaDetalle.noExiste;
        return PopScope(
          // Si ya no existe, la lista tiene que enterarse al volver.
          canPop: !noExiste,
          onPopInvokedWithResult: (salio, _) {
            if (!salio) Navigator.of(context).pop(true);
          },
          child: Scaffold(
            backgroundColor: AppColors.fondo,
            appBar: AppBar(
              title: const Text('Detalle de la medición'),
              actions: const [
                BotonAyuda(clave: 'app.mediciones'),
                BotonCerrarSesion(),
                SizedBox(width: 6),
              ],
            ),
            body: FondoDegradado(
              child: ListView(
                padding: context.margenDeScroll(inferior: 28),
                children: _contenido(context, state),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _contenido(BuildContext context, DetalleMedicionState state) {
    final cubit = context.read<DetalleMedicionCubit>();
    final m = state.medicion;

    if (state.carga == CargaDetalle.noExiste) {
      return [
        EstadoVacio(
          key: const Key('detalle-no-existe'),
          icono: Icons.search_off_rounded,
          titulo: 'Esta medición ya no existe',
          descripcion:
              'Puede que se haya eliminado desde otro teléfono. Vuelve a tus '
              'signos vitales para ver las que tienes.',
          accion: 'Volver',
          alPulsar: () => Navigator.of(context).pop(true),
        ),
      ];
    }
    if (m == null) {
      return [
        if (state.carga == CargaDetalle.error)
          EstadoError(
            mensaje: state.error ?? 'No pudimos cargar esta medición.',
            alReintentar: cubit.cargar,
          )
        else
          const CargandoCentro(mensaje: 'Cargando la medición…'),
      ];
    }

    return [
      const AvisoSinConexion(
        queSePuedeHacer: 'Mostramos lo que guardamos en este teléfono.',
      ),
      CabeceraMedicion(
        medicion: m,
        pendiente: state.pendiente,
        pacienteNombre: pacienteNombre,
      ),
      if (state.pendiente) ...[
        const SizedBox(height: 12),
        if (state.rechazo != null)
          RecuadroAviso.error('No se pudo guardar: ${state.rechazo}')
        else
          const RecuadroAviso.alerta(
            'Pendiente de envío: se enviará sola cuando vuelva la conexión.',
            key: Key('detalle-pendiente'),
            icono: Icons.cloud_upload_outlined,
          ),
      ],
      if (state.desdeCache && state.guardadaEn != null) ...[
        const SizedBox(height: 12),
        RecuadroAviso.informacion(
          'Mostramos la copia guardada el '
          '${FormatoFecha.cortaConHora(state.guardadaEn!)}.',
          icono: Icons.offline_pin_outlined,
        ),
      ],
      const SizedBox(height: 16),
      CuerpoDelDetalle(state: state, alReintentar: cubit.cargar),
      const SizedBox(height: 20),
      if (m.usada && !state.pendiente)
        const RecuadroAviso.informacion(
          'Tu médico usó esta medición en una atención: ya no se puede '
          'eliminar.',
          icono: Icons.lock_outline_rounded,
        )
      else
        BotonSecundario(
          key: const Key('detalle-eliminar'),
          texto: state.eliminando
              ? 'Eliminando…'
              : state.pendiente
              ? 'Descartar'
              : 'Eliminar',
          icono: Icons.delete_outline_rounded,
          color: AppColors.peligroSuave,
          onPressed: state.eliminando ? null : () => _eliminar(context, state),
        ),
    ];
  }
}
