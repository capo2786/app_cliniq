// lib/features/mi_salud/presentacion/widgets/partes_documento.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/avisos.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/mi_salud.dart';
import '../../dominio/reglas_mi_salud.dart';

/// Un bloque de texto con su rótulo pequeño en mayúsculas: «Indicaciones»,
/// «Recomendaciones».
class BloqueDeTexto extends StatelessWidget {
  final String rotulo;
  final String texto;

  const BloqueDeTexto({super.key, required this.rotulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RotuloPequeno(rotulo),
          const SizedBox(height: 4),
          SelectableText(
            texto,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// El rótulo de un dato dentro de una tarjeta, en mayúsculas y tenue.
class RotuloPequeno extends StatelessWidget {
  final String texto;

  const RotuloPequeno(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textoSecundario,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    );
  }
}

/// Los diagnósticos, uno por línea: «Amigdalitis aguda (J03.9)» y, si el
/// médico no lo confirmó, «· por confirmar».
class ListaDeDiagnosticos extends StatelessWidget {
  final List<DiagnosticoClinico> diagnosticos;

  const ListaDeDiagnosticos({super.key, required this.diagnosticos});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in diagnosticos)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Icon(
                    d.principal
                        ? Icons.label_important_outline_rounded
                        : Icons.label_outline_rounded,
                    size: 15,
                    color: AppColors.primarioClaro,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: d.descripcion),
                        if (d.codigo.isNotEmpty && d.codigo != d.descripcion)
                          TextSpan(
                            text: '  (${d.codigo})',
                            style: const TextStyle(
                              color: AppColors.textoTenue,
                              fontSize: 12,
                            ),
                          ),
                        if (d.porConfirmar)
                          const TextSpan(
                            text: ' · por confirmar',
                            style: TextStyle(
                              color: AppColors.alertaTexto,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// La cabecera de una receta, una orden o un certificado: qué es, cuándo y
/// si está anulado.
class EncabezadoDeDocumento extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final DocumentoClinico documento;

  /// Algo más bajo la fecha: «Urgente».
  final List<Widget> pastillas;

  /// «Emitido», «Anulado»: un certificado; la receta y la orden, en
  /// femenino.
  final bool masculino;

  const EncabezadoDeDocumento({
    super.key,
    required this.icono,
    required this.titulo,
    required this.documento,
    this.pastillas = const [],
    this.masculino = false,
  });

  @override
  Widget build(BuildContext context) {
    final fecha = documento.fecha;
    final emitido = masculino ? 'Emitido' : 'Emitida';

    return TarjetaEncabezado(
      icono: icono,
      titulo: titulo,
      descripcion: fecha == null
          ? '$emitido por ${documento.medicoNombre}'
          : '$emitido el ${FormatoFecha.diaLargoConAnio(fecha).toLowerCase()}',
      accesorio: documento.anulada || pastillas.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (documento.anulada)
                  Pastilla(
                    texto: masculino ? 'Anulado' : 'Anulada',
                    color: AppColors.peligroSuave,
                    icono: Icons.block_rounded,
                  ),
                ...pastillas,
              ],
            )
          : null,
    );
  }
}

/// «Firmado electrónicamente por … el …»: el sello de un documento que el
/// médico firmó, con la entidad que emitió su certificado.
class SelloDeFirma extends StatelessWidget {
  final FirmaElectronica? firma;

  const SelloDeFirma({super.key, required this.firma});

  @override
  Widget build(BuildContext context) {
    final emisor = firma?.emisor;

    return Container(
      key: const Key('sello-firma'),
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.exito.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.exito.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_rounded, color: AppColors.exito, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  textoDeLaFirma(firma),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
                if (emisor != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Emisor del certificado: $emisor',
                    style: const TextStyle(
                      color: AppColors.textoSecundario,
                      fontSize: 12,
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

/// Quién emitió el documento y para quién.
class EmisorYPaciente extends StatelessWidget {
  final DocumentoClinico documento;

  const EmisorYPaciente({super.key, required this.documento});

  @override
  Widget build(BuildContext context) {
    final edad = documento.pacienteEdad;

    return TarjetaTranslucida(
      child: Column(
        children: [
          FilaDato(
            icono: Icons.medical_information_outlined,
            rotulo: 'Médico',
            valor: [
              documento.medicoNombre,
              ?documento.medicoEspecialidad,
            ].where((p) => p.isNotEmpty).join(' · '),
          ),
          if (documento.medicoRegistro != null)
            FilaDato(
              icono: Icons.verified_outlined,
              rotulo: 'Registro profesional',
              valor: documento.medicoRegistro,
            ),
          FilaDato(
            icono: Icons.person_outline_rounded,
            rotulo: 'Paciente',
            valor: [
              documento.pacienteNombre,
              if (edad != null) '$edad años',
            ].where((p) => p.isNotEmpty).join(' · '),
          ),
          if (documento.pacienteCedula != null)
            FilaDato(
              icono: Icons.badge_outlined,
              rotulo: 'Documento de identidad',
              valor: documento.pacienteCedula,
            ),
        ],
      ),
    );
  }
}

/// El código con que se comprueba el documento, para dictarlo o copiarlo.
class CodigoDeVerificacion extends StatelessWidget {
  final String codigo;

  const CodigoDeVerificacion({super.key, required this.codigo});

  @override
  Widget build(BuildContext context) {
    return TarjetaTranslucida(
      child: Row(
        children: [
          Icon(Icons.qr_code_2_rounded, color: AppColors.primarioClaro),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Código de verificación',
                  style: TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  codigo,
                  key: const Key('codigo-verificacion'),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Con este código se comprueba que el documento es auténtico.',
                  style: TextStyle(color: AppColors.textoTenue, fontSize: 11.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar el código',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: codigo));
              if (context.mounted) mostrarAviso(context, 'Código copiado.');
            },
            icon: Icon(Icons.copy_rounded, color: AppColors.primarioClaro),
          ),
        ],
      ),
    );
  }
}
