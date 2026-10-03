// lib/features/mediciones/escaner/widgets/resultado/tarjetas_resultado.dart

import 'package:flutter/material.dart';

import '../../../../../core/tema/tokens.dart';
import '../../../data/models/medicion.dart';
import '../../../dominio/rangos_referencia.dart';
import '../../../dominio/reglas_mediciones.dart';
import '../../motor_signos_camara.dart';
import '../pasos_comunes.dart';

/// Los valores del resultado en tarjetas de dos columnas, que entran una
/// tras otra y con los números subiendo: la FC con su rango, la FR y la
/// variabilidad si vienen, y la calidad. Solo lo que la cámara mide.
class TarjetasResultado extends StatelessWidget {
  final ResultadoEscaner resultado;

  const TarjetasResultado({super.key, required this.resultado});

  @override
  Widget build(BuildContext context) {
    final r = resultado;
    final vfc = r.vfc;
    final tarjetas = <Widget>[
      _TarjetaValor(
        key: const Key('escaner-tarjeta-fc'),
        icono: Icons.favorite_rounded,
        color: AppColors.peligroSuave,
        titulo: 'Frecuencia cardiaca',
        valor: r.fc!,
        valorKey: const Key('escaner-fc'),
        unidad: 'lpm',
        rango: etiquetaDeRango(TipoMedicion.fc, r.fc!),
      ),
      if (r.fr != null)
        _TarjetaValor(
          key: const Key('escaner-fr'),
          icono: Icons.air_rounded,
          color: AppColors.celeste,
          titulo: 'Respiración (aproximada)',
          valor: r.fr!,
          unidad: 'rpm',
          rango: etiquetaDeRango(TipoMedicion.fr, r.fr!),
        ),
      if (vfc != null) ...[
        _TarjetaValor(
          key: const Key('escaner-vfc'),
          icono: Icons.show_chart_rounded,
          color: AppColors.violeta,
          titulo: 'Variabilidad (SDNN)',
          valor: vfc.sdnn.round(),
          unidad: 'ms',
        ),
        _TarjetaValor(
          icono: Icons.timeline_rounded,
          color: AppColors.violeta,
          titulo: 'Variabilidad (RMSSD)',
          valor: vfc.rmssd.round(),
          unidad: 'ms',
        ),
      ],
      _TarjetaCalidad(calidad: r.calidad),
    ];

    final filas = <Widget>[];
    for (var i = 0; i < tarjetas.length; i += 2) {
      filas.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Entrada(orden: i, child: tarjetas[i]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: i + 1 < tarjetas.length
                    ? _Entrada(orden: i + 1, child: tarjetas[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      key: const Key('escaner-tarjetas'),
      children: [
        for (final (i, fila) in filas.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          fila,
        ],
      ],
    );
  }
}

/// La entrada escalonada: aparece y sube un poco, cada tarjeta un poco
/// después de la anterior.
class _Entrada extends StatelessWidget {
  final int orden;
  final Widget child;

  const _Entrada({required this.orden, required this.child});

  @override
  Widget build(BuildContext context) {
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: sinAnimaciones
          ? Duration.zero
          : Duration(milliseconds: 380 + 90 * orden),
      curve: Interval(
        sinAnimaciones ? 0 : (90 * orden) / (380 + 90 * orden),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, hijo) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: hijo,
        ),
      ),
      child: child,
    );
  }
}

class _Caja extends StatelessWidget {
  final Color color;
  final Widget child;

  const _Caja({required this.color, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.tarjeta,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: child,
  );
}

class _TarjetaValor extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final int valor;
  final Key? valorKey;
  final String unidad;
  final String? rango;

  const _TarjetaValor({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.valor,
    required this.unidad,
    this.valorKey,
    this.rango,
  });

  @override
  Widget build(BuildContext context) {
    final sinAnimaciones = MediaQuery.disableAnimationsOf(context);
    final enRango = rango?.startsWith('En rango') ?? false;
    return _Caja(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: valor.toDouble()),
                  duration: sinAnimaciones
                      ? Duration.zero
                      : const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text(
                    '${v.round()}',
                    key: valorKey,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unidad,
                  style: const TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (rango != null) ...[
            const SizedBox(height: 6),
            Text(
              rango!,
              style: TextStyle(
                color: enRango ? AppColors.exito : AppColors.alerta,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaCalidad extends StatelessWidget {
  final double calidad;

  const _TarjetaCalidad({required this.calidad});

  @override
  Widget build(BuildContext context) {
    final color = colorDeCalidad(calidad);
    return _Caja(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.signal_cellular_alt_rounded, color: color, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Calidad de la señal',
                  style: TextStyle(
                    color: AppColors.textoSuave,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            key: const Key('escaner-nivel'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              nombreDelNivel(nivelDeCalidad(calidad)),
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La tarjeta honesta: la presión y la saturación no se miden con la
/// cámara; se registran con los aparatos de casa.
class TarjetaRegistrarAparatos extends StatelessWidget {
  final VoidCallback alRegistrar;

  const TarjetaRegistrarAparatos({super.key, required this.alRegistrar});

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.tarjeta,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      key: const Key('escaner-tarjeta-honesta'),
      borderRadius: BorderRadius.circular(16),
      onTap: alRegistrar,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.monitor_heart_outlined,
              color: AppColors.primarioClaro,
              size: 26,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Presión y saturación: regístralas con tu tensiómetro u '
                'oxímetro',
                style: TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Registrar',
              style: TextStyle(
                color: AppColors.acentoClaro,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.acentoClaro),
          ],
        ),
      ),
    ),
  );
}
