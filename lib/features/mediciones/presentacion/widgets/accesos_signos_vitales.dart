// lib/features/mediciones/presentacion/widgets/accesos_signos_vitales.dart

import 'package:flutter/material.dart';

import '../../../../core/configuracion/en_contexto.dart';
import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../dominio/destinos_medico.dart';
import '../mis_signos_vitales_page.dart';

/// El acceso a «Mis signos vitales» desde Mi salud: lo que la persona (o
/// su dependiente) registra en casa y, si la clínica lo activa, con el
/// escáner experimental. No se enseña si la clínica no tiene activadas las
/// mediciones del paciente.
class AccesoSignosVitales extends StatelessWidget {
  final String? pacienteId;
  final String? nombre;

  const AccesoSignosVitales({
    super.key,
    required this.pacienteId,
    required this.nombre,
  });

  @override
  Widget build(BuildContext context) {
    if (!context.config.telemedicina.medicionesPacienteActiva) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: _tarjeta(context),
    );
  }

  Widget _tarjeta(BuildContext context) {
    return TarjetaTranslucida(
      key: const Key('mi-salud-signos-vitales'),
      tinte: AppColors.peligroSuave,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MisSignosVitalesPage(
            pacienteId: pacienteId,
            pacienteNombre: nombre,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.monitor_heart_outlined,
            color: AppColors.peligroSuave,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre == null
                      ? 'Mis signos vitales'
                      : 'Signos vitales de $nombre',
                  style: const TextStyle(
                    color: AppColors.texto,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Registra la presión, el pulso, la glucosa o el peso de '
                  'tus aparatos de casa.',
                  style: TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textoTenue),
        ],
      ),
    );
  }
}

/// «Mis signos vitales» desde una cita de telemedicina o una consulta en
/// línea: lo que se registre ahí se puede compartir con ese médico
/// ([destino]). No se enseña si la clínica no tiene activadas las
/// mediciones del paciente.
class BotonSignosVitales extends StatelessWidget {
  final DestinoMedico destino;

  /// El dependiente, o `null` si es del titular.
  final String? pacienteId;
  final String? pacienteNombre;

  final String texto;

  const BotonSignosVitales({
    super.key,
    required this.destino,
    required this.texto,
    this.pacienteId,
    this.pacienteNombre,
  });

  @override
  Widget build(BuildContext context) {
    if (!context.config.telemedicina.medicionesPacienteActiva) {
      return const SizedBox.shrink();
    }

    return BotonSecundario(
      texto: texto,
      icono: Icons.monitor_heart_outlined,
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MisSignosVitalesPage(
            pacienteId: pacienteId,
            pacienteNombre: pacienteNombre,
            destino: destino,
          ),
        ),
      ),
    );
  }
}
