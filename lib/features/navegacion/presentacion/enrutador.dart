// lib/features/navegacion/presentacion/enrutador.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/presentacion/avisos.dart';
import '../../../core/presentacion/enlaces.dart';
import '../data/menu_service.dart';
import '../dominio/destinos.dart';
import 'pantallas_nativas.dart';

/// El tablero, visto desde cualquier pantalla que viva debajo de él: cómo se
/// abre un destino (su pestaña, o encima) y si hay campana.
///
/// Lo pone el tablero sobre sus pestañas y sobre cada pantalla que abre
/// encima: una ruta nueva no cuelga del tablero en el árbol de widgets, así
/// que se le vuelve a poner.
class AlcanceDeNavegacion extends InheritedWidget {
  /// Abre un destino: cambia de pestaña si la tiene; si no, lo abre encima.
  final void Function(DestinoNativo destino, {String? titulo}) abrir;

  /// El enlace de la campana del menú, o `null` si no hay campana.
  final EnlaceMenu? campana;

  const AlcanceDeNavegacion({
    super.key,
    required this.abrir,
    required this.campana,
    required super.child,
  });

  /// El de más arriba, escuchando sus cambios (para `build`).
  static AlcanceDeNavegacion? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AlcanceDeNavegacion>();

  @override
  bool updateShouldNotify(AlcanceDeNavegacion anterior) =>
      anterior.campana != campana || anterior.abrir != abrir;
}

/// Abre un destino desde cualquier pantalla.
///
/// Dentro del tablero lo abre el tablero (así «Mis citas» vuelve a su
/// pestaña). Fuera de él —la aceptación de los documentos legales, una
/// prueba de una pantalla suelta— se abre encima.
void abrirDestino(
  BuildContext context,
  DestinoNativo destino, {
  String? titulo,
}) {
  final alcance = context.getInheritedWidgetOfExactType<AlcanceDeNavegacion>();

  if (alcance != null) {
    alcance.abrir(destino, titulo: titulo);
    return;
  }

  final navegador = Navigator.of(context);

  if (destino.pantalla == PantallaNativa.inicio) {
    navegador.popUntil((ruta) => ruta.isFirst);
    return;
  }

  navegador.push(
    MaterialPageRoute<void>(
      builder: (_) => pantallaNativa(destino, titulo: titulo),
    ),
  );
}

/// Abre una ruta interna del sistema (el `enlace` de un aviso, un enlace de
/// un documento) con su pantalla. Devuelve `false` si la aplicación no la
/// sabe abrir (`/admin/...`): entonces no se hace nada, y quien llama decide
/// qué decir. Nunca se abre el navegador.
bool abrirRuta(BuildContext context, String ruta, {String? titulo}) {
  final destino = destinoDeRuta(ruta);
  if (destino == null) return false;

  abrirDestino(context, destino, titulo: titulo);
  return true;
}

/// Abre un enlace que venía dentro de un texto del servidor (un documento
/// legal, un artículo de ayuda), sin salir de la aplicación:
///
/// - una ruta interna (`/legal/privacidad`), con su pantalla; si la
///   aplicación no la sabe abrir, se dice;
/// - `mailto:`, con el correo del teléfono;
/// - una dirección web, en el navegador integrado.
void abrirEnlaceDeTexto(BuildContext context, String direccion) {
  final enlace = direccion.trim();

  if (enlace.startsWith('/')) {
    if (!abrirRuta(context, enlace)) {
      mostrarAviso(
        context,
        'Ese enlace no tiene una pantalla en la aplicación.',
      );
    }
    return;
  }

  final uri = Uri.tryParse(enlace);
  if (uri == null) return;

  if (uri.scheme == 'mailto' || uri.scheme == 'tel') {
    unawaited(abrirContacto(context, uri));
    return;
  }

  if (uri.scheme == 'http' || uri.scheme == 'https') {
    unawaited(abrirEnlace(context, enlace, queEs: 'el enlace'));
  }
}
