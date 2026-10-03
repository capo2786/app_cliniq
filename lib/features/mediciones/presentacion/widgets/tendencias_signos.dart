// lib/features/mediciones/presentacion/widgets/tendencias_signos.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/fechas/instante.dart';
import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/chip_opcion.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/medicion.dart';
import '../../dominio/rangos_referencia.dart';
import '../../dominio/reglas_mediciones.dart';
import '../../dominio/tendencias.dart';
import '../../providers/tendencias_cubit.dart';
import 'grafico_evolucion.dart';

/// La pestaña «Tendencias»: el periodo (7 días, 30 días o 3 meses) y una
/// tarjeta por tipo con datos, con el último valor, el mínimo, el promedio
/// y el máximo y su gráfica con la franja de referencia.
///
/// [respaldo] son las mediciones que ya tiene «Registro»: se usan si el
/// periodo no se pudo pedir (sin red).
class TendenciasSignos extends StatelessWidget {
  final List<Medicion> respaldo;

  const TendenciasSignos({super.key, required this.respaldo});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TendenciasCubit, TendenciasState>(
      builder: (context, state) {
        final cubit = context.read<TendenciasCubit>();
        final ahora = cubit.ahora;
        final delServidor = state.mediciones;
        final tendencias = calcularTendencias(
          delServidor ?? respaldo,
          state.periodo,
          ahora,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in PeriodoTendencia.values)
                  ChipDeOpcion(
                    key: Key('periodo-${p.dias}'),
                    texto: p.nombre,
                    elegido: state.periodo == p,
                    onTap: () => cubit.cargar(p),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (delServidor == null && !state.cargando) ...[
              const RecuadroAviso.informacion(
                'Sin conexión: la tendencia usa solo lo guardado en este '
                'teléfono.',
                icono: Icons.offline_pin_outlined,
              ),
              const SizedBox(height: 12),
            ],
            if (state.incompleto) ...[
              const RecuadroAviso.informacion(
                'Hay muchas mediciones en este periodo: la tendencia usa las '
                '500 más recientes.',
              ),
              const SizedBox(height: 12),
            ],
            if (tendencias.isEmpty)
              state.cargando && delServidor == null
                  ? const CargandoCentro(mensaje: 'Cargando tus tendencias…')
                  : EstadoVacio(
                      icono: Icons.insights_outlined,
                      titulo: 'Sin mediciones en ${state.periodo.nombre}',
                      descripcion:
                          'Elige un periodo más largo o registra una medición '
                          'con tus aparatos de casa.',
                    )
            else ...[
              const LeyendaDeOrigen(),
              const SizedBox(height: 12),
              for (final t in tendencias) ...[
                TarjetaTendencia(
                  key: Key('tendencia-${t.tipo.codigo}'),
                  tendencia: t,
                  periodo: state.periodo,
                  ahora: ahora,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ],
        );
      },
    );
  }
}

/// La tarjeta de un tipo en el periodo.
class TarjetaTendencia extends StatelessWidget {
  final TendenciaDelTipo tendencia;
  final PeriodoTendencia periodo;
  final DateTime ahora;

  const TarjetaTendencia({
    super.key,
    required this.tendencia,
    required this.periodo,
    required this.ahora,
  });

  String _numero(double v) {
    final decimales = decimalesDelTipo(tendencia.tipo);
    return numeroLegible(decimales == 0 ? v.round() : v, decimales: decimales);
  }

  String _par(Resumen r, Resumen? r2, double Function(Resumen) campo) =>
      r2 == null
      ? _numero(campo(r))
      : '${_numero(campo(r))}/${_numero(campo(r2))}';

  @override
  Widget build(BuildContext context) {
    final t = tendencia;
    final ultima = t.ultima;
    final rango = etiquetaDeRango(t.tipo, ultima.valor, valor2: ultima.valor2);
    final fecha = FormatoFecha.cortaConHora(enHoraDeLaClinica(ultima.medidoEn));

    return TarjetaTranslucida(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nombreDelTipo(t.tipo),
            style: const TextStyle(
              color: AppColors.texto,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                valorDeMedicion(ultima),
                style: const TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              if (rango != null)
                Pastilla(
                  texto: rango,
                  color: rango.startsWith('En rango')
                      ? AppColors.exito
                      : AppColors.alerta,
                ),
            ],
          ),
          Text(
            esDeCamara(ultima.metodo)
                ? 'Última: $fecha · con la cámara (experimental)'
                : 'Última: $fecha',
            style: const TextStyle(color: AppColors.textoTenue, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (rotulo, campo) in [
                ('Mínimo', (Resumen r) => r.minimo),
                ('Promedio', (Resumen r) => r.promedio),
                ('Máximo', (Resumen r) => r.maximo),
              ])
                Expanded(
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
                      Text(
                        _par(t.resumen, t.resumen2, campo),
                        style: const TextStyle(
                          color: AppColors.textoSuave,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (t.puntos.length >= 2)
            GraficoEvolucion(
              key: Key('grafico-${t.tipo.codigo}'),
              tendencia: t,
              periodo: periodo,
              ahora: ahora,
            )
          else
            const Text(
              'Con una sola medición todavía no hay gráfica.',
              style: TextStyle(color: AppColors.textoTenue, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
