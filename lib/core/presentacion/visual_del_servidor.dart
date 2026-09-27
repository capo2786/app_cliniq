// lib/core/presentacion/visual_del_servidor.dart

import 'package:flutter/material.dart';

/// Los iconos y colores que el administrador elige en el panel, traducidos a
/// la aplicación.
///
/// El panel dibuja sus iconos con un juego propio de nombres (`home`,
/// `calendario-mas`, `estetoscopio`…, ver `ui/icono/icono.ts`). Cada nombre
/// tiene aquí su equivalente de Material; uno que no está —un icono nuevo
/// del panel que esta versión todavía no conoce— se pinta con
/// [iconoGenerico] en vez de fallar o de quedar vacío.
const IconData iconoGenerico = Icons.apps_rounded;

const Map<String, IconData> iconosDelPanel = {
  'actividad': Icons.monitor_heart_outlined,
  'alerta': Icons.warning_amber_rounded,
  'ban': Icons.block_rounded,
  'calendario': Icons.event_note_rounded,
  'calendario-mas': Icons.add_circle_outline_rounded,
  'candado': Icons.lock_outline_rounded,
  'cedula': Icons.badge_outlined,
  'check': Icons.check_rounded,
  'check-circulo': Icons.check_circle_outline_rounded,
  'chevron': Icons.chevron_right_rounded,
  'chevron-abajo': Icons.expand_more_rounded,
  'chevron-izq': Icons.chevron_left_rounded,
  'chispa': Icons.auto_awesome_outlined,
  'close': Icons.close_rounded,
  'corazon': Icons.favorite_border_rounded,
  'correo': Icons.mail_outline_rounded,
  'cruz': Icons.local_hospital_outlined,
  'documento': Icons.description_outlined,
  'edit': Icons.edit_outlined,
  'enviar': Icons.send_rounded,
  'estetoscopio': Icons.medical_services_outlined,
  'filtro': Icons.filter_list_rounded,
  'flecha': Icons.arrow_forward_rounded,
  'home': Icons.home_rounded,
  'host': Icons.dns_outlined,
  'imprimir': Icons.print_outlined,
  'info': Icons.info_outline_rounded,
  'key': Icons.key_rounded,
  'list': Icons.list_alt_rounded,
  'lista-clinica': Icons.assignment_outlined,
  'logout': Icons.logout_rounded,
  'luna': Icons.dark_mode_outlined,
  'menu': Icons.menu_rounded,
  'ojo': Icons.visibility_outlined,
  'ojo-tachado': Icons.visibility_off_outlined,
  'plus': Icons.add_rounded,
  'refresh': Icons.refresh_rounded,
  'reloj': Icons.schedule_rounded,
  'search': Icons.search_rounded,
  'selector': Icons.tune_rounded,
  'shield': Icons.shield_outlined,
  'sol': Icons.light_mode_outlined,
  'standalone': Icons.web_asset_rounded,
  'teclado': Icons.keyboard_outlined,
  'telefono': Icons.phone_outlined,
  'template': Icons.dashboard_customize_outlined,
  'trash': Icons.delete_outline_rounded,
  'user': Icons.person_outline_rounded,
  'user-plus': Icons.person_add_alt_outlined,
  'users': Icons.group_outlined,
  'video': Icons.videocam_outlined,
};

/// El icono de la aplicación para un nombre del panel; desconocido o vacío,
/// [iconoGenerico].
IconData iconoDelServidor(String? nombre) =>
    iconosDelPanel[nombre?.trim().toLowerCase()] ?? iconoGenerico;

/// Un color `#RGB`, `#RRGGBB` o `#AARRGGBB` del panel, o `null` si no es un
/// color (vacío o mal escrito): quien lo pinta usa entonces el de su tema.
Color? colorDelServidor(String? texto) {
  var hex = texto?.trim() ?? '';
  if (hex.startsWith('#')) hex = hex.substring(1);

  if (hex.length == 3) {
    hex = hex.split('').map((c) => '$c$c').join();
  }
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;

  final valor = int.tryParse(hex, radix: 16);
  return valor == null ? null : Color(valor);
}
