// lib/features/mediciones/escaner/widgets/midiendo/panel_en_vivo.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/presentacion/widgets/botones.dart';
import '../../../../../core/tema/tokens.dart';
import '../../../dominio/procesamiento_ppg.dart';
import '../../escaner_state.dart';
import '../dibujos_escaner.dart';
import 'mosaicos_en_vivo.dart';

/// La línea de privacidad de la pantalla de medición.
const String lineaDePrivacidadVideo =
    'El video se analiza en tu teléfono y nunca se guarda ni se envía';

/// «Preparando…», «Tomando la medición… 18 s» o «En pausa · 18 s».
String textoDeAvance(EscanerState state) => switch (state.fase) {
  FaseMedicion.preparando => 'Preparando…',
  FaseMedicion.midiendo => 'Tomando la medición… ${state.segundosRestantes} s',
  FaseMedicion.pausada => 'En pausa · ${state.segundosRestantes} s',
};

/// El panel oscuro y translúcido de abajo mientras se mide: los mosaicos,
/// la onda con sus latidos, la mini gráfica de la FC, los latidos
/// detectados, el avance, «Cancelar» y la línea de privacidad.
class PanelEnVivo extends StatelessWidget {
  final EscanerState state;
  final VoidCallback alCancelar;

  const PanelEnVivo({super.key, required this.state, required this.alCancelar});

  @override
  Widget build(BuildContext context) {
    final lectura = state.lectura;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.fondoProfundo.withValues(alpha: 0.78),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: AppColors.veloClaro)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MosaicosEnVivo(lectura: lectura),
              const SizedBox(height: 8),
              OndaEnVivo(
                key: const Key('escaner-onda'),
                onda: lectura.onda,
                latidos: lectura.latidosEnOnda,
                color: AppColors.acentoClaro,
                alto: 58,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: state.historialFc.length >= 2
                        ? MiniGraficaFc(
                            key: const Key('escaner-mini-fc'),
                            historial: state.historialFc,
                          )
                        : const Text(
                            'La línea de tu pulso aparece cuando la señal '
                            'es buena.',
                            style: TextStyle(
                              color: AppColors.textoTenue,
                              fontSize: 11,
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Latidos detectados: ${state.latidos}',
                    key: const Key('escaner-latidos'),
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                textoDeAvance(state),
                key: const Key('escaner-cuenta'),
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    end: state.fase == FaseMedicion.preparando
                        ? 0
                        : state.avance,
                  ),
                  duration: const Duration(milliseconds: 400),
                  builder: (context, valor, _) => LinearProgressIndicator(
                    value: valor,
                    minHeight: 6,
                    color: state.fase == FaseMedicion.pausada
                        ? AppColors.alerta
                        : AppColors.exito,
                    backgroundColor: AppColors.bordeCampo,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              BotonSecundario(
                key: const Key('escaner-cancelar'),
                texto: 'Cancelar',
                icono: Icons.stop_rounded,
                color: AppColors.peligroSuave,
                onPressed: alCancelar,
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.textoTenue,
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      lineaDePrivacidadVideo,
                      key: Key('escaner-privacidad'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textoTenue,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La FC en vivo de cada segundo, como una línea pequeña con el último
/// valor marcado.
class MiniGraficaFc extends StatelessWidget {
  final List<PuntoFc> historial;

  const MiniGraficaFc({super.key, required this.historial});

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Tu pulso en vivo: de ${historial.first.fc.round()} a '
        '${historial.last.fc.round()} latidos por minuto',
    child: SizedBox(
      height: 30,
      child: CustomPaint(
        size: Size.infinite,
        painter: _PintorMiniFc(historial),
      ),
    ),
  );
}

class _PintorMiniFc extends CustomPainter {
  final List<PuntoFc> historial;

  _PintorMiniFc(this.historial);

  @override
  void paint(Canvas canvas, Size size) {
    if (historial.length < 2) return;
    final t0 = historial.first.segundo;
    final t1 = math.max(historial.last.segundo, t0 + 1);
    final minimo = historial.map((p) => p.fc).reduce(math.min) - 4;
    final maximo = historial.map((p) => p.fc).reduce(math.max) + 4;
    Offset punto(PuntoFc p) => Offset(
      size.width * (p.segundo - t0) / (t1 - t0),
      size.height * (1 - (p.fc - minimo) / (maximo - minimo)),
    );

    final linea = Path()
      ..moveTo(punto(historial.first).dx, punto(historial.first).dy);
    for (final p in historial.skip(1)) {
      linea.lineTo(punto(p).dx, punto(p).dy);
    }
    canvas.drawPath(
      linea,
      Paint()
        ..color = AppColors.peligroSuave
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(
      punto(historial.last),
      3.2,
      Paint()..color = AppColors.texto,
    );
  }

  @override
  bool shouldRepaint(covariant _PintorMiniFc antes) =>
      !identical(antes.historial, historial);
}
