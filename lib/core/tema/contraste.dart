// lib/core/tema/contraste.dart

import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// El contraste entre dos colores según WCAG 2 (de 1 a 21).
///
/// 4.5 es el mínimo para un texto normal y 3 para uno grande o un icono.
double contrasteEntre(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();

  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [color] llevado a la oscuridad de [referencia], con su tono.
///
/// La aplicación es oscura siempre: sus textos son blancos. Un fondo claro
/// del panel (el `#F8FAFC` de tantas marcas) no puede ir tal cual detrás de
/// ellos, así que se toma su tono y se le da la luz del fondo de siempre;
/// uno que ya es oscuro se queda como está. La saturación se modera para
/// que el fondo no compita con la marca.
Color oscurecerComo(Color color, Color referencia, {double saturacion = 0.6}) {
  final c = HSLColor.fromColor(color);
  final r = HSLColor.fromColor(referencia);

  if (c.lightness <= r.lightness) return color.withValues(alpha: 1);

  return HSLColor.fromAHSL(
    1,
    c.hue,
    math.min(c.saturation, saturacion),
    r.lightness,
  ).toColor();
}

/// El texto que va sobre [fondo] cuando la clínica eligió [preferido].
///
/// Sin preferido, el blanco de siempre. Con uno que se lee (contraste de 3,
/// el de un botón con letra gruesa), ese. Con uno que no se lee, el blanco
/// o el negro, el que más contraste dé: un botón ilegible no es una marca.
Color textoLegibleSobre(Color fondo, {Color? preferido}) {
  const blanco = Color(0xFFFFFFFF);
  const negro = Color(0xFF111111);

  if (preferido == null) return blanco;
  if (contrasteEntre(preferido, fondo) >= 3) {
    return preferido.withValues(alpha: 1);
  }

  return contrasteEntre(blanco, fondo) >= contrasteEntre(negro, fondo)
      ? blanco
      : negro;
}

/// Un color escrito `#RRGGBB` o `#RGB` (con o sin `#`), o `null` si no lo es.
Color? colorHex(String? hex) {
  var texto = hex?.trim() ?? '';
  if (texto.startsWith('#')) texto = texto.substring(1);
  if (texto.length == 3) texto = texto.split('').map((c) => '$c$c').join();
  if (texto.length != 6) return null;

  final valor = int.tryParse(texto, radix: 16);
  return valor == null ? null : Color(0xFF000000 | valor);
}
