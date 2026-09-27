import 'package:flutter/material.dart';

import 'paleta_marca.dart';

/// Sistema de diseño de Cliniq: colores, degradados, espaciados y radios.
///
/// Cada valor vive aquí una sola vez, con el nombre de su papel: las
/// pantallas dicen `AppColors.exito`, no "0xFF4ADE80", y un ajuste de marca se
/// hace en este archivo y en ningún otro.
///
/// La marca son dos colores: el primario, que es la calma de la clínica, y el
/// acento, que es la acción. Los elige el administrador en la configuración
/// (`clinica.colorPrimario`, `clinica.colorAcento`); si no los configuró son
/// los de siempre, el gris azulado `#5A6E73` y el terracota `#D16F4B`. Por
/// eso los de la marca no son constantes: salen de [PaletaMarca.actual]. Los
/// fondos, los estados y los textos sí lo son.
///
/// Regla para código nuevo: ningún `Color(0xFF...)` suelto en una pantalla.
/// Si hace falta un color que no está aquí, se agrega aquí con nombre.
class AppColors {
  const AppColors._();

  // ── Marca (de la configuración de la clínica) ───────────────────────
  /// El primario de la marca: el anillo del logotipo.
  static Color get primario => PaletaMarca.actual.primario;

  /// El primario aclarado, para iconos y detalles sobre fondo oscuro: el de
  /// la marca, tal cual, se pierde sobre el fondo profundo.
  static Color get primarioClaro => PaletaMarca.actual.primarioClaro;

  /// El acento de la marca: la cruz del logotipo y la acción principal.
  static Color get acento => PaletaMarca.actual.acento;

  /// El acento encendido, para el final del degradado del botón y el anillo
  /// de foco de los campos.
  static Color get acentoClaro => PaletaMarca.actual.acentoClaro;

  /// El acento muy suave, para textos que acompañan a una acción.
  static Color get acentoSuave => PaletaMarca.actual.acentoSuave;

  // ── Fondos ─────────────────────────────────────────────────────────
  /// Fondo general de las pantallas oscuras: el gris azulado casi negro.
  static const Color fondo = Color(0xFF0F171A);

  /// Aún más profundo que `fondo`, para el inicio y el arranque.
  static const Color fondoProfundo = Color(0xFF0B1113);

  /// Barras y superficies elevadas sobre el fondo.
  static const Color superficie = Color(0xFF162022);

  /// Tarjetas opacas sobre la superficie (diálogos, hojas inferiores).
  static const Color tarjeta = Color(0xFF212E31);

  /// Los tres tonos del degradado de fondo (ver `FondoDegradado`).
  static const Color fondoDegradadoInicio = Color(0xFF283A3E);
  static const Color fondoDegradadoMedio = Color(0xFF192629);

  // ── Tarjetas y campos ──────────────────────────────────────────────
  // Sobre el degradado de fondo las superficies no son opacas: dejan pasar
  // algo del gris azulado de atrás.

  /// Fondo de campos de formulario y tarjetas planas.
  static const Color campo = Color(0xE60F1A1D);

  /// Fondo de tarjetas con contenido, algo más opaco que `campo`.
  static const Color tarjetaPlana = Color(0xED142023);

  /// Borde sutil de campos y tarjetas.
  static const Color bordeCampo = Color(0xFF2D3F44);

  /// Borde de un campo deshabilitado.
  static const Color bordeDeshabilitado = Color(0xFF1C2A2D);

  // ── Estados ────────────────────────────────────────────────────────
  static const Color exito = Color(0xFF4ADE80);
  static const Color alerta = Color(0xFFFBBF24);
  static const Color peligro = Color(0xFFEF4444);

  /// Rojo apagado: cierres y salidas, donde el rojo pleno alarmaría de más.
  static const Color peligroSuave = Color(0xFFF87171);

  /// Rojo del botón que confirma algo destructivo (cerrar sesión, borrar).
  static const Color peligroBoton = Color(0xFFDC2626);

  /// Textos sobre el fondo de un aviso de alerta.
  static const Color alertaTexto = Color(0xFFFDE68A);
  static const Color alertaTextoFuerte = Color(0xFFFCD34D);

  /// Textos sobre el fondo de un error.
  static const Color errorTexto = Color(0xFFFCA5A5);
  static const Color errorTextoClaro = Color(0xFFFECACA);

  /// Fondos de los avisos flotantes.
  static const Color avisoExito = Color(0xFF166534);
  static const Color avisoError = Color(0xFF991B1B);
  static const Color avisoSinConexion = Color(0xFF9A5B08);

  // ── Series ─────────────────────────────────────────────────────────
  // Distinguen cosas entre sí: modalidades de cita y estados.
  static const Color celeste = Color(0xFF7CC4DC);
  static const Color menta = Color(0xFF2DD4BF);
  static const Color violeta = Color(0xFFA78BFA);
  static const Color ambar = Color(0xFFFFC857);

  // ── Texto ──────────────────────────────────────────────────────────
  static const Color texto = Colors.white;

  /// Texto de apoyo: descripciones y rótulos.
  static const Color textoSecundario = Color(0xFF9AABAF);

  /// Texto claro con un tinte de la marca, para lo que acompaña a un título.
  static const Color textoSuave = Color(0xFFC9D6D9);

  /// Texto casi apagado: pies de pantalla, versión instalada.
  static const Color textoTenue = Color(0xFF6E8288);

  /// Texto de ayuda dentro de un campo vacío.
  static const Color textoPista = Color(0xFF5F7479);

  /// Sombra de las tarjetas que se levantan del fondo.
  static const Color sombra = Color(0x66000000);

  /// Sombra más ligera, para lo que apenas se separa del fondo.
  static const Color sombraSuave = Color(0x3D000000);

  /// Velo blanco muy tenue para halos y líneas finas.
  static const Color veloClaro = Color(0x33FFFFFF);
  static const Color veloTransparente = Color(0x00FFFFFF);

  /// Fondo cálido y claro del icono de la aplicación: el anillo gris azulado
  /// y la cruz terracota necesitan un fondo claro para leerse en el lanzador.
  static const Color fondoIcono = Color(0xFFF4EFEA);
}

/// Degradados de Cliniq.
///
/// Son parte de la identidad visual: el encabezado es el mismo en citas, en
/// dependientes y en el perfil, y cada pantalla que repitiera sus tonos a mano
/// terminaría con uno distinto.
class AppGradientes {
  const AppGradientes._();

  /// Encabezado de sección: la tarjeta que presenta cada pantalla. Baja del
  /// gris azulado de la marca al fondo.
  static LinearGradient get encabezado => LinearGradient(
    colors: PaletaMarca.actual.encabezado,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Tarjeta de identidad del perfil, un punto más oscura que el encabezado.
  static LinearGradient get identidad => LinearGradient(
    colors: PaletaMarca.actual.identidad,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// El saludo del inicio: la única tarjeta que se va hacia el terracota.
  ///
  /// Es lo primero que se ve al entrar, así que sube del gris azulado de la
  /// marca a su terracota en vez de bajar al fondo como las demás. Sobre el
  /// extremo claro el texto blanco necesita un velo oscuro por debajo; eso lo
  /// pone la tarjeta, no este degradado.
  static LinearGradient get bienvenida => LinearGradient(
    colors: PaletaMarca.actual.bienvenida,
    stops: const [0, 0.38, 0.72, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// La acción principal de cada pantalla: el terracota encendiéndose.
  static LinearGradient get accion => LinearGradient(
    colors: [AppColors.acento, AppColors.acentoClaro],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Lo mismo, apagado, mientras la acción espera o no está disponible.
  static LinearGradient get accionApagada => LinearGradient(
    colors: [
      AppColors.acento.withValues(alpha: 0.45),
      AppColors.acentoClaro.withValues(alpha: 0.45),
    ],
  );

  /// El nombre de la marca en el acceso: blanco que se entibia.
  static LinearGradient get nombreDeMarca =>
      LinearGradient(colors: [Colors.white, AppColors.acentoSuave]);

  /// El logotipo pequeño de las barras: la marca de un tono al otro.
  static LinearGradient get marca => LinearGradient(
    colors: [AppColors.primario, AppColors.acento],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Escala de espaciado. Múltiplos fijos para que las pantallas alineen
/// igual sin decidir un número cada vez.
class AppEspaciado {
  const AppEspaciado._();

  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double xxl = 28;
}

/// Radios de esquina. Tres tamaños bastan: chip, tarjeta y panel.
class AppRadio {
  const AppRadio._();

  static const double chip = 12;
  static const double tarjeta = 16;
  static const double panel = 22;

  static BorderRadius get deChip => BorderRadius.circular(chip);
  static BorderRadius get deTarjeta => BorderRadius.circular(tarjeta);
  static BorderRadius get dePanel => BorderRadius.circular(panel);
}
