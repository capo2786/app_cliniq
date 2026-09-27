// lib/core/tema/paleta_marca.dart

import 'package:flutter/painting.dart';

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
/// Los fondos oscuros, los estados (éxito, alerta, peligro) y los textos no
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

  const PaletaMarca({
    required this.primario,
    required this.primarioClaro,
    required this.acento,
    required this.acentoClaro,
    required this.acentoSuave,
    required this.encabezado,
    required this.identidad,
    required this.bienvenida,
  });

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
  static bool aplicar({String? primario, String? acento}) {
    final nueva = PaletaMarca.desde(
      primario: _color(primario),
      acento: _color(acento),
    );
    if (nueva == actual) return false;

    actual = nueva;
    return true;
  }

  /// La paleta de estos dos colores; el que falte, el de siempre.
  factory PaletaMarca.desde({Color? primario, Color? acento}) {
    const base = deSiempre;
    final p = primario ?? base.primario;
    final a = acento ?? base.acento;

    final mismoPrimario = _igual(p, base.primario);
    final mismoAcento = _igual(a, base.acento);
    if (mismoPrimario && mismoAcento) return base;

    List<Color> desdePrimario(List<Color> tonos) => mismoPrimario
        ? tonos
        : [for (final t in tonos) _derivar(t, base.primario, p)];

    Color desdeAcento(Color tono) =>
        mismoAcento ? tono : _derivar(tono, base.acento, a);

    final bienvenida = desdePrimario([base.bienvenida[0]]).first;

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
    );
  }

  static Color? _color(String? hex) {
    var texto = hex?.trim() ?? '';
    if (texto.startsWith('#')) texto = texto.substring(1);
    if (texto.length == 3) texto = texto.split('').map((c) => '$c$c').join();
    if (texto.length != 6) return null;

    final valor = int.tryParse(texto, radix: 16);
    return valor == null ? null : Color(0xFF000000 | valor);
  }

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
      _igual(other.acento, acento);

  @override
  int get hashCode => Object.hash(primario.toARGB32(), acento.toARGB32());
}
