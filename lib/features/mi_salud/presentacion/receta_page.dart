// lib/features/mi_salud/presentacion/receta_page.dart

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
import 'visor_pdf_page.dart';
import 'widgets/partes_documento.dart';
import 'widgets/vista_documento.dart';

/// Una receta entera, dentro de la aplicación: los medicamentos con cómo
/// tomarlos, las recomendaciones, quién la emitió y el código con que la
/// farmacia la comprueba. Se guarda en el teléfono para enseñarla sin
/// cobertura. Si el médico la firmó electrónicamente, lo dice, y con el PDF
/// disponible ofrece «Ver PDF».
class RecetaPage extends StatelessWidget {
  final String id;

  /// La receta que ya venía en Mi salud: se enseña mientras llega la suya.
  final Receta? inicial;

  /// Por defecto, `Servicios.miSalud`.
  final MiSaludService? servicio;

  const RecetaPage({super.key, required this.id, this.inicial, this.servicio});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthBloc>().usuario?.uid ?? '';
    final fuente = servicio ?? Servicios.miSalud;

    return BlocProvider(
      create: (_) =>
          DocumentoCubit<Receta>(() => fuente.receta(uid, id), inicial: inicial)
            ..cargar(),
      child: VistaDeDocumento<Receta>(
        titulo: 'Receta',
        cargando: 'Abriendo la receta…',
        alVerPdf: (context, receta) =>
            abrirPdfDelDocumento(context, TipoDocumentoFirmado.receta, receta),
        contenido: (context, receta) => [
          EncabezadoDeDocumento(
            icono: Icons.medication_outlined,
            titulo: 'Receta médica',
            documento: receta,
          ),
          if (receta.firmado) ...[
            const SizedBox(height: 12),
            SelloDeFirma(firma: receta.firma),
          ],
          if (receta.anulada) ...[
            const SizedBox(height: 12),
            RecuadroAviso.error(
              receta.anuladaMotivo == null
                  ? 'El médico anuló esta receta: ya no es válida.'
                  : 'El médico anuló esta receta: ya no es válida. Motivo: '
                        '${receta.anuladaMotivo}',
            ),
          ],
          const SizedBox(height: 22),
          EtiquetaSeccion(medicamentos(receta.items.length)),
          for (final item in receta.items) ...[
            _Medicamento(item: item),
            const SizedBox(height: 10),
          ],
          if (receta.indicacionesNoFarmacologicas != null) ...[
            const SizedBox(height: 12),
            const EtiquetaSeccion('Recomendaciones'),
            TarjetaTranslucida(
              child: SelectableText(
                receta.indicacionesNoFarmacologicas!,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (receta.diagnosticos.isNotEmpty) ...[
            const SizedBox(height: 22),
            const EtiquetaSeccion('Diagnóstico'),
            TarjetaTranslucida(
              child: ListaDeDiagnosticos(diagnosticos: receta.diagnosticos),
            ),
          ],
          const SizedBox(height: 22),
          const EtiquetaSeccion('Emitida por'),
          EmisorYPaciente(documento: receta),
          if (receta.codigoVerificacion.isNotEmpty) ...[
            const SizedBox(height: 12),
            CodigoDeVerificacion(codigo: receta.codigoVerificacion),
          ],
        ],
      ),
    );
  }
}

/// Un medicamento: el nombre como se pide en la farmacia y cómo se toma.
class _Medicamento extends StatelessWidget {
  final ItemReceta item;

  const _Medicamento({required this.item});

  @override
  Widget build(BuildContext context) {
    return TarjetaTranslucida(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.medication_rounded, color: AppColors.acentoClaro),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.nombreCompleto,
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (item.posologia.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.posologia,
              style: const TextStyle(
                color: AppColors.textoSuave,
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (item.via != null || item.cantidad != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (item.via != null) 'Vía: ${item.via}',
                if (item.cantidad != null) 'Cantidad: ${item.cantidad}',
              ].join(' · '),
              style: const TextStyle(
                color: AppColors.textoSecundario,
                fontSize: 12.5,
              ),
            ),
          ],
          if (item.indicaciones != null) ...[
            const SizedBox(height: 6),
            Text(
              item.indicaciones!,
              style: const TextStyle(
                color: AppColors.textoSuave,
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
