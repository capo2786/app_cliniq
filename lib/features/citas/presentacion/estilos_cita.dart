import 'package:flutter/material.dart';

import '../../../core/tema/tokens.dart';
import '../data/models/cita.dart';

/// El color y el icono de cada modalidad y de cada estado.
///
/// El color es información, no adorno: de un vistazo se distingue una
/// videollamada de una consulta en persona. Por eso cada uno lleva además su
/// icono —el color solo no basta para quien no distingue colores—.
extension EstiloTipoCita on TipoCita {
  Color get color => switch (this) {
    TipoCita.presencial => AppColors.primarioClaro,
    TipoCita.telemedicina => AppColors.violeta,
    TipoCita.asincrona => AppColors.menta,
  };

  IconData get icono => switch (this) {
    TipoCita.presencial => Icons.medical_services_outlined,
    TipoCita.telemedicina => Icons.videocam_outlined,
    TipoCita.asincrona => Icons.description_outlined,
  };
}

extension EstiloEstadoCita on EstadoCita {
  Color get color => switch (this) {
    EstadoCita.programada => AppColors.celeste,
    EstadoCita.reagendada => AppColors.ambar,
    EstadoCita.atendida => AppColors.exito,
    EstadoCita.noAsistio => AppColors.peligroSuave,
    EstadoCita.cancelada => AppColors.textoSecundario,
  };

  IconData get icono => switch (this) {
    EstadoCita.programada => Icons.schedule_rounded,
    EstadoCita.reagendada => Icons.update_rounded,
    EstadoCita.atendida => Icons.check_circle_outline_rounded,
    EstadoCita.noAsistio => Icons.block_rounded,
    EstadoCita.cancelada => Icons.cancel_outlined,
  };
}
