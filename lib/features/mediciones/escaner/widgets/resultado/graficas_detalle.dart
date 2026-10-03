// lib/features/mediciones/escaner/widgets/resultado/graficas_detalle.dart

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/tema/tokens.dart';
import '../../../data/models/medicion.dart';
import '../../../dominio/detalle_medicion.dart';
import '../../../dominio/rangos_referencia.dart';
import '../dibujos_escaner.dart';
import '../../../presentacion/widgets/ejes_graficas.dart';

/// El mensaje de una gráfica sin datos suficientes.
const String sinSenalParaGrafica = 'No hay suficiente señal para esta gráfica';

/// Las seis gráficas del detalle, en tarjetas una debajo de otra, cada una
/// con una línea sencilla que explica qué muestra.
class GraficasDelDetalle extends StatelessWidget {
  final DetalleMedicion detalle;
  final bool frValida;

  const GraficasDelDetalle({
    super.key,
    required this.detalle,
    required this.frValida,
  });

  @override
  Widget build(BuildContext context) {
    final d = detalle;
    final m = d.metricas;
    return Column(
      children: [
        _Tarjeta(
          titulo: 'Onda del pulso',
          explicacion:
              'La señal de tu pulso en los últimos 10 segundos. Cada punto '
              'blanco es un latido detectado.',
          grafica: d.onda.length >= 3 * d.fs && d.latidosEnOnda.length >= 2
              ? OndaEnVivo(
                  key: const Key('grafica-onda'),
                  onda: d.onda,
                  latidos: d.latidosEnOnda,
                  color: AppColors.acentoClaro,
                  alto: 110,
                )
              : null,
        ),
        _Tarjeta(
          titulo: 'Frecuencia cardiaca durante la medición',
          explicacion:
              'Tu pulso estimado segundo a segundo. La franja verde es el '
              'rango de 60 a 100 lpm.',
          referencia: leyendaDeReferencia(TipoMedicion.fc),
          grafica: d.fcPorSegundo.length >= 3
              ? _lineas(
                  key: const Key('grafica-fc'),
                  puntos: [
                    for (final p in d.fcPorSegundo) FlSpot(p.segundo, p.fc),
                  ],
                  color: AppColors.peligroSuave,
                  franja: referenciaDelTipo(TipoMedicion.fc),
                  ejeX: 's',
                )
              : null,
        ),
        _Tarjeta(
          titulo: 'Intervalos entre latidos',
          explicacion:
              'Cuánto tiempo pasó entre un latido y el siguiente, en '
              'milisegundos. Es normal que cambie un poco.',
          grafica: d.calidadSuficiente && d.intervalos.length >= 5
              ? _barras(d)
              : null,
        ),
        _Tarjeta(
          titulo: 'Poincaré',
          explicacion:
              'Cada punto compara un intervalo con el siguiente. SD1 mide la '
              'variación de latido a latido; SD2, la variación lenta.',
          pie: d.vfcValida && m != null
              ? 'SD1 ${m.sd1.round()} ms · SD2 ${m.sd2.round()} ms'
              : null,
          grafica: d.vfcValida ? _poincare(d) : null,
        ),
        _Tarjeta(
          titulo: 'Espectro de frecuencias',
          explicacion:
              'Cuánta fuerza tiene la señal en cada ritmo posible. El pico '
              'marcado es tu frecuencia cardiaca: así la calcula el escáner.',
          grafica: d.espectro.length >= 10 && d.picoLpm != null
              ? _lineas(
                  key: const Key('grafica-espectro'),
                  puntos: [
                    for (final p in d.espectro) FlSpot(p.lpm, p.potencia),
                  ],
                  color: AppColors.violeta,
                  area: true,
                  marca: d.picoLpm,
                  ejeX: 'lpm',
                  sinEjeY: true,
                )
              : null,
        ),
        _Tarjeta(
          titulo: 'Respiración',
          explicacion:
              'La onda lenta que la respiración deja en la señal. Cada '
              'subida y bajada es más o menos una respiración.',
          grafica: frValida && d.respiracion.length >= 15 * d.fsRespiracion
              ? _lineas(
                  key: const Key('grafica-respiracion'),
                  puntos: [
                    for (final (i, v) in d.respiracion.indexed)
                      FlSpot(i / d.fsRespiracion, v),
                  ],
                  color: AppColors.celeste,
                  ejeX: 's',
                  sinEjeY: true,
                )
              : null,
        ),
      ],
    );
  }

  static Widget _lineas({
    required Key key,
    required List<FlSpot> puntos,
    required Color color,
    required String ejeX,
    RangoReferencia? franja,
    bool area = false,
    double? marca,
    bool sinEjeY = false,
  }) {
    final ys = puntos.map((p) => p.y);
    var minY = ys.reduce(math.min);
    var maxY = ys.reduce(math.max);
    if (franja != null) {
      minY = math.min(minY, franja.minimo.toDouble());
      maxY = math.max(maxY, franja.maximo.toDouble());
    }
    final margen = math.max((maxY - minY) * 0.1, franja == null ? 0.05 : 4);
    return SizedBox(
      key: key,
      height: 150,
      child: LineChart(
        LineChartData(
          minY: minY - margen,
          maxY: maxY + margen,
          lineTouchData: const LineTouchData(enabled: false),
          gridData: rejillaDeGraficas,
          borderData: FlBorderData(show: false),
          titlesData: titulosDeEjes(
            rangoX: puntos.last.x - puntos.first.x,
            rangoY: maxY - minY,
            unidadX: ejeX,
            sinEjeY: sinEjeY,
          ),
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              if (franja != null)
                HorizontalRangeAnnotation(
                  y1: franja.minimo.toDouble(),
                  y2: franja.maximo.toDouble(),
                  color: AppColors.exito.withValues(alpha: 0.12),
                ),
            ],
          ),
          extraLinesData: ExtraLinesData(
            verticalLines: [
              if (marca != null)
                VerticalLine(
                  x: marca,
                  color: AppColors.texto.withValues(alpha: 0.8),
                  strokeWidth: 1.5,
                  dashArray: const [4, 3],
                  label: VerticalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                    labelResolver: (_) => '${marca.round()} lpm',
                  ),
                ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: puntos,
              color: color,
              barWidth: 2.2,
              isCurved: false,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: area,
                color: color.withValues(alpha: 0.18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _barras(DetalleMedicion d) {
    final ms = d.intervalos.map((i) => i.ms);
    final minimo = ms.reduce(math.min);
    final maximo = ms.reduce(math.max);
    return SizedBox(
      key: const Key('grafica-intervalos'),
      height: 150,
      child: BarChart(
        BarChartData(
          minY: math.max(0, minimo - 80),
          maxY: maximo + 40,
          barTouchData: BarTouchData(enabled: false),
          gridData: rejillaDeGraficas,
          borderData: FlBorderData(show: false),
          titlesData: titulosDeEjes(
            rangoX: d.intervalos.length.toDouble(),
            rangoY: maximo - minimo,
            unidadX: '',
          ),
          barGroups: [
            for (final (i, intervalo) in d.intervalos.indexed)
              BarChartGroupData(
                x: i + 1,
                barRods: [
                  BarChartRodData(
                    toY: intervalo.ms,
                    width: math.max(2, 220 / d.intervalos.length),
                    color: AppColors.acentoClaro,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static Widget _poincare(DetalleMedicion d) {
    final rr = d.intervalos.map((i) => i.ms).toList();
    final minimo = rr.reduce(math.min) - 40;
    final maximo = rr.reduce(math.max) + 40;
    return SizedBox(
      key: const Key('grafica-poincare'),
      height: 200,
      child: ScatterChart(
        ScatterChartData(
          minX: minimo,
          maxX: maximo,
          minY: minimo,
          maxY: maximo,
          scatterTouchData: ScatterTouchData(enabled: false),
          gridData: rejillaDeGraficas,
          borderData: FlBorderData(show: false),
          titlesData: titulosDeEjes(
            rangoX: maximo - minimo,
            rangoY: maximo - minimo,
            unidadX: 'ms',
          ),
          scatterSpots: [
            for (var i = 1; i < rr.length; i++)
              ScatterSpot(
                rr[i - 1],
                rr[i],
                dotPainter: FlDotCirclePainter(
                  radius: 3.5,
                  color: AppColors.violeta.withValues(alpha: 0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  final String titulo;
  final String explicacion;
  final Widget? grafica;
  final String? referencia;
  final String? pie;

  const _Tarjeta({
    required this.titulo,
    required this.explicacion,
    required this.grafica,
    this.referencia,
    this.pie,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: AppColors.tarjeta,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            color: AppColors.texto,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          explicacion,
          style: const TextStyle(
            color: AppColors.textoSecundario,
            fontSize: 12,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 10),
        grafica ??
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text(
                  sinSenalParaGrafica,
                  key: Key('grafica-sin-datos'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textoTenue, fontSize: 12.5),
                ),
              ),
            ),
        if (grafica != null && (referencia ?? pie) != null) ...[
          const SizedBox(height: 6),
          Text(
            [?pie, ?referencia].join(' · '),
            style: const TextStyle(color: AppColors.textoTenue, fontSize: 11),
          ),
        ],
      ],
    ),
  );
}
