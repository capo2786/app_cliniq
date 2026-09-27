// lib/features/citas/data/sala_jitsi.dart

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../dominio/sala_embebida.dart';
import 'videollamada_service.dart';

/// La sala de video de verdad: la página de Jitsi de la clínica en un
/// WebView de la propia aplicación (`flutter_inappwebview`). Es el único
/// archivo que conoce el WebView.
///
/// Nada sale de la pantalla: la página solo navega dentro de la sala
/// (`decidirNavegacion`), las ventanas nuevas no se abren, y la cámara y el
/// micrófono se conceden solo al servidor de video. Las decisiones son
/// funciones puras de `dominio/sala_embebida.dart`, probadas sin WebView.
class SalaJitsi implements SalaDeVideo {
  const SalaJitsi();

  @override
  Widget construir(
    DatosDeSala datos, {
    required String asunto,
    required OyenteDeSala oyente,
  }) => VistaJitsi(datos: datos, asunto: asunto, oyente: oyente);
}

/// El WebView de la sala.
class VistaJitsi extends StatefulWidget {
  final DatosDeSala datos;
  final String asunto;
  final OyenteDeSala oyente;

  const VistaJitsi({
    super.key,
    required this.datos,
    required this.asunto,
    required this.oyente,
  });

  @override
  State<VistaJitsi> createState() => _VistaJitsiState();
}

class _VistaJitsiState extends State<VistaJitsi> {
  static const String _noCargo =
      'No pudimos abrir la sala de video. Revisa tu conexión e intenta de '
      'nuevo.';
  static const String _seCerro =
      'La sala de video se cerró de forma inesperada. Intenta de nuevo.';

  String get _dominio => widget.datos.dominio;
  String get _sala => widget.datos.sala;

  late final String _direccion = direccionDeLaSala(
    dominio: _dominio,
    sala: _sala,
    token: widget.datos.token,
    asunto: widget.asunto,
  );

  late final UnmodifiableListView<UserScript> _guiones = UnmodifiableListView([
    UserScript(
      groupName: 'salaCliniq',
      source: guionDeLaSala(_dominio),
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      forMainFrameOnly: true,
      allowedOriginRules: {'https://$_dominio'},
    ),
  ]);

  final InAppWebViewSettings _ajustes = InAppWebViewSettings(
    javaScriptEnabled: true,
    useShouldOverrideUrlLoading: true,
    // WebRTC: el video va dentro de la página y suena sin tocar nada.
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    allowsPictureInPictureMediaPlayback: false,
    allowsAirPlayForMediaPlayback: false,
    iframeAllow: 'camera; microphone; autoplay',
    // Las ventanas nuevas (target=_blank, window.open) pasan por
    // onCreateWindow, que no abre ninguna.
    supportMultipleWindows: true,
    javaScriptCanOpenWindowsAutomatically: false,
    // Que la sala no parezca una página: sin gestos de atrás, zoom ni
    // menús de enlace.
    allowsBackForwardNavigationGestures: false,
    allowsLinkPreview: false,
    disableLongPressContextMenuOnLinks: true,
    supportZoom: false,
    builtInZoomControls: false,
    // En Android, sin la página de error de Chrome: la pantalla pone la
    // suya, con «Reintentar».
    disableDefaultErrorPage: true,
    geolocationEnabled: false,
    isInspectable: kDebugMode,
  );

  bool _termino = false;

  void _terminar() {
    if (_termino) return;
    _termino = true;
    widget.oyente.alTerminar();
  }

  void _alRecibirEvento(List<dynamic> argumentos) {
    switch (leerEventoDeSala(argumentos)) {
      case EventoDeSala.dentro:
        widget.oyente.alEntrar();
      case EventoDeSala.terminada:
        _terminar();
      case null:
        break;
    }
  }

  Future<NavigationActionPolicy> _decidir(NavigationAction accion) async {
    final destino = accion.request.url;
    if (destino == null) return NavigationActionPolicy.CANCEL;

    final decision = decidirNavegacion(
      destino,
      dominio: _dominio,
      sala: _sala,
      marcoPrincipal: accion.isForMainFrame,
    );

    switch (decision) {
      case DecisionDeNavegacion.permitir:
        return NavigationActionPolicy.ALLOW;
      case DecisionDeNavegacion.bloquear:
        return NavigationActionPolicy.CANCEL;
      case DecisionDeNavegacion.terminar:
        _terminar();
        return NavigationActionPolicy.CANCEL;
    }
  }

  PermissionResponse _conceder(PermissionRequest pedido) {
    final medios = pedido.resources.where(_esMedio).toList();

    if (medios.isEmpty || !esOrigenDeLaSala(pedido.origin, _dominio)) {
      return PermissionResponse(action: PermissionResponseAction.DENY);
    }

    return PermissionResponse(
      resources: medios,
      action: PermissionResponseAction.GRANT,
    );
  }

  static bool _esMedio(PermissionResourceType recurso) =>
      recurso == PermissionResourceType.CAMERA ||
      recurso == PermissionResourceType.MICROPHONE ||
      recurso == PermissionResourceType.CAMERA_AND_MICROPHONE;

  bool _esFalloDeCarga(WebResourceRequest pedido, {bool cancelado = false}) =>
      esFalloDeCarga(
        pedido.url,
        dominio: _dominio,
        sala: _sala,
        marcoPrincipal: pedido.isForMainFrame,
        cancelado: cancelado,
      );

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(_direccion)),
      initialSettings: _ajustes,
      initialUserScripts: _guiones,
      onWebViewCreated: (controlador) => controlador.addJavaScriptHandler(
        handlerName: manejadorDeLaSala,
        callback: _alRecibirEvento,
      ),
      shouldOverrideUrlLoading: (_, accion) => _decidir(accion),
      // Ninguna ventana nueva: se da por atendida y no se abre.
      onCreateWindow: (_, _) async => true,
      onPermissionRequest: (_, pedido) async => _conceder(pedido),
      onLoadStop: (_, direccion) {
        if (direccion != null &&
            decidirNavegacion(direccion, dominio: _dominio, sala: _sala) ==
                DecisionDeNavegacion.permitir) {
          widget.oyente.alCargar();
        }
      },
      onReceivedError: (_, pedido, error) {
        final cancelado = error.type == WebResourceErrorType.CANCELLED;
        if (_esFalloDeCarga(pedido, cancelado: cancelado)) {
          widget.oyente.alFallar(_noCargo);
        }
      },
      onReceivedHttpError: (_, pedido, _) {
        if (pedido.isForMainFrame == true && _esFalloDeCarga(pedido)) {
          widget.oyente.alFallar(_noCargo);
        }
      },
      onRenderProcessGone: (_, _) => widget.oyente.alFallar(_seCerro),
      onWebContentProcessDidTerminate: (_) => widget.oyente.alFallar(_seCerro),
    );
  }
}
