import 'package:flutter/material.dart';

import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../../../citas/presentacion/estilos_cita.dart';
import '../../data/models/medico_portal.dart';
import '../../dominio/horarios.dart';
import '../../dominio/huecos.dart';
import 'pastilla_modalidad.dart';

/// Un médico de la lista: quién es, qué modalidades ofrece, cuándo atiende
/// y cuál es su próximo turno libre (el que dice la API).
class TarjetaMedico extends StatelessWidget {
  final MedicoPortal medico;
  final DateTime ahora;
  final bool elegido;
  final VoidCallback onTap;

  const TarjetaMedico({
    super.key,
    required this.medico,
    required this.ahora,
    required this.elegido,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final modalidades = medico.modalidadesOfrecidas;

    return TarjetaTranslucida(
      onTap: onTap,
      tinte: elegido ? AppColors.acento : null,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Encabezado(medico: medico),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tipo in modalidades) PastillaModalidad(tipo: tipo),
            ],
          ),
          const SizedBox(height: 10),
          _LineaDato(
            icono: Icons.schedule_rounded,
            texto: resumenHorario(medico.horariosAtencion),
            color: AppColors.textoSuave,
            colorIcono: AppColors.primarioClaro,
          ),
          const SizedBox(height: 6),
          _ProximoTurno(medico: medico, ahora: ahora),
        ],
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  final MedicoPortal medico;

  const _Encabezado({required this.medico});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Iniciales(nombre: medico.nombre),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                medico.nombre,
                style: const TextStyle(
                  color: AppColors.texto,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              if (medico.especialidad != null || medico.ciudad != null)
                Text(
                  [?medico.especialidad, ?medico.ciudad].join(' · '),
                  style: const TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 12.5,
                  ),
                ),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          color: AppColors.textoSecundario,
        ),
      ],
    );
  }
}

class _Iniciales extends StatelessWidget {
  final String nombre;

  const _Iniciales({required this.nombre});

  String get _iniciales {
    final partes = nombre
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppGradientes.encabezado,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _iniciales,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 17,
        ),
      ),
    );
  }
}

/// «Próximo turno: hoy a las 15:30 · Telemedicina».
class _ProximoTurno extends StatelessWidget {
  final MedicoPortal medico;
  final DateTime ahora;

  const _ProximoTurno({required this.medico, required this.ahora});

  @override
  Widget build(BuildContext context) {
    final proximo = medico.proximo;

    if (proximo == null) {
      return const _LineaDato(
        icono: Icons.event_available_rounded,
        texto: 'Sin turnos próximos',
        color: AppColors.textoTenue,
      );
    }

    return _LineaDato(
      icono: Icons.event_available_rounded,
      texto: [
        'Próximo turno: ${turnoNatural(proximo.inicio, ahora)}',
        // Con una sola modalidad, ya se sabe cuál es.
        if (medico.modalidadesOfrecidas.length > 1)
          context.modalidad(proximo.modalidad).nombre,
      ].join(' · '),
      color: AppColors.exito,
      negrita: true,
    );
  }
}

class _LineaDato extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;
  final Color? colorIcono;
  final bool negrita;

  const _LineaDato({
    required this.icono,
    required this.texto,
    required this.color,
    this.colorIcono,
    this.negrita = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 15, color: colorIcono ?? color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: negrita ? FontWeight.w700 : null,
            ),
          ),
        ),
      ],
    );
  }
}
