// lib/features/ayuda/presentacion/enlaces_de_ayuda.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/presentacion/avisos.dart';
import '../../mi_salud/presentacion/mi_salud_page.dart';
import '../../soporte/presentacion/soporte_page.dart';
import '../../soporte/presentacion/ticket_page.dart';
import 'centro_ayuda_page.dart';

/// Abre una ruta interna que no es de estos módulos con el enrutador de la
/// aplicación. Devuelve `false` si la aplicación no la sabe abrir.
typedef AbrirRutaInterna = bool Function(BuildContext context, String ruta);

/// La pantalla nativa de una ruta de la ayuda, de soporte o de Mi salud, o
/// `null` si la ruta es de otro módulo.
Widget? pantallaDeLaRuta(String ruta, {AbrirRutaInterna? abrirRuta}) {
  final limpia = Uri.tryParse(ruta)?.path ?? ruta;
  final partes = limpia.split('/').where((p) => p.isNotEmpty).toList();

  return switch (partes) {
    ['ayuda'] => CentroAyudaPage(abrirRuta: abrirRuta),
    ['soporte'] => const SoportePage(),
    ['soporte', 'tickets', final id] => TicketPage(id: id),
    ['mi-salud'] => const MiSaludPage(),
    _ => null,
  };
}

/// Abre un enlace de un artículo de ayuda sin sacar a nadie de la
/// aplicación:
///
/// - una ruta interna (`/soporte`, `/portal/agendar`), con su pantalla
///   nativa; si la aplicación no la sabe abrir, se dice y no se va al
///   navegador;
/// - una dirección `http(s)`, en el navegador integrado;
/// - un `mailto:`, con la aplicación de correo, como siempre.
Future<void> abrirEnlaceDeAyuda(
  BuildContext context,
  String url, {
  AbrirRutaInterna? abrirRuta,
}) async {
  if (url.startsWith('/')) {
    _abrirRuta(context, url, abrirRuta);
    return;
  }

  final direccion = Uri.tryParse(url);
  final correo = direccion?.scheme.toLowerCase() == 'mailto';

  var abierto = false;
  if (direccion != null) {
    try {
      abierto = await launchUrl(
        direccion,
        mode: correo
            ? LaunchMode.externalApplication
            : LaunchMode.inAppBrowserView,
      );
    } catch (_) {
      abierto = false;
    }
  }

  if (!abierto && context.mounted) {
    mostrarAviso(context, 'No pudimos abrir el enlace: $url', error: true);
  }
}

void _abrirRuta(
  BuildContext context,
  String ruta,
  AbrirRutaInterna? abrirRuta,
) {
  final pantalla = pantallaDeLaRuta(ruta, abrirRuta: abrirRuta);

  if (pantalla != null) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => pantalla));
    return;
  }

  if (abrirRuta?.call(context, ruta) ?? false) return;

  mostrarAviso(context, 'Esa sección no está disponible en la aplicación.');
}
