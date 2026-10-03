// lib/features/mediciones/escaner/widgets/midiendo/mosaicos_en_vivo.dart

import 'package:flutter/material.dart';

import '../../../../../core/tema/tokens.dart';
import '../../../dominio/reglas_mediciones.dart';
import '../../motor_signos_camara.dart';
import '../pasos_comunes.dart';

/// Los tres mosaicos del panel mientras se mide: la FC en vivo, la
/// respiración (que solo se sabe al final) y la calidad de la señal.
class MosaicosEnVivo extends StatelessWidget {
  final LecturaEnVivo lectura;

  const MosaicosEnVivo({super.key, required this.lectura});

  @override
  Widget build(BuildContext context) {
    final fc = lectura.fcVisible ? lectura.fc!.round() : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _Mosaico(
            icono: Icons.favorite_rounded,
            color: AppColors.peligroSuave,
            titulo: 'Frecuencia cardiaca',
            valor: fc?.toString(),
            valorKey: const Key('escaner-fc-vivo'),
            unidad: 'lpm',
            etiqueta: fc == null ? null : 'en vivo',
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(
          child: _Mosaico(
            icono: Icons.air_rounded,
            color: AppColors.celeste,
            titulo: 'Respiración',
            unidad: 'rpm',
            pie: 'Al terminar',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: _MosaicoCalidad(calidad: lectura.calidad)),
      ],
    );
  }
}

class _Mosaico extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String? valor;
  final Key? valorKey;
  final String unidad;
  final String? etiqueta;
  final String? pie;

  const _Mosaico({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.unidad,
    this.valor,
    this.valorKey,
    this.etiqueta,
    this.pie,
  });

  @override
  Widget build(BuildContext context) {
    return _Caja(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Encabezado(icono: icono, color: color, titulo: titulo),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: valor == null
                ? const _Pendiente(key: ValueKey('pendiente'))
                : Row(
                    key: ValueKey(valor),
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        valor!,
                        key: valorKey,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        unidad,
                        style: const TextStyle(
                          color: AppColors.textoSecundario,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 2),
          if (etiqueta != null)
            Text(
              etiqueta!,
              style: const TextStyle(
                color: AppColors.exito,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            Text(
              pie ?? 'Calculando…',
              style: const TextStyle(color: AppColors.textoTenue, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

/// La calidad: una barra que se llena y su nombre.
class _MosaicoCalidad extends StatelessWidget {
  final double? calidad;

  const _MosaicoCalidad({required this.calidad});

  @override
  Widget build(BuildContext context) {
    final c = calidad;
    final color = colorDeCalidad(c);
    final nombre = c == null
        ? 'Midiendo…'
        : switch (nivelDeCalidad(c)) {
            NivelCalidad.buena => 'Buena',
            NivelCalidad.regular => 'Regular',
            NivelCalidad.baja => 'Baja',
          };
    return _Caja(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Encabezado(
            icono: Icons.signal_cellular_alt_rounded,
            color: color,
            titulo: 'Calidad de señal',
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (c ?? 0).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 500),
              builder: (context, valor, _) => LinearProgressIndicator(
                value: valor,
                minHeight: 7,
                color: color,
                backgroundColor: AppColors.bordeCampo,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nombre,
            key: const Key('escaner-calidad'),
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Caja extends StatelessWidget {
  final Widget child;

  const _Caja({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
    decoration: BoxDecoration(
      color: AppColors.veloClaro.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.veloClaro),
    ),
    child: child,
  );
}

class _Encabezado extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;

  const _Encabezado({
    required this.icono,
    required this.color,
    required this.titulo,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icono, color: color, size: 14),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          titulo,
          maxLines: 2,
          style: const TextStyle(
            color: AppColors.textoSuave,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
      ),
    ],
  );
}

/// «—» con un brillo que pasa, mientras no hay valor.
class _Pendiente extends StatefulWidget {
  const _Pendiente({super.key});

  @override
  State<_Pendiente> createState() => _PendienteState();
}

class _PendienteState extends State<_Pendiente>
    with SingleTickerProviderStateMixin {
  late final AnimationController _brillo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _brillo.stop();
    } else if (!_brillo.isAnimating) {
      _brillo.repeat();
    }
  }

  @override
  void dispose() {
    _brillo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const texto = Text(
      '—',
      style: TextStyle(
        color: AppColors.texto,
        fontSize: 24,
        fontWeight: FontWeight.w900,
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) return texto;
    return AnimatedBuilder(
      animation: _brillo,
      builder: (context, hijo) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          colors: const [
            AppColors.textoTenue,
            AppColors.texto,
            AppColors.textoTenue,
          ],
          stops: [
            (_brillo.value - 0.3).clamp(0.0, 1.0),
            _brillo.value,
            (_brillo.value + 0.3).clamp(0.0, 1.0),
          ],
        ).createShader(rect),
        child: hijo,
      ),
      child: texto,
    );
  }
}
