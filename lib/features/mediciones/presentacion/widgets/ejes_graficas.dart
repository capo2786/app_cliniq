// lib/features/mediciones/presentacion/widgets/ejes_graficas.dart

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/tema/tokens.dart';

/// Un paso «redondo» (1, 2 o 5 por una potencia de diez) para unas
/// [marcas] en un [rango].
double intervaloRedondo(double rango, {int marcas = 4}) {
  if (rango <= 0 || !rango.isFinite) return 1;
  final crudo = rango / marcas;
  final potencia = math
      .pow(10, (math.log(crudo) / math.ln10).floor())
      .toDouble();
  final base = crudo / potencia;
  final redondo = base < 1.5
      ? 1
      : base < 3
      ? 2
      : base < 7
      ? 5
      : 10;
  return redondo * potencia;
}

/// Un rótulo de eje solo si cae en el paso: fl_chart dibuja también el
/// mínimo y el máximo, que si no son redondos se enciman con los demás.
Widget rotuloDeEje(
  double valor,
  TitleMeta meta, {
  String unidad = '',
  String Function(double)? formato,
}) {
  final pasos = valor / meta.appliedInterval;
  if ((pasos - pasos.round()).abs() > 1e-6) return const SizedBox.shrink();
  final numero = formato?.call(valor) ?? '${valor.round()}';
  return SideTitleWidget(
    meta: meta,
    child: Text(
      unidad.isEmpty ? numero : '$numero $unidad',
      style: const TextStyle(color: AppColors.textoTenue, fontSize: 10),
    ),
  );
}

/// Los rótulos de los ejes de las gráficas del detalle: pocos y redondos.
FlTitlesData titulosDeEjes({
  required double rangoX,
  required double rangoY,
  required String unidadX,
  bool sinEjeY = false,
}) {
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: !sinEjeY,
        reservedSize: 34,
        interval: intervaloRedondo(rangoY, marcas: 3),
        getTitlesWidget: (v, meta) => rotuloDeEje(v, meta),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 22,
        interval: intervaloRedondo(rangoX),
        getTitlesWidget: (v, meta) => rotuloDeEje(v, meta, unidad: unidadX),
      ),
    ),
  );
}

/// La rejilla horizontal, tenue.
FlGridData get rejillaDeGraficas => FlGridData(
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) =>
      const FlLine(color: AppColors.bordeCampo, strokeWidth: 1),
);
