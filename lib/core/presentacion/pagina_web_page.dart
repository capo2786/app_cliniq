// lib/core/presentacion/pagina_web_page.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../servicios.dart';
import '../tema/tokens.dart';
import '../web/navegacion_web.dart';
import '../web/vista_web.dart';
import 'enlaces.dart';
import 'widgets/estados.dart';
import 'widgets/fondo_app.dart';

/// Una página de fuera dentro de la aplicación: un enlace externo del menú
/// que puso el administrador, un enlace web de un artículo de ayuda o de un
/// documento legal.
///
/// Va bajo la cabecera de Cliniq —el título y «Cerrar»— en un WebView
/// propio: sin Chrome Custom Tabs, sin Safari y sin el navegador del
/// teléfono. Dentro de la página se navega como siempre; el botón atrás
/// vuelve a la página anterior y, en la primera, cierra. [titulo] es el
/// nombre del enlace, si lo hay; si no, el de la página.
class PaginaWebPage extends StatefulWidget {
  final Uri direccion;
  final String? titulo;

  /// Sin ella, la de `Servicios.vistaWeb` (el WebView).
  final FabricaDeVistaWeb? fabrica;

  const PaginaWebPage({
    super.key,
    required this.direccion,
    this.titulo,
    this.fabrica,
  });

  @override
  State<PaginaWebPage> createState() => _PaginaWebPageState();
}

class _PaginaWebPageState extends State<PaginaWebPage> {
  late Uri _aCargar = widget.direccion;
  late Uri _actual = widget.direccion;
  String? _tituloDeLaPagina;
  double _progreso = 0;
  bool _puedeVolver = false;
  bool _fallo = false;

  /// Cada «Reintentar» arma una vista nueva.
  int _intento = 0;

  ControlDeVistaWeb? _control;

  late final OyenteDeVistaWeb _oyente = OyenteDeVistaWeb(
    alCrear: (control) => _control = control,
    alCambiarTitulo: (titulo) => _si(() => _tituloDeLaPagina = titulo),
    alCambiarDireccion: (direccion) => _si(() => _actual = direccion),
    alAvanzar: (progreso) => _si(() => _progreso = progreso),
    alCambiarHistorial: (puede) => _si(() => _puedeVolver = puede),
    alPedirContacto: (direccion) {
      if (mounted) unawaited(abrirContacto(context, direccion));
    },
    alFallar: (direccion) => _si(() {
      _aCargar = direccion;
      _fallo = true;
    }),
  );

  void _si(VoidCallback cambio) {
    if (mounted) setState(cambio);
  }

  void _reintentar() {
    setState(() {
      _fallo = false;
      _progreso = 0;
      _puedeVolver = false;
      _control = null;
      _intento++;
    });
  }

  void _cerrar() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final titulo = tituloDePaginaWeb(
      direccion: _actual,
      pedido: widget.titulo,
      deLaPagina: _tituloDeLaPagina,
    );

    return PopScope(
      // Con páginas anteriores, atrás vuelve a la anterior; en la primera
      // (o si no cargó), cierra.
      canPop: _fallo || !_puedeVolver,
      onPopInvokedWithResult: (seFue, _) {
        if (!seFue) unawaited(_control?.volver());
      },
      child: Scaffold(
        backgroundColor: AppColors.fondo,
        appBar: _Cabecera(
          titulo: titulo,
          direccion: _actual,
          progreso: _fallo ? 1 : _progreso,
          alCerrar: _cerrar,
          alRecargar: _fallo ? _reintentar : () => _control?.recargar(),
        ),
        body: _fallo
            ? FondoDegradado(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    EstadoError(
                      key: const Key('error-pagina-web'),
                      mensaje:
                          'No pudimos abrir ${servidorVisible(_aCargar)}. '
                          'Revisa tu conexión e intenta de nuevo.',
                      alReintentar: _reintentar,
                    ),
                  ],
                ),
              )
            : KeyedSubtree(
                key: ValueKey('vista-web-$_intento'),
                child: (widget.fabrica ?? Servicios.vistaWeb).construir(
                  _aCargar,
                  _oyente,
                ),
              ),
      ),
    );
  }
}

/// La cabecera de Cliniq sobre la página: cerrar, el título con el servidor
/// debajo (con el candado si la conexión es segura), recargar y la barra de
/// carga.
class _Cabecera extends StatelessWidget implements PreferredSizeWidget {
  final String titulo;
  final Uri direccion;
  final double progreso;
  final VoidCallback alCerrar;
  final VoidCallback alRecargar;

  const _Cabecera({
    required this.titulo,
    required this.direccion,
    required this.progreso,
    required this.alCerrar,
    required this.alRecargar,
  });

  static const double _altoBarra = 2;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + _altoBarra);

  @override
  Widget build(BuildContext context) {
    final segura = direccion.scheme.toLowerCase() == 'https';

    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        key: const Key('cerrar-pagina-web'),
        tooltip: 'Cerrar',
        icon: const Icon(Icons.close_rounded),
        onPressed: alCerrar,
      ),
      titleSpacing: 0,
      title: Semantics(
        header: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titulo,
              key: const Key('titulo-pagina-web'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.texto,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  segura ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 12,
                  color: AppColors.textoSecundario,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    servidorVisible(direccion),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textoSecundario,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          key: const Key('recargar-pagina-web'),
          tooltip: 'Recargar',
          icon: const Icon(Icons.refresh_rounded),
          onPressed: alRecargar,
        ),
        const SizedBox(width: 4),
      ],
      // Cargada la página, la barra se quita (no se oculta): una barra sin
      // fin seguiría pidiendo cuadros aunque no se viera.
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(_altoBarra),
        child: progreso < 1
            ? LinearProgressIndicator(
                value: progreso <= 0 ? null : progreso,
                minHeight: _altoBarra,
                color: AppColors.acentoClaro,
                backgroundColor: Colors.transparent,
              )
            : const SizedBox(height: _altoBarra),
      ),
    );
  }
}
