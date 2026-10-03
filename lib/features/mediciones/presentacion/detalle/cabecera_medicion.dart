// lib/features/mediciones/presentacion/detalle/cabecera_medicion.dart

import 'package:flutter/material.dart';

import '../../../../core/fechas/instante.dart';
import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/medicion.dart';
import '../../dominio/reglas_mediciones.dart';
import '../widgets/partes_mediciones.dart';
import 'ficha_medicion.dart';

/// La cabecera de «Detalle de la medición»: el valor grande, el tipo, la
/// fecha y la hora, las insignias (el origen y la calidad), el momento,
/// quién la analizó (si es de la cámara) y las notas.
class CabeceraMedicion extends StatelessWidget {
  final Medicion medicion;

  /// Está en la cola del teléfono, esperando red.
  final bool pendiente;

  /// El dependiente, si es de uno.
  final String? pacienteNombre;

  const CabeceraMedicion({
    super.key,
    required this.medicion,
    this.pendiente = false,
    this.pacienteNombre,
  });

  @override
  Widget build(BuildContext context) {
    final m = medicion;
    final color = colorDelTipo(m.tipo);
    final local = enHoraDeLaClinica(m.medidoEn);
    final origen = m.metodo.esCamara ? origenDelAnalisis(m.notas) : null;
    final notas = notasVisibles(m.notas);

    return TarjetaTranslucida(
      key: const Key('detalle-cabecera'),
      tinte: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(iconoDelTipo(m.tipo), color: color, size: 27),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreDelTipo(m.tipo),
                      style: const TextStyle(
                        color: AppColors.textoSecundario,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        valorDeMedicion(m),
                        key: const Key('detalle-valor'),
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Linea(
            icono: Icons.event_rounded,
            texto:
                '${FormatoFecha.diaLargoConAnio(local)} · '
                '${FormatoFecha.hora(local)}',
          ),
          if (pacienteNombre != null)
            _Linea(icono: Icons.person_outline, texto: 'De $pacienteNombre'),
          if (m.contexto != null)
            _Linea(
              icono: Icons.self_improvement_rounded,
              texto: nombreDelContexto(m.contexto!),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...insigniasDeMedicion(m),
              if (pendiente)
                const Pastilla(
                  texto: 'Pendiente de envío',
                  color: AppColors.alerta,
                  icono: Icons.cloud_upload_outlined,
                ),
            ],
          ),
          if (origen != null) ...[
            const SizedBox(height: 10),
            Text(
              origen,
              key: const Key('detalle-origen'),
              style: const TextStyle(
                color: AppColors.textoTenue,
                fontSize: 11.5,
              ),
            ),
          ],
          if (notas != null) ...[
            const SizedBox(height: 10),
            Text(
              notas,
              key: const Key('detalle-notas'),
              style: const TextStyle(
                color: AppColors.textoSuave,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Linea({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        Icon(icono, size: 16, color: AppColors.textoTenue),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              color: AppColors.textoSecundario,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}
