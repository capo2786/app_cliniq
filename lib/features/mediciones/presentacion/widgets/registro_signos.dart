// lib/features/mediciones/presentacion/widgets/registro_signos.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/avisos.dart';
import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../data/cola_mediciones.dart';
import '../../data/models/medicion.dart';
import '../../dominio/reglas_mediciones.dart';
import '../../providers/mis_signos_vitales_cubit.dart';
import 'partes_mediciones.dart';

/// «Presión arterial 120/80 mmHg».
String nombreDelTipoYValor(Medicion m) =>
    '${nombreDelTipo(m.tipo)} ${valorDeMedicion(m)}';

/// La pregunta antes de eliminar una medición: la misma en la lista y en
/// el detalle.
Future<bool> confirmarEliminarMedicion(BuildContext context, Medicion m) =>
    confirmarAccion(
      context,
      titulo: '¿Eliminar esta medición?',
      mensaje:
          'Se borra «${nombreDelTipoYValor(m)}» de tus signos vitales. Tu '
          'médico ya no la verá.',
      confirmar: 'Eliminar',
      icono: Icons.delete_outline_rounded,
      peligroso: true,
    );

/// La pestaña «Registro»: lo pendiente de enviar y la lista por fecha, con
/// «Ver mediciones anteriores». Cada tarjeta se toca para ver su detalle.
class RegistroSignos extends StatelessWidget {
  final MisSignosVitalesState state;
  final DateTime ahora;

  /// Abre el detalle de una medición guardada.
  final ValueChanged<Medicion>? alAbrir;

  /// Abre el detalle de un envío pendiente.
  final ValueChanged<EnvioPendiente>? alAbrirPendiente;

  const RegistroSignos({
    super.key,
    required this.state,
    required this.ahora,
    this.alAbrir,
    this.alAbrirPendiente,
  });

  Future<void> _eliminar(BuildContext context, Medicion m) async {
    final cubit = context.read<MisSignosVitalesCubit>();
    if (await confirmarEliminarMedicion(context, m)) {
      await cubit.eliminar(m.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MisSignosVitalesCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.pendientes.isNotEmpty) ...[
          const EtiquetaSeccion('Pendientes de enviar'),
          for (final envio in state.pendientes) ...[
            TarjetaPendiente(
              key: Key('pendiente-${envio.idLocal}'),
              envio: envio,
              alDescartar: () => cubit.descartarPendiente(envio.idLocal),
              alAbrir: alAbrirPendiente == null
                  ? null
                  : () => alAbrirPendiente!(envio),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
        ],
        ..._porDia(context),
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
    );
  }

  List<Widget> _porDia(BuildContext context) {
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
            alAbrir: alAbrir == null ? null : () => alAbrir!(m),
          ),
        )
        ..add(const SizedBox(height: 10));
    }
    return widgets;
  }
}
