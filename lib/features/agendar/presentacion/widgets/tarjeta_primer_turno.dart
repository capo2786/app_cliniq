import 'package:flutter/material.dart';

import '../../../../core/formato/fechas.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../dominio/huecos.dart';
import '../../providers/agendar_state.dart';
import 'pastilla_modalidad.dart';

/// «El primer turno disponible»: médico, día y hora, a un toque.
///
/// Mientras se confirma el turno contra la API ([confirmando]) no se puede
/// volver a tocar y enseña una rueda en vez de la flecha.
class TarjetaPrimerTurno extends StatelessWidget {
  final PrimerTurno primero;
  final DateTime ahora;
  final bool confirmando;
  final VoidCallback onTap;

  const TarjetaPrimerTurno({
    super.key,
    required this.primero,
    required this.ahora,
    required this.confirmando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final turno = primero.turno;
    final medico = primero.medico;
    final cuando = turnoNatural(turno.inicio, ahora);

    return Semantics(
      button: true,
      label: 'El primer turno disponible: ${medico.nombre}, $cuando',
      child: TarjetaTranslucida(
        key: const Key('primer-turno'),
        onTap: confirmando ? null : onTap,
        tinte: AppColors.acento,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EL PRIMER TURNO DISPONIBLE',
                    style: TextStyle(
                      color: AppColors.acentoClaro,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    FormatoFecha.capitalizar(cuando),
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    FormatoFecha.diaLargo(turno.inicio),
                    style: const TextStyle(
                      color: AppColors.textoSecundario,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    [medico.nombre, ?medico.especialidad].join(' · '),
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  PastillaModalidad(tipo: turno.modalidad),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _Accion(confirmando: confirmando),
          ],
        ),
      ),
    );
  }
}

class _Accion extends StatelessWidget {
  final bool confirmando;

  const _Accion({required this.confirmando});

  @override
  Widget build(BuildContext context) {
    if (confirmando) {
      return SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2.6,
          color: AppColors.acentoClaro,
        ),
      );
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: AppGradientes.accion,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
    );
  }
}
