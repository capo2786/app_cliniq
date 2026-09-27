// lib/features/mi_salud/presentacion/orden_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/providers/auth_bloc.dart';
import '../data/mi_salud_service.dart';
import '../data/models/mi_salud.dart';
import '../dominio/reglas_mi_salud.dart';
import '../providers/documento_cubit.dart';
import 'widgets/partes_documento.dart';
import 'widgets/vista_documento.dart';

/// Una orden de laboratorio, de imagen u otra, dentro de la aplicación: los
/// exámenes con sus indicaciones, la prioridad, quién la emitió y su código
/// de verificación.
class OrdenPage extends StatelessWidget {
  final String id;

  /// La orden que ya venía en Mi salud: se enseña mientras llega la suya.
  final Orden? inicial;

  /// Por defecto, `Servicios.miSalud`.
  final MiSaludService? servicio;

  const OrdenPage({super.key, required this.id, this.inicial, this.servicio});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthBloc>().usuario?.uid ?? '';
    final fuente = servicio ?? Servicios.miSalud;

    return BlocProvider(
      create: (_) =>
          DocumentoCubit<Orden>(() => fuente.orden(uid, id), inicial: inicial)
            ..cargar(),
      child: VistaDeDocumento<Orden>(
        titulo: 'Orden',
        cargando: 'Abriendo la orden…',
        contenido: (context, orden) => [
          EncabezadoDeDocumento(
            icono: orden.tipo == TipoOrden.imagen
                ? Icons.monitor_heart_outlined
                : Icons.biotech_outlined,
            titulo: orden.tipo == TipoOrden.otro
                ? 'Orden'
                : 'Orden de ${nombreDelTipoDeOrden(orden.tipo).toLowerCase()}',
            documento: orden,
            pastillas: [
              if (orden.urgente)
                const Pastilla(
                  texto: 'Urgente',
                  color: AppColors.alerta,
                  icono: Icons.priority_high_rounded,
                ),
            ],
          ),
          if (orden.anulada) ...[
            const SizedBox(height: 12),
            RecuadroAviso.error(
              orden.anuladaMotivo == null
                  ? 'El médico anuló esta orden: ya no es válida.'
                  : 'El médico anuló esta orden: ya no es válida. Motivo: '
                        '${orden.anuladaMotivo}',
            ),
          ] else if (orden.urgente) ...[
            const SizedBox(height: 12),
            const RecuadroAviso.alerta(
              'El médico la marcó como urgente: hazte estos exámenes lo antes '
              'posible.',
              icono: Icons.priority_high_rounded,
            ),
          ],
          const SizedBox(height: 22),
          EtiquetaSeccion(examenes(orden.items.length)),
          TarjetaTranslucida(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, item) in orden.items.indexed) ...[
                  if (i > 0) const Divider(color: AppColors.bordeCampo),
                  _Examen(item: item),
                ],
              ],
            ),
          ),
          if (orden.observaciones != null) ...[
            const SizedBox(height: 22),
            const EtiquetaSeccion('Observaciones'),
            TarjetaTranslucida(
              child: SelectableText(
                orden.observaciones!,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (orden.diagnosticos.isNotEmpty) ...[
            const SizedBox(height: 22),
            const EtiquetaSeccion('Diagnóstico'),
            TarjetaTranslucida(
              child: ListaDeDiagnosticos(diagnosticos: orden.diagnosticos),
            ),
          ],
          const SizedBox(height: 22),
          const EtiquetaSeccion('Emitida por'),
          EmisorYPaciente(documento: orden),
          if (orden.codigoVerificacion.isNotEmpty) ...[
            const SizedBox(height: 12),
            CodigoDeVerificacion(codigo: orden.codigoVerificacion),
          ],
        ],
      ),
    );
  }
}

class _Examen extends StatelessWidget {
  final ItemOrden item;

  const _Examen({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_box_outline_blank_rounded,
              size: 18,
              color: AppColors.primarioClaro,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: item.nombre),
                      if (item.codigo != null)
                        TextSpan(
                          text: '  (${item.codigo})',
                          style: const TextStyle(
                            color: AppColors.textoTenue,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.indicaciones != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.indicaciones!,
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
