// lib/core/web/navegacion_web.dart

/// Las páginas de fuera dentro de la aplicación, sin plataforma: qué
/// dirección se puede abrir, qué se hace con cada navegación y qué título
/// lleva la cabecera.
///
/// Todo es puro para que las pruebas lo fijen sin WebView. Lo usan
/// `vista_web.dart` (el WebView) y `PaginaWebPage` (la pantalla).
library;

/// La dirección web que se puede abrir en la pantalla de páginas web:
/// `http` o `https` con un servidor. `null` si no lo es (una ruta interna,
/// un `tel:`, un texto cualquiera).
Uri? direccionWebValida(String texto) {
  final direccion = Uri.tryParse(texto.trim());
  if (direccion == null || direccion.host.isEmpty) return null;

  return esWeb(direccion) ? direccion : null;
}

/// Si la dirección es `http` o `https`.
bool esWeb(Uri direccion) {
  final esquema = direccion.scheme.toLowerCase();
  return esquema == 'http' || esquema == 'https';
}

/// Si la dirección es un teléfono o un correo: van al marcador o a la
/// aplicación de correo del teléfono, que es lo que se espera al tocarlos.
bool esContacto(Uri direccion) {
  final esquema = direccion.scheme.toLowerCase();
  return esquema == 'tel' || esquema == 'mailto';
}

/// Qué se hace con una navegación de la página.
enum DecisionWeb {
  /// Se carga en la misma pantalla: navegar dentro de la página se puede.
  permitir,

  /// Un `tel:` o un `mailto:` tocado: no se carga, se abre el marcador o el
  /// correo del teléfono.
  abrirContacto,

  /// Otra aplicación, otra tienda, un archivo del teléfono, un guion: no se
  /// carga y la persona sigue donde estaba. Nada saca a nadie de la
  /// aplicación.
  bloquear,
}

/// Decide una navegación del WebView.
///
/// - `http`/`https`: se carga (en el marco principal o en un marco).
/// - `tel:`/`mailto:`: al marcador o al correo, pero solo si la persona lo
///   tocó ([tocado]); una página no abre el marcador por su cuenta. Si la
///   plataforma no dice si fue un toque (`null`), se da por tocado.
/// - Los marcos de una página pueden cargar `about:`, `data:` y `blob:`
///   (así se arman muchos); la página principal, solo `about:blank`.
/// - Todo lo demás (`intent:`, `market:`, `whatsapp:`, `file:`,
///   `javascript:`…) se bloquea.
DecisionWeb decidirNavegacionWeb(
  Uri destino, {
  bool marcoPrincipal = true,
  bool? tocado,
}) {
  if (esWeb(destino)) return DecisionWeb.permitir;

  if (esContacto(destino)) {
    return tocado == false ? DecisionWeb.bloquear : DecisionWeb.abrirContacto;
  }

  final esquema = destino.scheme.toLowerCase();

  if (!marcoPrincipal) {
    return const {'about', 'data', 'blob'}.contains(esquema)
        ? DecisionWeb.permitir
        : DecisionWeb.bloquear;
  }

  return esquema == 'about' && destino.path == 'blank'
      ? DecisionWeb.permitir
      : DecisionWeb.bloquear;
}

/// Una ventana nueva (`target="_blank"`, `window.open`) no abre otra
/// pantalla ni el navegador: se carga en la misma, si se puede cargar.
DecisionWeb decidirVentanaNueva(Uri? destino, {bool? tocado}) {
  if (destino == null) return DecisionWeb.bloquear;

  return decidirNavegacionWeb(destino, tocado: tocado);
}

/// El título de la cabecera: el que se pidió (el nombre del enlace del
/// menú), si no el de la página, y si la página todavía no tiene título,
/// el servidor sin `www.`.
String tituloDePaginaWeb({
  required Uri direccion,
  String? pedido,
  String? deLaPagina,
}) {
  final nombre = pedido?.trim() ?? '';
  if (nombre.isNotEmpty) return nombre;

  final servidor = servidorVisible(direccion);
  final pagina = deLaPagina?.trim() ?? '';

  // Mientras carga, algunas plataformas dan la dirección como título.
  if (pagina.isNotEmpty &&
      pagina != direccion.toString() &&
      !pagina.startsWith('http://') &&
      !pagina.startsWith('https://')) {
    return pagina;
  }

  return servidor.isEmpty ? 'Página web' : servidor;
}

/// El servidor como se lee en la cabecera: `andina.ec` en vez de
/// `www.andina.ec`.
String servidorVisible(Uri direccion) {
  final servidor = direccion.host.toLowerCase();
  return servidor.startsWith('www.') ? servidor.substring(4) : servidor;
}

/// Si un error del WebView es que la página no cargó: el de la página
/// principal (iOS no lo dice: solo avisa de esos), de una dirección web y
/// que no sea una carga cancelada. Las navegaciones que se bloquean (un
/// `intent:`, un `tel:`) también llegan como error en iOS, y esas no
/// cuentan; tampoco los errores de un marco o de un recurso (una imagen, un
/// anuncio).
bool esFalloDeCargaWeb(
  Uri? direccion, {
  bool? marcoPrincipal,
  bool cancelado = false,
}) {
  if (cancelado || marcoPrincipal == false || direccion == null) return false;

  return esWeb(direccion);
}
