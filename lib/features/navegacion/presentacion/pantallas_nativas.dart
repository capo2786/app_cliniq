// lib/features/navegacion/presentacion/pantallas_nativas.dart

import 'package:flutter/material.dart';

import '../../agendar/presentacion/agendar_page.dart';
import '../../avisos/presentacion/avisos_page.dart';
import '../../citas/presentacion/citas_page.dart';
import '../../consultas/presentacion/consultas_page.dart';
import '../../consultas/presentacion/detalle_consulta_page.dart';
import '../../dependientes/presentacion/dependientes_page.dart';
import '../../legal/presentacion/documento_legal_page.dart';
import '../../perfil/presentacion/perfil_page.dart';
import '../../privacidad/presentacion/privacidad_page.dart';
import '../dominio/destinos.dart';
import 'muy_pronto_page.dart';

/// La pantalla que abre cada destino del enrutador: el único lugar donde una
/// ruta del sistema se convierte en una pantalla.
///
/// [titulo] es el nombre del enlace del menú, si se llegó desde ahí (una
/// pantalla que todavía no existe lo usa en su cabecera). [alAgendar] lo pone
/// el tablero para que «Mis citas» pueda abrir el agendamiento.
///
/// **Punto de registro de los módulos nuevos.** Mi salud, Centro de ayuda y
/// Soporte abren «Muy pronto» mientras no tengan pantalla; al integrarlas se
/// cambia su línea aquí por su página (`MiSaludPage()`, `CentroAyudaPage()`,
/// `SoportePage()`, `TicketPage(id: destino.parametro('id'))`) y nada más:
/// el menú, la campana y los enlaces ya llegan hasta aquí.
Widget pantallaNativa(
  DestinoNativo destino, {
  String? titulo,
  VoidCallback? alAgendar,
}) {
  return switch (destino.pantalla) {
    // El inicio siempre es una pestaña: lo arma el tablero, con sus accesos.
    PantallaNativa.inicio => const SizedBox.shrink(),
    PantallaNativa.citas => CitasPage(alAgendar: alAgendar),
    PantallaNativa.agendar => const AgendarPage(),
    PantallaNativa.dependientes => const DependientesPage(),
    PantallaNativa.consultas => const ConsultasPage(),
    PantallaNativa.consulta => DetalleConsultaPage(
      consultaId: destino.parametro('id'),
    ),
    PantallaNativa.perfil => const PerfilPage(),
    PantallaNativa.videoconsulta => MuyProntoPage(
      titulo: titulo ?? 'Videoconsulta',
    ),
    PantallaNativa.avisos => AvisosPage(titulo: titulo),
    PantallaNativa.privacidad => const PrivacidadPage(),
    PantallaNativa.encuesta => MuyProntoPage(titulo: titulo ?? 'Encuesta'),
    PantallaNativa.legal => DocumentoLegalPage(
      slug: destino.parametro('slug'),
      titulo: titulo,
    ),

    // ── Módulos por integrar ───────────────────────────────────────────
    PantallaNativa.miSalud => MuyProntoPage(titulo: titulo ?? 'Mi salud'),
    PantallaNativa.ayuda => MuyProntoPage(titulo: titulo ?? 'Centro de ayuda'),
    PantallaNativa.soporte => MuyProntoPage(titulo: titulo ?? 'Soporte'),
    PantallaNativa.ticket => MuyProntoPage(
      titulo: titulo ?? 'Ticket de soporte',
    ),
  };
}
