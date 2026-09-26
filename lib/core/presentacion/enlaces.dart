import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'avisos.dart';

/// Abre una dirección en el navegador del teléfono.
///
/// Si no se puede abrir —no hay navegador, la dirección está mal—, se dice
/// con la dirección a la vista para que la persona la copie: un botón que no
/// hace nada es peor que un aviso.
Future<void> abrirEnlace(BuildContext context, String url) async {
  var abierto = false;

  try {
    abierto = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    abierto = false;
  }

  if (!abierto && context.mounted) {
    mostrarAviso(
      context,
      'No pudimos abrir el documento. Ábrelo en tu navegador: $url',
      error: true,
    );
  }
}
