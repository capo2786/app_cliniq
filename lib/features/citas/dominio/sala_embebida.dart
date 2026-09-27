// lib/features/citas/dominio/sala_embebida.dart

/// La sala de Jitsi dentro de la aplicación, sin plataforma: la dirección
/// que carga el WebView, los ajustes de Jitsi que van en ella y lo que se
/// decide con cada navegación, cada permiso y cada error de la página.
///
/// Todo es puro (entra un valor, sale otro) para que las pruebas lo fijen
/// sin WebView. Quien lo usa es `SalaJitsi` (`data/sala_jitsi.dart`).
library;

import 'dart:convert';

/// El idioma de la sala. Va en la consulta (`?lang=es`) y no en los ajustes:
/// `defaultLanguage` no está en la lista blanca de Jitsi, que lo descartaría.
const String idiomaDeLaSala = 'es';

/// Los botones de la barra de Jitsi: lo justo para una consulta.
const List<String> botonesDeLaSala = [
  'microphone',
  'camera',
  'chat',
  'raisehand',
  'tileview',
  'select-background',
  'hangup',
  'settings',
];

/// Los ajustes de Jitsi que viajan en la dirección de la sala
/// (`#config.…=…&interfaceConfig.…=…`), en orden.
///
/// Jitsi solo acepta desde la dirección las claves de sus listas blancas
/// (`react/features/base/config/configWhitelist.ts` e
/// `interfaceConfigWhitelist.ts`, versión `stable/jitsi-meet_11248`) y
/// descarta el resto sin avisar; las pruebas lo comprueban contra una copia
/// de esas listas. Lo que no está en ellas y hace falta se resuelve de otra
/// forma:
///
/// - el idioma, con `?lang=es` ([idiomaDeLaSala]);
/// - las marcas de agua de Jitsi (`SHOW_JITSI_WATERMARK`,
///   `SHOW_WATERMARK_FOR_GUESTS`, `SHOW_BRAND_WATERMARK`), con el estilo que
///   inyecta [guionDeLaSala] y en el `interface_config.js` del servidor.
///
/// La pantalla previa no se apaga desde aquí sino en el servidor
/// (`ENABLE_PREJOIN_PAGE=0`): pedida desde la dirección
/// (`prejoinConfig.enabled=false`), Jitsi —fuera de un iframe, como en el
/// WebView— entra sin cámara ni micrófono (`disableInitialGUM`).
///
/// El asunto se ve en la cabecera de Cliniq, así que dentro de Jitsi se
/// oculta (`hideConferenceSubject`); igual se manda, para que el nombre al
/// azar de la sala no aparezca en ninguna parte. `subject` solo lo aplica un
/// moderador; `localSubject` es el que ve quien entra.
Map<String, Object> ajustesDeJitsi({String asunto = ''}) {
  final limpio = asuntoParaJitsi(asunto);

  return {
    // `disableDeepLinking` está en desuso, pero el servidor puede no traer
    // `deeplinking`: se mandan los dos.
    'config.disableDeepLinking': true,
    'config.deeplinking.disabled': true,
    if (limpio.isNotEmpty) ...{
      'config.subject': limpio,
      'config.localSubject': limpio,
    },
    'config.hideConferenceSubject': true,
    // Los nombres de respaldo de Jitsi vienen en inglés y no se traducen.
    'config.defaultLocalDisplayName': 'Yo',
    'config.defaultRemoteDisplayName': 'Participante',
    'config.toolbarButtons': botonesDeLaSala,
    'config.disableInviteFunctions': true,
    'config.participantsPane.enabled': false,
    'config.disablePolls': true,
    'config.disableReactions': true,
    'config.recordingService.enabled': false,
    'config.recordingService.sharingEnabled': false,
    'config.localRecording.disable': true,
    // El viejo `liveStreamingEnabled` del servidor pisaría al nuevo si no se
    // manda también.
    'config.liveStreamingEnabled': false,
    'config.liveStreaming.enabled': false,
    'config.securityUi.hideLobbyButton': true,
    'config.securityUi.disableLobbyPassword': true,
    // La sala va con token: el aviso de «nombre de sala inseguro» confunde.
    'config.enableInsecureRoomNameWarning': false,
    // El nombre es el del token: no se cambia desde los ajustes de la sala.
    'config.readOnlyName': true,
    'config.disableProfile': true,
    // Una consulta médica: nada de gravatar ni estadísticas de terceros.
    'config.disableThirdPartyRequests': true,
    // Sin la encuesta de Jitsi al colgar, que además demora el cierre.
    'config.feedbackPercentage': 0,
    'interfaceConfig.SHOW_POWERED_BY': false,
    // Donde Jitsi nombra al proveedor o a «su» aplicación.
    'interfaceConfig.PROVIDER_NAME': 'Cliniq',
    'interfaceConfig.NATIVE_APP_NAME': 'Cliniq',
  };
}

/// El asunto como lo lee Jitsi sin romperse.
///
/// Jitsi decodifica cada valor y lo lee como JSON, pero antes cambia las
/// comillas tipográficas por rectas y `\&` por `&`: unas comillas “así” en
/// el nombre de la clínica dejarían el JSON roto y Jitsi descartaría el
/// asunto. Se dejan rectas (el JSON las escapa), sin barras invertidas ni
/// caracteres de control, y con un largo razonable.
String asuntoParaJitsi(String asunto) {
  final limpio = asunto
      .replaceAll(RegExp('[\u2018\u2019]'), "'")
      .replaceAll(RegExp('[\u201C\u201D]'), '"')
      .replaceAll(r'\', '')
      .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return limpio.length <= 120 ? limpio : limpio.substring(0, 120).trimRight();
}

/// Los ajustes como fragmento de la dirección: `clave=valor` unidos con
/// `&`, cada valor en JSON y codificado como `encodeURIComponent`, que es
/// como Jitsi los lee (`parseURLParams`).
String fragmentoDeAjustes(Map<String, Object> ajustes) => ajustes.entries
    .map((e) => '${e.key}=${Uri.encodeComponent(jsonEncode(e.value))}')
    .join('&');

/// La dirección que carga el WebView:
/// `https://<dominio>/<sala>?jwt=<token>&lang=es#<ajustes>`.
String direccionDeLaSala({
  required String dominio,
  required String sala,
  required String token,
  String asunto = '',
}) {
  final consulta =
      'jwt=${Uri.encodeQueryComponent(token)}'
      '&lang=$idiomaDeLaSala';

  return 'https://$dominio/${Uri.encodeComponent(sala)}?$consulta'
      '#${fragmentoDeAjustes(ajustesDeJitsi(asunto: asunto))}';
}

/// Qué se hace con una navegación del WebView de la sala.
enum DecisionDeNavegacion {
  /// Es la sala: se carga.
  permitir,

  /// Otro sitio (jitsi.org, un enlace, otra aplicación): no se carga y la
  /// persona sigue en la sala.
  bloquear,

  /// El servidor de video lleva fuera de la sala (la página de bienvenida,
  /// la de cierre, otra sala): la videoconsulta terminó. No se carga y la
  /// pantalla se cierra.
  terminar,
}

/// Decide una navegación del WebView de la sala.
///
/// En la página principal solo se carga `https://<dominio>/<sala>` (con
/// cualquier consulta o fragmento; la sala sin distinguir mayúsculas, como
/// Jitsi). El mismo servidor en otra ruta es el fin de la sala: Jitsi lleva
/// a la bienvenida o a `static/close.html` al colgar. Todo lo demás se
/// bloquea.
///
/// Dentro de un iframe se deja el mismo servidor y los marcos vacíos
/// (`about:blank`, `about:srcdoc`); nada más.
DecisionDeNavegacion decidirNavegacion(
  Uri destino, {
  required String dominio,
  required String sala,
  bool marcoPrincipal = true,
}) {
  if (!marcoPrincipal) {
    if (destino.scheme.toLowerCase() == 'about') {
      return DecisionDeNavegacion.permitir;
    }
    return esDelServidor(destino, dominio)
        ? DecisionDeNavegacion.permitir
        : DecisionDeNavegacion.bloquear;
  }

  if (!esDelServidor(destino, dominio)) return DecisionDeNavegacion.bloquear;

  return _esLaSala(destino, sala)
      ? DecisionDeNavegacion.permitir
      : DecisionDeNavegacion.terminar;
}

/// Si la dirección es del servidor de video: `https`, el mismo nombre y el
/// mismo puerto.
bool esDelServidor(Uri? direccion, String dominio) {
  if (direccion == null || direccion.scheme.toLowerCase() != 'https') {
    return false;
  }

  final servidor = Uri.tryParse('https://$dominio');
  if (servidor == null || servidor.host.isEmpty) return false;

  return direccion.host.toLowerCase() == servidor.host.toLowerCase() &&
      direccion.port == servidor.port;
}

bool _esLaSala(Uri direccion, String sala) {
  String ruta;
  try {
    ruta = Uri.decodeComponent(direccion.path);
  } on ArgumentError {
    return false;
  }

  ruta = ruta.replaceAll(RegExp(r'/+$'), '');
  return ruta.toLowerCase() == '/${sala.toLowerCase()}';
}

/// Si la página pide la cámara o el micrófono desde el servidor de video: a
/// ese, y solo a ese, se le conceden sin volver a preguntar (la aplicación
/// ya pidió el permiso al sistema).
bool esOrigenDeLaSala(Uri? origen, String dominio) =>
    esDelServidor(origen, dominio);

/// Si un error del WebView es que la sala no cargó: el de la página
/// principal (iOS no lo dice: solo avisa de esos), de la dirección de la
/// sala y que no sea una carga cancelada. Las navegaciones que se bloquean
/// también llegan como error en iOS, y esas no cuentan.
bool esFalloDeCarga(
  Uri? direccion, {
  required String dominio,
  required String sala,
  bool? marcoPrincipal,
  bool cancelado = false,
}) {
  if (cancelado || marcoPrincipal == false || direccion == null) return false;

  return decidirNavegacion(direccion, dominio: dominio, sala: sala) ==
      DecisionDeNavegacion.permitir;
}

/// Lo que cuenta la página de la sala a la aplicación.
enum EventoDeSala {
  /// Entró a la conferencia (`videoConferenceJoined`).
  dentro,

  /// Colgó, la echaron o el médico terminó la sala (`readyToClose` o
  /// `videoConferenceLeft`): se cierra la pantalla.
  terminada,
}

/// El manejador de JavaScript con que la página avisa a la aplicación
/// (`window.flutter_inappwebview.callHandler`).
const String manejadorDeLaSala = 'salaCliniq';

/// Lee lo que mandó la página al [manejadorDeLaSala]; `null` si no es nada
/// conocido.
EventoDeSala? leerEventoDeSala(List<dynamic> argumentos) {
  if (argumentos.isEmpty) return null;

  return switch (argumentos.first) {
    'dentro' => EventoDeSala.dentro,
    'terminada' => EventoDeSala.terminada,
    _ => null,
  };
}

/// Lo que se oculta de la página de Jitsi: sus marcas de agua y el «powered
/// by», que además llevan a jitsi.org.
const String estiloDeLaSala =
    '.watermark,.leftwatermark,.rightwatermark,.poweredby'
    '{display:none!important}';

/// El guion que se inyecta en la página de la sala, al empezar a cargarla y
/// solo en el marco principal del servidor de video.
///
/// - Oculta las marcas de Jitsi ([estiloDeLaSala]).
/// - Escucha los eventos de la API de Jitsi. La página los publica en su
///   propia ventana (sin iframe, la ventana «de afuera» es ella misma; la
///   API se enciende sola porque la dirección trae `jwt`): con
///   `video-conference-joined` avisa `dentro`; con `video-ready-to-close`
///   —el `readyToClose` de la API— o `video-conference-left`, avisa
///   `terminada`. Jitsi también publica `video-conference-left` al
///   recargarse la página: ese no cuenta.
String guionDeLaSala(String dominio) {
  final servidor = Uri.tryParse('https://$dominio');
  final host = jsonEncode((servidor?.host ?? dominio).toLowerCase());

  return '''
(function () {
  if (window.__salaCliniq || window.top !== window) return;
  window.__salaCliniq = true;
  if (String(location.hostname).toLowerCase() !== $host) return;

  var estilo = ${jsonEncode(estiloDeLaSala)};
  function ponerEstilo() {
    var raiz = document.head || document.documentElement;
    if (!raiz) { setTimeout(ponerEstilo, 50); return; }
    var hoja = document.createElement('style');
    hoja.textContent = estilo;
    raiz.appendChild(hoja);
  }
  ponerEstilo();

  function avisar(evento) {
    try {
      window.flutter_inappwebview.callHandler(${jsonEncode(manejadorDeLaSala)}, evento);
    } catch (e) {}
  }

  var descargando = false;
  var dentro = false;
  var terminada = false;
  window.addEventListener('beforeunload', function () { descargando = true; });
  window.addEventListener('pagehide', function () { descargando = true; });

  window.addEventListener('message', function (e) {
    if (e.source !== window) return;
    var datos = e.data;
    if (typeof datos === 'string') {
      try { datos = JSON.parse(datos); } catch (_) { return; }
    }
    if (!datos || datos.postis !== true || datos.method !== 'message') return;
    var mensaje = datos.params;
    if (!mensaje || mensaje.type !== 'event' || !mensaje.data) return;
    var nombre = mensaje.data.name;

    if (nombre === 'video-conference-joined' && !dentro) {
      dentro = true;
      avisar('dentro');
    } else if (!terminada && (nombre === 'video-ready-to-close'
        || (nombre === 'video-conference-left' && !descargando))) {
      terminada = true;
      avisar('terminada');
    }
  });
})();
''';
}
