// lib/features/avisos/dominio/avisos.dart

import 'package:flutter/material.dart';

/// Cada cuánto se pregunta, con la aplicación abierta, si hay avisos nuevos:
/// el mismo minuto de la campana del panel (`INTERVALO_MS = 60_000`). Un
/// contador que se actualiza cada segundo no aporta nada y gasta datos.
const Duration intervaloCampana = Duration(seconds: 60);

/// El icono de un aviso según su tipo, como en el panel
/// (`iconoNotificacion`); lo desconocido es un aviso genérico.
IconData iconoDeAviso(String tipo) {
  final t = tipo.toUpperCase();

  if (t.contains('VIDEO')) return Icons.videocam_outlined;
  if (t.contains('CONSULTA')) return Icons.medical_services_outlined;
  if (t.contains('CITA') || t.contains('RECORDATORIO')) {
    return Icons.event_note_rounded;
  }
  if (t.contains('TICKET') || t.contains('SOPORTE')) {
    return Icons.support_agent_rounded;
  }
  if (t.contains('ARCO') || t.contains('PRIVACIDAD')) {
    return Icons.shield_outlined;
  }
  if (t.contains('ENCUESTA')) return Icons.star_outline_rounded;
  if (t.contains('DOCUMENTO') || t.contains('RECETA') || t.contains('ORDEN')) {
    return Icons.description_outlined;
  }
  if (t.contains('ALERTA') || t.contains('SEGURIDAD')) {
    return Icons.warning_amber_rounded;
  }

  return Icons.notifications_none_rounded;
}

/// La insignia de la campana: hasta 99, y de ahí «99+».
String insigniaDeAvisos(int noLeidos) => noLeidos > 99 ? '99+' : '$noLeidos';
