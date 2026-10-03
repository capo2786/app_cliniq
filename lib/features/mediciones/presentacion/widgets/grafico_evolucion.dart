// lib/features/mediciones/presentacion/widgets/grafico_evolucion.dart

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/fechas/instante.dart';
import '../../../../core/formato/fechas.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/medicion.dart';
import '../../dominio/rangos_referencia.dart';
import '../../dominio/reglas_mediciones.dart';
import '../../dominio/tendencias.dart';

/// La evolución de un tipo en el periodo: la línea de los valores (y la
/// diastólica en la presión), la franja verde de la referencia para
/// adultos y cada punto con su forma según de dónde salió: círculo, de un
/// aparato de casa o a mano; cuadrado, de la cámara (experimental).
/// Solo con dos puntos o más: con uno no hay evolución que ver.
class GraficoEvolucion extends StatelessWidget {
  final TendenciaDelTipo tendencia;
  final PeriodoTendencia periodo;
  final DateTime ahora;

  const GraficoEvolucion({
    super.key,
    required this.tendencia,
    required this.periodo,
    required this.ahora,
  });

  @override
  Widget build(BuildContext context) {
    final tipo = tendencia.tipo;
    final esPresion = tipo == TipoMedicion.pa;
    final desde = periodo.desde(ahora);
    double x(DateTime instante) =>
        instante.difference(desde).inMinutes / Duration.minutesPerDay;

    final puntos = tendencia.puntos;
    final principal = [for (final p in puntos) FlSpot(x(p.instante), p.valor)];
    final segunda = esPresion
        ? [
            for (final p in puntos)
              if (p.valor2 != null) FlSpot(x(p.instante), p.valor2!),
          ]
        : const <FlSpot>[];
    final camara = [for (final p in puntos) p.deCamara];
    final camara2 = [
      for (final p in puntos)
        if (p.valor2 != null) p.deCamara,
    ];

    final franjas = [
      ?referenciaDelTipo(tipo),
      if (esPresion) referenciaDiastolica,
    ];
    final valores = [
      ...principal.map((p) => p.y),
      ...segunda.map((p) => p.y),
      for (final f in franjas) ...[f.minimo.toDouble(), f.maximo.toDouble()],
    ];
    final minimo = valores.reduce(math.min);
    final maximo = valores.reduce(math.max);
    final margen = math.max((maximo - minimo) * 0.12, tipo.margenMinimo);

    LineChartBarData linea(
      List<FlSpot> spots,
      List<bool> deCamara,
      Color color,
    ) => LineChartBarData(
      spots: spots,
      color: color,
      barWidth: 2.4,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, _, _, indice) =>
            indice < deCamara.length && deCamara[indice]
            ? FlDotSquarePainter(size: 8, color: color, strokeWidth: 0)
            : FlDotCirclePainter(radius: 3.6, color: color, strokeWidth: 0),
      ),
    );

    return Semantics(
      label:
          '${nombreDelTipo(tipo)}: ${puntos.length} mediciones en '
          '${periodo.nombre}; la última, ${valorDeMedicion(tendencia.ultima)}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: periodo.dias.toDouble(),
                minY: (minimo - margen).floorToDouble(),
                maxY: (maximo + margen).ceilToDouble(),
                lineTouchData: const LineTouchData(enabled: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.bordeCampo, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                rangeAnnotations: RangeAnnotations(
                  horizontalRangeAnnotations: [
                    for (final f in franjas)
                      HorizontalRangeAnnotation(
                        y1: f.minimo.toDouble(),
                        y2: f.maximo.toDouble(),
                        color: AppColors.exito.withValues(alpha: 0.12),
                      ),
                  ],
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (valor, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          numeroLegible(valor),
                          style: const TextStyle(
                            color: AppColors.textoTenue,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                lineBarsData: [
                  linea(
                    principal,
                    camara,
                    esPresion ? AppColors.acentoClaro : AppColors.celeste,
                  ),
                  if (segunda.length >= 2)
                    linea(segunda, camara2, AppColors.violeta),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                FormatoFecha.diaYMesCorto(enHoraDeLaClinica(desde)),
                style: const TextStyle(
                  color: AppColors.textoTenue,
                  fontSize: 11,
                ),
              ),
              const Text(
                'Hoy',
                style: TextStyle(color: AppColors.textoTenue, fontSize: 11),
              ),
            ],
          ),
          if (franjas.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              esPresion
                  ? '${leyendaDeReferencia(tipo)}: arriba la sistólica, abajo '
                        'la diastólica'
                  : leyendaDeReferencia(tipo),
              style: const TextStyle(color: AppColors.textoTenue, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

extension on TipoMedicion {
  /// El margen mínimo arriba y abajo de la gráfica, en las unidades del
  /// tipo.
  double get margenMinimo => switch (this) {
    TipoMedicion.temp => 0.3,
    TipoMedicion.peso => 1,
    _ => 4,
  };
}

/// La leyenda de las formas: de dónde salió cada punto.
class LeyendaDeOrigen extends StatelessWidget {
  const LeyendaDeOrigen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(Widget forma, String texto) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        forma,
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 12,
          ),
        ),
      ],
    );
    return Wrap(
      key: const Key('tendencias-leyenda'),
      spacing: 16,
      runSpacing: 6,
      children: [
        item(
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.textoSuave,
              shape: BoxShape.circle,
            ),
          ),
          'Aparato de casa o a mano',
        ),
        item(
          Container(width: 8, height: 8, color: AppColors.textoSuave),
          'Cámara (experimental)',
        ),
      ],
    );
  }
}
