// lib/features/mediciones/presentacion/widgets/registro_signos.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/avisos.dart';
import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../data/models/medicion.dart';
import '../../dominio/reglas_mediciones.dart';
import '../../providers/mis_signos_vitales_cubit.dart';
import 'partes_mediciones.dart';

/// «Presión arterial 120/80 mmHg».
String nombreDelTipoYValor(Medicion m) =>
    '${nombreDelTipo(m.tipo)} ${valorDeMedicion(m)}';

/// La pestaña «Registro»: lo pendiente de enviar y la lista por fecha, con
/// «Ver mediciones anteriores».
class RegistroSignos extends StatelessWidget {
  final MisSignosVitalesState state;
  final DateTime ahora;

  const RegistroSignos({super.key, required this.state, required this.ahora});

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
    final cubit = context.read<MisSignosVitalesCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.pendientes.isNotEmpty) ...[
          const EtiquetaSeccion('Pendientes de enviar'),
          for (final envio in state.pendientes) ...[
            TarjetaPendiente(
              envio: envio,
              alDescartar: () => cubit.descartarPendiente(envio.idLocal),
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
          ),
        )
        ..add(const SizedBox(height: 10));
    }
    return widgets;
  }
}
