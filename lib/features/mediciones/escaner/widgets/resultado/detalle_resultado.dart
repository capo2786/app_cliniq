// lib/features/mediciones/escaner/widgets/resultado/detalle_resultado.dart

import 'package:flutter/material.dart';

import '../../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../../core/tema/tokens.dart';
import '../../../dominio/detalle_medicion.dart';
import '../../../dominio/reglas_mediciones.dart';
import 'graficas_detalle.dart';

/// «Detalle de la medición»: datos extra en tarjetas pequeñas y seis
/// gráficas, todo calculado en el teléfono con la misma serie. Cada dato
/// solo con la calidad que lo sostiene; cada gráfica, solo con datos
/// suficientes (si no, lo dice).
class DetalleDeLaMedicion extends StatelessWidget {
  final DetalleMedicion detalle;

  /// La FR del resultado salió (calidad ≥ 0,6): se dibuja la respiración.
  final bool frValida;

  const DetalleDeLaMedicion({
    super.key,
    required this.detalle,
    required this.frValida,
  });

  @override
  Widget build(BuildContext context) {
    final d = detalle;
    final m = d.metricas;
    final datos = <(String, String)>[
      if (d.calidadSuficiente) ...[
        if (m != null) ('Intervalo medio', '${m.medio.round()} ms'),
        if (d.fcMinima != null) ('FC mínima', '${d.fcMinima!.round()} lpm'),
        if (d.fcMaxima != null) ('FC máxima', '${d.fcMaxima!.round()} lpm'),
        ('Latidos detectados', '${d.latidos}'),
        if (d.vfcValida && m != null) ...[
          ('pNN50', '${numeroLegible(m.pnn50, decimales: 1)} %'),
          ('SD1', '${m.sd1.round()} ms'),
          ('SD2', '${m.sd2.round()} ms'),
        ],
      ],
      ('Duración', '${d.duracion.round()} s'),
      ('Calidad de la señal', '${(d.calidad * 100).round()} %'),
    ];

    return Column(
      key: const Key('escaner-detalle'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EtiquetaSeccion('Detalle de la medición'),
        const Text(
          'Detalle calculado en tu teléfono',
          style: TextStyle(color: AppColors.textoTenue, fontSize: 11.5),
        ),
        const SizedBox(height: 10),
        // Tres por fila (dos en pantallas muy angostas).
        LayoutBuilder(
          builder: (context, limites) {
            final porFila = limites.maxWidth < 300 ? 2 : 3;
            final ancho = (limites.maxWidth - 8 * (porFila - 1)) / porFila;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (rotulo, valor) in datos)
                  _DatoPequeno(rotulo: rotulo, valor: valor, ancho: ancho),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        GraficasDelDetalle(detalle: d, frValida: frValida),
      ],
    );
  }
}

class _DatoPequeno extends StatelessWidget {
  final String rotulo;
  final String valor;
  final double ancho;

  const _DatoPequeno({
    required this.rotulo,
    required this.valor,
    required this.ancho,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ancho,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.tarjeta,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rotulo,
            style: const TextStyle(
              color: AppColors.textoSecundario,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            valor,
            style: const TextStyle(
              color: AppColors.texto,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
