// lib/core/presentacion/margenes.dart

import 'package:flutter/material.dart';

/// Márgenes que respetan lo que el sistema operativo ocupa en pantalla.
extension MargenesDelSistema on BuildContext {
  /// Alto de la barra de navegación de Android (o de la barra de gestos).
  ///
  /// Se usa `viewPadding` y no `padding` a propósito: `padding` se pone en
  /// cero cuando el teclado está abierto, y entonces el último campo de un
  /// formulario volvería a quedar debajo de la barra al cerrarlo.
  double get margenInferiorDelSistema => MediaQuery.viewPaddingOf(this).bottom;

  /// Relleno de una lista o formulario con desplazamiento, ya descontada la
  /// barra del sistema. Un `EdgeInsets` fijo deja la última tarjeta medio
  /// tapada.
  EdgeInsets margenDeScroll({
    double horizontal = 20,
    double superior = 20,
    double inferior = 20,
  }) {
    return EdgeInsets.fromLTRB(
      horizontal,
      superior,
      horizontal,
      inferior + margenInferiorDelSistema,
    );
  }
}
