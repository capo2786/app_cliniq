import 'package:flutter/material.dart';

import '../../../core/tema/tokens.dart';
import '../data/models/consulta.dart';

/// El color y el icono de cada estado de una consulta en línea.
///
/// Como en las citas, el color va siempre con su icono: el color solo no
/// basta para quien no distingue colores.
extension EstiloEstadoConsulta on EstadoConsulta {
  Color get color => switch (this) {
    EstadoConsulta.borrador => AppColors.ambar,
    EstadoConsulta.enviada => AppColors.celeste,
    EstadoConsulta.enRevision => AppColors.violeta,
    EstadoConsulta.respondida => AppColors.exito,
    EstadoConsulta.cerrada => AppColors.textoSecundario,
    EstadoConsulta.cancelada => AppColors.peligroSuave,
  };

  IconData get icono => switch (this) {
    EstadoConsulta.borrador => Icons.edit_note_rounded,
    EstadoConsulta.enviada => Icons.send_rounded,
    EstadoConsulta.enRevision => Icons.manage_search_rounded,
    EstadoConsulta.respondida => Icons.mark_chat_read_outlined,
    EstadoConsulta.cerrada => Icons.lock_outline_rounded,
    EstadoConsulta.cancelada => Icons.cancel_outlined,
  };

  /// Lo que significa para el paciente, en una línea.
  String get explicacion => switch (this) {
    EstadoConsulta.borrador =>
      'Todavía no la envías: el médico no la ha visto.',
    EstadoConsulta.enviada => 'Enviada. El médico todavía no la abre.',
    EstadoConsulta.enRevision => 'El médico está revisando tu consulta.',
    EstadoConsulta.respondida =>
      'El médico respondió. Puedes escribirle mientras dure el seguimiento.',
    EstadoConsulta.cerrada => 'Consulta cerrada.',
    EstadoConsulta.cancelada => 'Cancelaste esta consulta.',
  };
}

/// El color del plazo: ámbar si queda poco, rojo si ya se pasó.
Color colorDelPlazo(String? plazo) {
  if (plazo == null) return AppColors.acentoClaro;
  if (plazo == 'Demorada') return AppColors.peligroSuave;
  if (plazo.contains('min') || plazo == 'Queda 1 h') return AppColors.alerta;

  return AppColors.acentoClaro;
}
