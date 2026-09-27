// test/dobles/vista_web.dart

import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/web/vista_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hace de WebView: en el anfitrión de pruebas no hay uno de verdad.
///
/// Anota qué direcciones se cargaron y deja a la prueba contar lo que la
/// página contaría (su título, que no cargó, un `tel:` tocado) con el
/// [oyente] de la última vista.
class VistaWebFalsa extends FabricaDeVistaWeb {
  /// El título que «tiene» la página; `null`, ninguno.
  final String? tituloDeLaPagina;

  final List<Uri> cargadas = [];
  final ControlFalso control = ControlFalso();
  OyenteDeVistaWeb? oyente;

  VistaWebFalsa({this.tituloDeLaPagina});

  /// La pone en `Servicios.vistaWeb` hasta que termine la prueba.
  void instalar() {
    Servicios.vistaWebParaPruebas = this;
    addTearDown(
      () => Servicios.vistaWebParaPruebas = const VistaWebDelSistema(),
    );
  }

  @override
  Widget construir(Uri direccion, OyenteDeVistaWeb oyente) {
    this.oyente = oyente;
    return _VistaFalsa(direccion: direccion, fabrica: this);
  }
}

/// Lo que la pantalla le pidió a la vista.
class ControlFalso implements ControlDeVistaWeb {
  int vueltasAtras = 0;
  int recargas = 0;

  @override
  Future<void> volver() async => vueltasAtras++;

  @override
  Future<void> recargar() async => recargas++;
}

class _VistaFalsa extends StatefulWidget {
  final Uri direccion;
  final VistaWebFalsa fabrica;

  const _VistaFalsa({required this.direccion, required this.fabrica});

  @override
  State<_VistaFalsa> createState() => _VistaFalsaState();
}

class _VistaFalsaState extends State<_VistaFalsa> {
  @override
  void initState() {
    super.initState();
    // Una vista nueva es una carga nueva (volver a pintar la pantalla no).
    widget.fabrica.cargadas.add(widget.direccion);

    // Como el WebView: avisa después de crearse y al terminar de cargar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final oyente = widget.fabrica.oyente;
      if (!mounted || oyente == null) return;

      oyente.alCrear(widget.fabrica.control);
      oyente.alAvanzar(1);
      final titulo = widget.fabrica.tituloDeLaPagina;
      if (titulo != null) oyente.alCambiarTitulo(titulo);
    });
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'Página ${widget.direccion}',
      key: const Key('vista-web-falsa'),
    ),
  );
}
