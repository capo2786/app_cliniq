// lib/features/mi_salud/presentacion/certificado_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formato/fechas.dart';
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

/// Un certificado médico de reposo dentro de la aplicación: cuántos días,
/// desde y hasta cuándo, de qué tipo, la contingencia, las recomendaciones,
/// quién lo emitió y su código de verificación. El diagnóstico aparece solo
/// si el servidor lo manda y el certificado no lo reserva, igual que en el
/// PDF. Si el médico lo firmó, lo dice, y con el PDF disponible ofrece «Ver
/// PDF».
class CertificadoPage extends StatelessWidget {
  final String id;

  /// El certificado que ya venía en Mi salud: se enseña mientras llega el
  /// suyo.
  final CertificadoReposo? inicial;

  /// Por defecto, `Servicios.miSalud`.
  final MiSaludService? servicio;

  const CertificadoPage({
    super.key,
    required this.id,
    this.inicial,
    this.servicio,
  });

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthBloc>().usuario?.uid ?? '';
    final fuente = servicio ?? Servicios.miSalud;

    return BlocProvider(
      create: (_) => DocumentoCubit<CertificadoReposo>(
        () => fuente.certificado(uid, id),
        inicial: inicial,
      )..cargar(),
      child: VistaDeDocumento<CertificadoReposo>(
        titulo: 'Certificado de reposo',
        cargando: 'Abriendo el certificado…',
        alVerPdf: (context, certificado) => abrirPdfDelDocumento(
          context,
          TipoDocumentoFirmado.certificado,
          certificado,
        ),
        contenido: (context, certificado) => [
          EncabezadoDeDocumento(
            icono: Icons.hotel_outlined,
            titulo: 'Certificado médico de reposo',
            documento: certificado,
            masculino: true,
          ),
          if (certificado.firmado) ...[
            const SizedBox(height: 12),
            SelloDeFirma(firma: certificado.firma),
          ],
          if (certificado.anulada) ...[
            const SizedBox(height: 12),
            RecuadroAviso.error(
              certificado.anuladaMotivo == null
                  ? 'El médico anuló este certificado: ya no es válido.'
                  : 'El médico anuló este certificado: ya no es válido. '
                        'Motivo: ${certificado.anuladaMotivo}',
            ),
          ],
          const SizedBox(height: 22),
          const EtiquetaSeccion('Reposo'),
          _Reposo(certificado: certificado),
          if (certificado.recomendaciones != null) ...[
            const SizedBox(height: 22),
            const EtiquetaSeccion('Recomendaciones'),
            TarjetaTranslucida(
              child: SelectableText(
                certificado.recomendaciones!,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
          if (certificado.diagnosticoVisible) ...[
            const SizedBox(height: 22),
            const EtiquetaSeccion('Diagnóstico'),
            TarjetaTranslucida(
              child: ListaDeDiagnosticos(
                diagnosticos: certificado.diagnosticos,
              ),
            ),
          ] else if (certificado.diagnosticoReservado) ...[
            const SizedBox(height: 12),
            const RecuadroAviso.informacion(
              'Diagnóstico reservado: no aparece en el certificado.',
              icono: Icons.lock_outline_rounded,
            ),
          ],
          const SizedBox(height: 22),
          const EtiquetaSeccion('Emitido por'),
          EmisorYPaciente(documento: certificado, conModalidad: false),
          if (certificado.codigoVerificacion.isNotEmpty) ...[
            const SizedBox(height: 12),
            CodigoDeVerificacion(codigo: certificado.codigoVerificacion),
          ],
        ],
      ),
    );
  }
}

/// Los días (en número y en letras), desde y hasta, el tipo, la
/// contingencia, la modalidad de la atención y a quién va dirigido.
class _Reposo extends StatelessWidget {
  final CertificadoReposo certificado;

  const _Reposo({required this.certificado});

  @override
  Widget build(BuildContext context) {
    final desde = certificado.fechaDesde;
    final hasta = certificado.fechaHasta;
    final letras = certificado.diasEnLetras;
    final modalidad = nombreDeLaModalidad(context, certificado.modalidad);
    final destinatario = certificado.destinatario;

    return TarjetaTranslucida(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                diasDeReposo(certificado.dias),
                key: const Key('dias-reposo'),
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (letras != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '($letras)',
                      style: const TextStyle(
                        color: AppColors.textoSecundario,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (certificado.tipoReposo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Pastilla(
              texto:
                  'Reposo '
                  '${nombreDelTipoDeReposo(certificado.tipoReposo).toLowerCase()}',
              color: certificado.absoluto
                  ? AppColors.acentoClaro
                  : AppColors.primarioClaro,
              icono: Icons.bed_outlined,
            ),
          ],
          const SizedBox(height: 8),
          FilaDato(
            icono: Icons.event_available_outlined,
            rotulo: 'Desde',
            valor: desde == null ? null : FormatoFecha.diaLargoConAnio(desde),
          ),
          FilaDato(
            icono: Icons.event_busy_outlined,
            rotulo: 'Hasta',
            valor: hasta == null ? null : FormatoFecha.diaLargoConAnio(hasta),
          ),
          if (certificado.contingencia.isNotEmpty)
            FilaDato(
              icono: Icons.fact_check_outlined,
              rotulo: 'Contingencia',
              valor: nombreDeLaContingencia(certificado.contingencia),
            ),
          if (modalidad != null)
            FilaDato(
              icono: Icons.medical_services_outlined,
              rotulo: 'Modalidad de la atención',
              valor: modalidad,
            ),
          if (destinatario != null)
            FilaDato(
              icono: Icons.apartment_outlined,
              rotulo: 'Dirigido a',
              valor: nombreDelDestinatario(destinatario),
            ),
        ],
      ),
    );
  }
}
