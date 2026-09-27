import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../web/navegacion_web.dart';
import 'avisos.dart';
import 'pagina_web_page.dart';

/// Abre una página web dentro de la aplicación, en su propia pantalla
/// ([PaginaWebPage]): un WebView bajo la cabecera de Cliniq, con su título y
/// «Cerrar». Ni Chrome Custom Tabs, ni Safari, ni el navegador del teléfono.
///
/// Es para lo que no es de la clínica ni tiene pantalla propia: un enlace
/// `EXTERNO` del menú que puso el administrador, un enlace web de un
/// artículo de ayuda o de un documento. [titulo] va en la cabecera (el
/// nombre del enlace); sin él, el de la página. Un `tel:` o un `mailto:` se
/// abren con el marcador o el correo del teléfono. Si la dirección no es
/// web, se dice con la dirección a la vista: un botón que no hace nada es
/// peor que un aviso.
Future<void> abrirPaginaWeb(
  BuildContext context,
  String url, {
  String? titulo,
}) async {
  final direccion = Uri.tryParse(url.trim());

  if (direccion != null && esContacto(direccion)) {
    return abrirContacto(context, direccion);
  }

  final web = direccionWebValida(url);
  if (web == null) {
    mostrarAviso(context, 'No pudimos abrir el enlace: $url', error: true);
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PaginaWebPage(direccion: web, titulo: titulo),
    ),
  );
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

/// Un `tel:` o un `mailto:` que llegó escrito (un enlace del menú, de un
/// texto o de una página web): se abre con el marcador o con el correo del
/// teléfono.
Future<void> abrirContacto(BuildContext context, Uri direccion) => _abrirFuera(
  context,
  direccion,
  direccion.scheme == 'tel'
      ? 'Llama al ${direccion.path}.'
      : 'Escribe a ${direccion.path}.',
);

Future<void> _abrirFuera(
  BuildContext context,
  Uri direccion,
  String siNoAbre,
) async {
  // Fuera de la aplicación solo van un teléfono y un correo; una dirección
  // web tiene su pantalla (abrirPaginaWeb).
  if (!esContacto(direccion)) return;

  var abierto = false;

  try {
    // Lo único que sale de la aplicación: el marcador y el correo del
    // teléfono.
    abierto = await launchUrl(direccion, mode: LaunchMode.externalApplication);
  } catch (_) {
    abierto = false;
  }

  if (!abierto && context.mounted) {
    mostrarAviso(context, 'No pudimos abrirlo desde aquí. $siNoAbre');
  }
}
