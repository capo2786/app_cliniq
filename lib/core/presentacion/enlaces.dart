import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'avisos.dart';

/// Abre una dirección en el navegador del teléfono.
///
/// Si no se puede abrir —no hay navegador, la dirección está mal—, se dice
/// con la dirección a la vista para que la persona la copie: un botón que no
/// hace nada es peor que un aviso. [queEs] nombra lo que se abre en ese
/// aviso: «el documento», «el panel web».
Future<void> abrirEnlace(
  BuildContext context,
  String url, {
  String queEs = 'el documento',
}) async {
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
      'No pudimos abrir $queEs. Ábrelo en tu navegador: $url',
      error: true,
    );
  }
}

/// Un teléfono como dirección `tel:`, sin espacios ni guiones (el marcador
/// del teléfono los ignora, pero algunos no aceptan la dirección con ellos).
Uri direccionDeTelefono(String numero) =>
    Uri(scheme: 'tel', path: numero.replaceAll(RegExp(r'[^0-9+*#]'), ''));

/// Un correo como dirección `mailto:`.
Uri direccionDeCorreo(String correo) =>
    Uri(scheme: 'mailto', path: correo.trim());

/// Abre el marcador del teléfono con ese número. Si no se puede (una tableta
/// sin línea), se dice con el número a la vista.
Future<void> llamar(BuildContext context, String numero) =>
    _abrirFuera(context, direccionDeTelefono(numero), 'Llama al $numero.');

/// Abre la aplicación de correo con esa dirección.
Future<void> escribirCorreo(BuildContext context, String correo) =>
    _abrirFuera(context, direccionDeCorreo(correo), 'Escribe a $correo.');

Future<void> _abrirFuera(
  BuildContext context,
  Uri direccion,
  String siNoAbre,
) async {
  var abierto = false;

  try {
    abierto = await launchUrl(direccion, mode: LaunchMode.externalApplication);
  } catch (_) {
    abierto = false;
  }

  if (!abierto && context.mounted) {
    mostrarAviso(context, 'No pudimos abrirlo desde aquí. $siNoAbre');
  }
}
