// lib/core/tema/paleta_marca.dart

import 'package:flutter/painting.dart';

import 'contraste.dart';

/// Los colores de la marca de la clínica y los tonos que salen de ellos.
///
/// La marca son dos colores: el primario (la calma) y el acento (la acción).
/// Los elige el administrador (`clinica.colorPrimario`, `clinica.colorAcento`)
/// y, si no los configuró, son los de siempre: el gris azulado `#5A6E73` y
/// el terracota `#D16F4B`. Los tonos claros, los de los encabezados y los
/// del saludo se derivan con el mismo criterio con que se hicieron los de
/// siempre: la misma diferencia de tono, saturación y luz respecto de su
/// color base.
///
/// Además, la clínica puede elegir el fondo, la barra lateral y el texto
/// sobre el primario (`clinica.colorFondo`, `colorBarraLateral`,
/// `colorTextoSobrePrimario`). La aplicación es oscura siempre, así que del
/// fondo y de la barra toma el tono y les da la oscuridad de los de siempre
/// (ver `oscurecerComo`): los textos blancos se siguen leyendo. La barra
/// lateral del panel es, en la aplicación, la de arriba y la de abajo
/// (`superficie`). El texto sobre el primario va en la acción principal,
/// si se lee sobre el acento.
///
/// Los estados (éxito, alerta, peligro), las tarjetas y los demás textos no
/// son de la marca y no cambian.
class PaletaMarca {
  final Color primario;
  final Color primarioClaro;
  final Color acento;
  final Color acentoClaro;
  final Color acentoSuave;

  /// Encabezado de sección: del tono de la marca hacia el fondo.
  final List<Color> encabezado;

  /// La tarjeta de identidad del perfil, un punto más oscura.
  final List<Color> identidad;

  /// El saludo del inicio: del primario oscurecido al acento.
  final List<Color> bienvenida;

  /// El fondo de las pantallas y los dos tonos de arriba de su degradado.
  final Color fondo;
  final Color fondoDegradadoInicio;
  final Color fondoDegradadoMedio;

  /// Las barras de arriba y de abajo y las hojas que suben.
  final Color superficie;

  /// El texto y los iconos de la acción principal.
  final Color textoSobreAccion;

  const PaletaMarca({
    required this.primario,
    required this.primarioClaro,
    required this.acento,
    required this.acentoClaro,
    required this.acentoSuave,
    required this.encabezado,
    required this.identidad,
    required this.bienvenida,
    this.fondo = _fondo,
    this.fondoDegradadoInicio = _fondoDegradadoInicio,
    this.fondoDegradadoMedio = _fondoDegradadoMedio,
    this.superficie = _superficie,
    this.textoSobreAccion = _blanco,
  });

  static const Color _fondo = Color(0xFF0F171A);
  static const Color _fondoDegradadoInicio = Color(0xFF283A3E);
  static const Color _fondoDegradadoMedio = Color(0xFF192629);
  static const Color _superficie = Color(0xFF162022);
  static const Color _blanco = Color(0xFFFFFFFF);

  /// La de siempre: la que se usa si la clínica no configuró colores.
  static const PaletaMarca deSiempre = PaletaMarca(
    primario: Color(0xFF5A6E73),
    primarioClaro: Color(0xFF9DB3B8),
    acento: Color(0xFFD16F4B),
    acentoClaro: Color(0xFFE8956F),
    acentoSuave: Color(0xFFF3C3AA),
    encabezado: [Color(0xFF62797F), Color(0xFF465A5F), Color(0xFF2B393C)],
    identidad: [Color(0xFF556A70), Color(0xFF3A4B50), Color(0xFF243034)],
    bienvenida: [
      Color(0xFF465A5F),
      Color(0xFF5A6E73),
      Color(0xFF966E5F),
      Color(0xFFD16F4B),
    ],
  );

  /// La paleta en uso. La cambia [aplicar] con cada configuración.
  static PaletaMarca actual = deSiempre;

  /// Aplica los colores de la configuración (`#RRGGBB` o `null`). Devuelve si
  /// la paleta cambió, para que la aplicación se vuelva a pintar.
  static bool aplicar({
    String? primario,
    String? acento,
    String? fondo,
    String? barra,
    String? textoSobrePrimario,
  }) {
    final nueva = PaletaMarca.desde(
      primario: _color(primario),
      acento: _color(acento),
      fondo: _color(fondo),
      barra: _color(barra),
      textoSobrePrimario: _color(textoSobrePrimario),
    );
    if (nueva == actual) return false;

    actual = nueva;
    return true;
  }

  /// La paleta de estos colores; el que falte, el de siempre.
  factory PaletaMarca.desde({
    Color? primario,
    Color? acento,
    Color? fondo,
    Color? barra,
    Color? textoSobrePrimario,
  }) {
    const base = deSiempre;
    final p = primario ?? base.primario;
    final a = acento ?? base.acento;

    final mismoPrimario = _igual(p, base.primario);
    final mismoAcento = _igual(a, base.acento);
    final sinFondos =
        fondo == null && barra == null && textoSobrePrimario == null;
    if (mismoPrimario && mismoAcento && sinFondos) return base;

    List<Color> desdePrimario(List<Color> tonos) => mismoPrimario
        ? tonos
        : [for (final t in tonos) _derivar(t, base.primario, p)];

    Color desdeAcento(Color tono) =>
        mismoAcento ? tono : _derivar(tono, base.acento, a);

    final bienvenida = desdePrimario([base.bienvenida[0]]).first;

    // El fondo: el de la clínica, oscuro; sus tonos, con el mismo criterio
    // que los del primario. La barra, la suya; sin ella, la del fondo.
    final f = fondo == null ? base.fondo : oscurecerComo(fondo, base.fondo);
    Color desdeFondo(Color tono) =>
        _igual(f, base.fondo) ? tono : _derivar(tono, base.fondo, f);

    return PaletaMarca(
      primario: p,
      primarioClaro: desdePrimario([base.primarioClaro]).first,
      acento: a,
      acentoClaro: desdeAcento(base.acentoClaro),
      acentoSuave: desdeAcento(base.acentoSuave),
      encabezado: desdePrimario(base.encabezado),
      identidad: desdePrimario(base.identidad),
      bienvenida: [
        bienvenida,
        p,
        // El tono de paso entre los dos, como el de siempre.
        Color.lerp(p, a, 0.55)!,
        a,
      ],
      fondo: f,
      fondoDegradadoInicio: desdeFondo(base.fondoDegradadoInicio),
      fondoDegradadoMedio: desdeFondo(base.fondoDegradadoMedio),
      superficie: barra == null
          ? desdeFondo(base.superficie)
          : oscurecerComo(barra, base.superficie),
      textoSobreAccion: textoLegibleSobre(a, preferido: textoSobrePrimario),
    );
  }

  static Color? _color(String? hex) => colorHex(hex);

  static bool _igual(Color a, Color b) => a.toARGB32() == b.toARGB32();

  /// El tono [derivado] de [base] llevado a [nuevo]: la misma diferencia de
  /// tono y de luz, y la saturación en la misma proporción.
  static Color _derivar(Color derivado, Color base, Color nuevo) {
    final d = HSLColor.fromColor(derivado);
    final b = HSLColor.fromColor(base);
    final n = HSLColor.fromColor(nuevo);

    final proporcion = b.saturation == 0 ? 1.0 : d.saturation / b.saturation;

    return HSLColor.fromAHSL(
      1,
      (n.hue + d.hue - b.hue) % 360,
      (n.saturation * proporcion).clamp(0.0, 1.0),
      (n.lightness + d.lightness - b.lightness).clamp(0.0, 1.0),
    ).toColor();
  }

  @override
  bool operator ==(Object other) =>
      other is PaletaMarca &&
      _igual(other.primario, primario) &&
      _igual(other.acento, acento) &&
      _igual(other.fondo, fondo) &&
      _igual(other.superficie, superficie) &&
      _igual(other.textoSobreAccion, textoSobreAccion);

  @override
  int get hashCode => Object.hash(
    primario.toARGB32(),
    acento.toARGB32(),
    fondo.toARGB32(),
    superficie.toARGB32(),
    textoSobreAccion.toARGB32(),
  );
}
