// lib/features/mi_salud/presentacion/receta_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/presentacion/widgets/contacto_clinica.dart';
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

/// Una receta entera, dentro de la aplicación, en las dos partes de la
/// receta ecuatoriana:
///
/// - **Para la farmacia** (la prescripción): cada medicamento por su nombre
///   genérico, la concentración, la forma farmacéutica y la cantidad a
///   dispensar en números y en letras.
/// - **Cómo tomarlo** (las indicaciones para el paciente): vía, dosis,
///   frecuencia, duración e indicaciones de cada medicamento, las
///   recomendaciones y los signos de alarma.
///
/// Luego el diagnóstico, quién la emitió, la modalidad de la atención y el
/// código con que la farmacia la comprueba. Se guarda en el teléfono para
/// enseñarla sin cobertura. Si el médico la firmó electrónicamente, lo
/// dice; si la atención fue a distancia y no está firmada, avisa que así no
/// sirve para la farmacia. «Ver PDF» abre la receta en PDF (la firmada o la
/// vista previa).
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
        claveDeAyuda: 'app.miSalud.receta',
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
          ] else if (!receta.firmado &&
              esAtencionADistancia(receta.modalidad)) ...[
            const SizedBox(height: 12),
            const RecuadroAviso.alerta(
              'La atención fue a distancia: sin la firma electrónica del '
              'médico, esta receta no es válida para retirar los '
              'medicamentos en la farmacia.',
              key: Key('aviso-receta-sin-firma'),
              icono: Icons.edit_off_outlined,
            ),
          ],
          const SizedBox(height: 22),
          EtiquetaSeccion(
            'Para la farmacia · ${medicamentos(receta.items.length)}',
          ),
          _ParaLaFarmacia(items: receta.items),
          const SizedBox(height: 22),
          const EtiquetaSeccion('Cómo tomarlo'),
          for (final item in receta.items) ...[
            _ComoTomarlo(item: item),
            const SizedBox(height: 10),
          ],
          if (receta.indicacionesNoFarmacologicas != null) ...[
            TarjetaTranslucida(
              key: const Key('recomendaciones-receta'),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: BloqueDeTexto(
                rotulo: 'Recomendaciones',
                texto: receta.indicacionesNoFarmacologicas!,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (receta.signosAlarma != null)
            _SignosDeAlarma(texto: receta.signosAlarma!),
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

/// La prescripción: lo que se lleva a la farmacia. Cada medicamento por su
/// nombre genérico, con la concentración, la forma y la cantidad a
/// dispensar en números y en letras.
class _ParaLaFarmacia extends StatelessWidget {
  final List<ItemReceta> items;

  const _ParaLaFarmacia({required this.items});

  @override
  Widget build(BuildContext context) {
    return TarjetaTranslucida(
      key: const Key('receta-para-la-farmacia'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Muestra esta parte en la farmacia.',
            style: TextStyle(color: AppColors.textoSecundario, fontSize: 12.5),
          ),
          for (final item in items) ...[
            const Divider(color: AppColors.bordeCampo, height: 22),
            _Prescripcion(item: item),
          ],
        ],
      ),
    );
  }
}

class _Prescripcion extends StatelessWidget {
  final ItemReceta item;

  const _Prescripcion({required this.item});

  @override
  Widget build(BuildContext context) {
    final presentacion = item.presentacion;
    final cantidad = item.cantidadADispensar;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.medication_rounded,
            color: AppColors.acentoClaro,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.medicamento,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (presentacion != null) ...[
                const SizedBox(height: 2),
                Text(
                  presentacion,
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (cantidad != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Cantidad: $cantidad',
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Las indicaciones de un medicamento para el paciente: dosis, frecuencia,
/// duración, vía e indicaciones.
class _ComoTomarlo extends StatelessWidget {
  final ItemReceta item;

  const _ComoTomarlo({required this.item});

  @override
  Widget build(BuildContext context) {
    final datos = [
      if (item.dosis.isNotEmpty) ('Dosis', item.dosis),
      if (item.frecuencia.isNotEmpty) ('Frecuencia', item.frecuencia),
      if (item.duracion.isNotEmpty) ('Duración', item.duracion),
      if (item.via != null) ('Vía', item.via!),
    ];

    return TarjetaTranslucida(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.nombreCompleto,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (datos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                for (final (rotulo, valor) in datos)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RotuloPequeno(rotulo),
                      const SizedBox(height: 2),
                      Text(
                        valor,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          if (item.indicaciones != null) ...[
            const SizedBox(height: 10),
            Text(
              item.indicaciones!,
              style: const TextStyle(
                color: AppColors.textoSuave,
                fontSize: 13,
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

/// Ante qué volver a consultar o ir a emergencias, con el número de
/// emergencias de la clínica (si lo tiene configurado).
class _SignosDeAlarma extends StatelessWidget {
  final String texto;

  const _SignosDeAlarma({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('signos-de-alarma'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.peligro.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.peligro.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.peligroSuave,
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Signos de alarma',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            texto,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Si notas alguno, busca atención médica de inmediato.',
            style: TextStyle(color: AppColors.textoSuave, fontSize: 12.5),
          ),
          const BotonEmergencia(),
        ],
      ),
    );
  }
}
