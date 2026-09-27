// lib/core/web/vista_web.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'navegacion_web.dart';

/// Lo que la página cuenta a la pantalla que la muestra.
class OyenteDeVistaWeb {
  /// La vista está lista: con esto se vuelve atrás o se recarga.
  final ValueChanged<ControlDeVistaWeb> alCrear;

  /// El título de la página cambió.
  final ValueChanged<String> alCambiarTitulo;

  /// La dirección que se está viendo cambió (se navegó dentro de la página).
  final ValueChanged<Uri> alCambiarDireccion;

  /// Cuánto va la carga, de 0 a 1.
  final ValueChanged<double> alAvanzar;

  /// Si hay una página anterior dentro de la vista.
  final ValueChanged<bool> alCambiarHistorial;

  /// Se tocó un `tel:` o un `mailto:`.
  final ValueChanged<Uri> alPedirContacto;

  /// La página no cargó (sin red, el servidor no existe).
  final ValueChanged<Uri> alFallar;

  const OyenteDeVistaWeb({
    required this.alCrear,
    required this.alCambiarTitulo,
    required this.alCambiarDireccion,
    required this.alAvanzar,
    required this.alCambiarHistorial,
    required this.alPedirContacto,
    required this.alFallar,
  });
}

/// Lo que la pantalla le puede pedir a la vista.
abstract class ControlDeVistaWeb {
  /// Vuelve a la página anterior dentro de la vista.
  Future<void> volver();

  Future<void> recargar();
}

/// Cómo se arma la vista de una página web. La de verdad es el WebView;
/// las pruebas ponen una de mentira (en el anfitrión de pruebas no hay
/// WebView).
abstract class FabricaDeVistaWeb {
  const FabricaDeVistaWeb();

  Widget construir(Uri direccion, OyenteDeVistaWeb oyente);
}

/// La página en un WebView de la propia aplicación (`flutter_inappwebview`,
/// el mismo de la videoconsulta). Es el único archivo de las páginas web
/// que conoce el WebView.
///
/// Se navega dentro de la página como en cualquier navegador; las ventanas
/// nuevas se abren en la misma vista; `tel:` y `mailto:` van al marcador o
/// al correo del teléfono, y nada más sale de la aplicación
/// ([decidirNavegacionWeb]). La página no recibe permisos (cámara,
/// micrófono, ubicación) ni puente con la aplicación.
class VistaWebDelSistema extends FabricaDeVistaWeb {
  const VistaWebDelSistema();

  @override
  Widget construir(Uri direccion, OyenteDeVistaWeb oyente) =>
      _VistaWeb(direccion: direccion, oyente: oyente);
}

class _VistaWeb extends StatefulWidget {
  final Uri direccion;
  final OyenteDeVistaWeb oyente;

  const _VistaWeb({required this.direccion, required this.oyente});

  @override
  State<_VistaWeb> createState() => _VistaWebState();
}

class _VistaWebState extends State<_VistaWeb> {
  final InAppWebViewSettings _ajustes = InAppWebViewSettings(
    javaScriptEnabled: true,
    useShouldOverrideUrlLoading: true,
    // Las ventanas nuevas (target=_blank, window.open) se cargan en la
    // misma vista: en Android, sin varias ventanas; en iOS, por
    // onCreateWindow.
    supportMultipleWindows: false,
    javaScriptCanOpenWindowsAutomatically: false,
    allowsBackForwardNavigationGestures: true,
    allowsLinkPreview: false,
    // En Android, sin la página de error de Chrome: la pantalla pone la
    // suya, con «Reintentar».
    disableDefaultErrorPage: true,
    geolocationEnabled: false,
    mediaPlaybackRequiresUserGesture: true,
    isInspectable: kDebugMode,
  );

  OyenteDeVistaWeb get _oyente => widget.oyente;

  static bool? _tocado(NavigationAction accion) {
    if (accion.hasGesture case final gesto?) return gesto;

    final tipo = accion.navigationType;
    if (tipo == null) return null;
    return tipo == NavigationType.LINK_ACTIVATED;
  }

  NavigationActionPolicy _aplicar(DecisionWeb decision, Uri destino) {
    switch (decision) {
      case DecisionWeb.permitir:
        return NavigationActionPolicy.ALLOW;
      case DecisionWeb.abrirContacto:
        _oyente.alPedirContacto(destino);
        return NavigationActionPolicy.CANCEL;
      case DecisionWeb.bloquear:
        return NavigationActionPolicy.CANCEL;
    }
  }

  Future<NavigationActionPolicy> _decidir(NavigationAction accion) async {
    final destino = accion.request.url;
    if (destino == null) return NavigationActionPolicy.CANCEL;

    final decision = decidirNavegacionWeb(
      destino,
      marcoPrincipal: accion.isForMainFrame,
      tocado: _tocado(accion),
    );

    return _aplicar(decision, destino);
  }

  Future<bool> _ventanaNueva(
    InAppWebViewController controlador,
    CreateWindowAction accion,
  ) async {
    final destino = accion.request.url;

    switch (decidirVentanaNueva(destino, tocado: _tocado(accion))) {
      case DecisionWeb.permitir:
        await controlador.loadUrl(urlRequest: URLRequest(url: destino));
      case DecisionWeb.abrirContacto:
        _oyente.alPedirContacto(destino!);
      case DecisionWeb.bloquear:
        break;
    }

    // Atendida: no se abre ninguna ventana.
    return true;
  }

  Future<void> _revisarHistorial(InAppWebViewController controlador) async {
    try {
      _oyente.alCambiarHistorial(await controlador.canGoBack());
    } catch (_) {
      // La vista ya no existe: no hay nada que decir.
    }
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri.uri(widget.direccion)),
      initialSettings: _ajustes,
      onWebViewCreated: (controlador) =>
          _oyente.alCrear(_ControlInApp(controlador)),
      shouldOverrideUrlLoading: (_, accion) => _decidir(accion),
      onCreateWindow: _ventanaNueva,
      onPermissionRequest: (_, _) async =>
          PermissionResponse(action: PermissionResponseAction.DENY),
      onTitleChanged: (_, titulo) {
        if (titulo != null) _oyente.alCambiarTitulo(titulo);
      },
      onProgressChanged: (_, progreso) => _oyente.alAvanzar(progreso / 100),
      onUpdateVisitedHistory: (controlador, direccion, _) {
        if (direccion != null) _oyente.alCambiarDireccion(direccion);
        _revisarHistorial(controlador);
      },
      onReceivedError: (_, pedido, error) {
        final cancelado = error.type == WebResourceErrorType.CANCELLED;
        if (esFalloDeCargaWeb(
          pedido.url,
          marcoPrincipal: pedido.isForMainFrame,
          cancelado: cancelado,
        )) {
          _oyente.alFallar(pedido.url);
        }
      },
      onRenderProcessGone: (_, _) => _oyente.alFallar(widget.direccion),
      onWebContentProcessDidTerminate: (_) =>
          _oyente.alFallar(widget.direccion),
    );
  }
}

class _ControlInApp implements ControlDeVistaWeb {
  final InAppWebViewController _controlador;

  _ControlInApp(this._controlador);

  @override
  Future<void> volver() => _controlador.goBack();

  @override
  Future<void> recargar() => _controlador.reload();
}
