// lib/features/mediciones/presentacion/widgets/grafico_evolucion.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/fechas/instante.dart';
import '../../../../core/formato/fechas.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/medicion.dart';
import '../../dominio/reglas_mediciones.dart';

/// Hasta cuántos puntos se dibujan (los más recientes).
const int puntosDelGrafico = 30;

/// Las mediciones de un tipo para el gráfico: de la más antigua a la más
/// reciente, las últimas [puntosDelGrafico].
List<Medicion> serieDelTipo(List<Medicion> mediciones, TipoMedicion tipo) {
  final deTipo = [
    for (final m in mediciones)
      if (m.tipo == tipo) m,
  ]..sort((a, b) => a.medidoEn.compareTo(b.medidoEn));
  return deTipo.length > puntosDelGrafico
      ? deTipo.sublist(deTipo.length - puntosDelGrafico)
      : deTipo;
}

/// Un gráfico simple de la evolución de la FC o de la PA (sistólica y
/// diastólica), con la primera y la última fecha. Solo con dos puntos o
/// más: con uno no hay evolución que ver.
class GraficoEvolucion extends StatelessWidget {
  final TipoMedicion tipo;
  final List<Medicion> serie;

  const GraficoEvolucion({super.key, required this.tipo, required this.serie});

  @override
  Widget build(BuildContext context) {
    final esPresion = tipo == TipoMedicion.pa;
    final principal = [
      for (final (i, m) in serie.indexed)
        FlSpot(i.toDouble(), m.valor.toDouble()),
    ];
    final diastolica = esPresion
        ? [
            for (final (i, m) in serie.indexed)
              if (m.valor2 != null) FlSpot(i.toDouble(), m.valor2!.toDouble()),
          ]
        : const <FlSpot>[];

    final valores = [...principal, ...diastolica].map((p) => p.y);
    final minimo = valores.reduce((a, b) => a < b ? a : b);
    final maximo = valores.reduce((a, b) => a > b ? a : b);
    final margen = ((maximo - minimo) * 0.15).clamp(4, 30).toDouble();

    final primera = FormatoFecha.diaYMesCorto(
      enHoraDeLaClinica(serie.first.medidoEn),
    );
    final ultima = FormatoFecha.diaYMesCorto(
      enHoraDeLaClinica(serie.last.medidoEn),
    );
    final ultimoValor = valorDeMedicion(serie.last);

    LineChartBarData linea(List<FlSpot> puntos, Color color) =>
        LineChartBarData(
          spots: puntos,
          color: color,
          barWidth: 2.6,
          isCurved: false,
          isStrokeCapRound: true,
          dotData: FlDotData(show: puntos.length <= 12),
        );

    return Semantics(
      label:
          '${nombreDelTipo(tipo)}: ${serie.length} mediciones del $primera al '
          '$ultima; la última, $ultimoValor',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nombreDelTipo(tipo),
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                'Última: $ultimoValor',
                style: const TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          if (esPresion)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Arriba la sistólica (la alta), abajo la diastólica (la baja)',
                style: TextStyle(color: AppColors.textoTenue, fontSize: 11.5),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                minY: (minimo - margen).floorToDouble(),
                maxY: (maximo + margen).ceilToDouble(),
                lineTouchData: const LineTouchData(enabled: false),
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.bordeCampo, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
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
                          valor.round().toString(),
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
                    esPresion ? AppColors.acentoClaro : AppColors.celeste,
                  ),
                  if (diastolica.length >= 2)
                    linea(diastolica, AppColors.violeta),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                primera,
                style: const TextStyle(
                  color: AppColors.textoTenue,
                  fontSize: 11,
                ),
              ),
              Text(
                ultima,
                style: const TextStyle(
                  color: AppColors.textoTenue,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
