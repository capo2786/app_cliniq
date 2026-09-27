// lib/features/navegacion/dominio/destinos.dart

import '../data/menu_service.dart';

/// Las pantallas propias de la aplicación a las que puede llevar un enlace
/// del menú, de un aviso o de un texto.
///
/// Las del final (Mi salud, Centro de ayuda y Soporte) todavía no tienen
/// pantalla: se registran en `presentacion/pantallas_nativas.dart` y,
/// mientras tanto, abren «Muy pronto». Nunca el navegador.
enum PantallaNativa {
  inicio,
  citas,
  agendar,
  dependientes,
  consultas,

  /// Una consulta en línea: `/portal/consultas/:id`.
  consulta,

  /// La sala de una cita de telemedicina: `/portal/videoconsulta/:citaId`.
  videoconsulta,

  perfil,

  /// La lista de avisos de la campana: `/notificaciones`.
  avisos,

  /// Mis derechos sobre mis datos (ARCO).
  privacidad,

  /// La encuesta de una cita atendida: `/portal/encuesta/:citaId`.
  encuesta,

  /// Un documento legal: `/legal/:slug`.
  legal,

  miSalud,
  ayuda,
  soporte,

  /// Un ticket de soporte: `/soporte/tickets/:id`.
  ticket,
}

/// Una ruta del sistema y la pantalla que la abre. Los segmentos que
/// empiezan con `:` son parámetros (`/portal/consultas/:id`).
class RutaDelSistema {
  final String patron;
  final PantallaNativa pantalla;

  const RutaDelSistema(this.patron, this.pantalla);
}

/// El enrutador: las rutas del panel que la aplicación sabe abrir con una
/// pantalla suya. Lo usan el menú, los avisos de la campana y cualquier
/// enlace interno.
///
/// Las rutas son del sistema (no se administran): lo que el administrador
/// elige es cuáles se ven en el menú, en qué orden, con qué nombre, icono y
/// color. Una ruta que no está aquí no se abre: la aplicación no manda a
/// nadie al navegador para ver el panel web.
const List<RutaDelSistema> rutasDelSistema = [
  RutaDelSistema('/inicio', PantallaNativa.inicio),
  RutaDelSistema('/mis-citas', PantallaNativa.citas),
  RutaDelSistema('/portal/agendar', PantallaNativa.agendar),
  RutaDelSistema('/portal/dependientes', PantallaNativa.dependientes),
  RutaDelSistema('/portal/consultas', PantallaNativa.consultas),
  RutaDelSistema('/portal/consultas/:id', PantallaNativa.consulta),
  RutaDelSistema('/portal/videoconsulta/:citaId', PantallaNativa.videoconsulta),
  RutaDelSistema('/perfil', PantallaNativa.perfil),
  RutaDelSistema('/notificaciones', PantallaNativa.avisos),
  RutaDelSistema('/portal/arco', PantallaNativa.privacidad),
  RutaDelSistema('/privacidad/solicitudes', PantallaNativa.privacidad),
  RutaDelSistema('/portal/encuesta/:citaId', PantallaNativa.encuesta),
  RutaDelSistema('/legal/:slug', PantallaNativa.legal),
  RutaDelSistema('/mi-salud', PantallaNativa.miSalud),
  RutaDelSistema('/ayuda', PantallaNativa.ayuda),
  RutaDelSistema('/soporte', PantallaNativa.soporte),
  RutaDelSistema('/soporte/tickets/:id', PantallaNativa.ticket),
];

/// A dónde lleva un enlace.
sealed class DestinoDeEnlace {
  const DestinoDeEnlace();
}

/// Una pantalla de la aplicación, con los parámetros de su ruta
/// (`{'id': '…'}` en `/portal/consultas/:id`).
class DestinoNativo extends DestinoDeEnlace {
  final PantallaNativa pantalla;
  final Map<String, String> parametros;

  const DestinoNativo(this.pantalla, [this.parametros = const {}]);

  /// El valor de un parámetro de la ruta, o `''` si no lo trae.
  String parametro(String nombre) => parametros[nombre] ?? '';

  /// Sin parámetros: puede ser una pestaña de la barra.
  bool get sinParametros => parametros.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is DestinoNativo &&
      other.pantalla == pantalla &&
      other.parametros.length == parametros.length &&
      parametros.entries.every((e) => other.parametros[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
    pantalla,
    Object.hashAllUnordered([
      for (final e in parametros.entries) Object.hash(e.key, e.value),
    ]),
  );

  @override
  String toString() => parametros.isEmpty
      ? 'DestinoNativo($pantalla)'
      : 'DestinoNativo($pantalla, $parametros)';
}

/// Una página de fuera (un enlace `EXTERNO` del menú, que puso el
/// administrador). Se abre en el navegador integrado, sin salir de la
/// aplicación.
class DestinoWeb extends DestinoDeEnlace {
  final String url;

  const DestinoWeb(this.url);

  @override
  bool operator ==(Object other) => other is DestinoWeb && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'DestinoWeb($url)';
}

/// Un teléfono (`tel:`) o un correo (`mailto:`): se abren con el marcador o
/// con el correo del teléfono, como siempre.
class DestinoContacto extends DestinoDeEnlace {
  final Uri direccion;

  const DestinoContacto(this.direccion);

  @override
  bool operator ==(Object other) =>
      other is DestinoContacto && other.direccion == direccion;

  @override
  int get hashCode => direccion.hashCode;

  @override
  String toString() => 'DestinoContacto($direccion)';
}

/// La pantalla de una ruta interna del sistema (`/portal/consultas/abc`), o
/// `null` si la aplicación no la sabe abrir (`/admin/...`, una ruta que
/// esta versión todavía no conoce).
///
/// Se ignoran la consulta y el fragmento (`?x=1`, `#y`) y la barra final;
/// los parámetros se devuelven ya decodificados. Una dirección completa
/// (`https://…`) no es una ruta interna.
DestinoNativo? destinoDeRuta(String ruta) {
  var limpia = ruta.trim();

  final corte = limpia.indexOf(RegExp(r'[?#]'));
  if (corte >= 0) limpia = limpia.substring(0, corte);

  if (!limpia.startsWith('/') || limpia.startsWith('//')) return null;

  final partes = [
    for (final p in limpia.split('/'))
      if (p.isNotEmpty) p,
  ];
  if (partes.isEmpty) return null;

  for (final ruta in rutasDelSistema) {
    final parametros = _coincidir(ruta.patron, partes);
    if (parametros != null) return DestinoNativo(ruta.pantalla, parametros);
  }

  return null;
}

/// Los parámetros si [partes] encaja con [patron]; si no, `null`.
Map<String, String>? _coincidir(String patron, List<String> partes) {
  final segmentos = [
    for (final s in patron.split('/'))
      if (s.isNotEmpty) s,
  ];
  if (segmentos.length != partes.length) return null;

  final parametros = <String, String>{};

  for (var i = 0; i < segmentos.length; i++) {
    final segmento = segmentos[i];

    if (segmento.startsWith(':')) {
      final String valor;
      try {
        valor = Uri.decodeComponent(partes[i]).trim();
      } catch (_) {
        return null;
      }
      if (valor.isEmpty) return null;

      parametros[segmento.substring(1)] = valor;
    } else if (segmento != partes[i].toLowerCase()) {
      return null;
    }
  }

  return parametros;
}

final RegExp _direccionWeb = RegExp(r'^https?://\S+$', caseSensitive: false);
final RegExp _contacto = RegExp(r'^(tel|mailto):', caseSensitive: false);

/// A dónde lleva un enlace del menú, o `null` si la aplicación no lo sabe
/// abrir: entonces no se enseña (ni en la barra ni en los accesos).
///
/// - `LINK`: una ruta del sistema abre su pantalla; una que el enrutador no
///   conoce no se muestra.
/// - `EXTERNO`: la dirección que puso el administrador, en el navegador
///   integrado; `tel:` y `mailto:`, con el marcador o el correo.
DestinoDeEnlace? destinoDe(EnlaceMenu enlace) {
  final ruta = enlace.route.trim();

  if (enlace.externo) {
    if (_direccionWeb.hasMatch(ruta)) return DestinoWeb(ruta);

    if (_contacto.hasMatch(ruta)) {
      final direccion = Uri.tryParse(ruta);
      return direccion == null ? null : DestinoContacto(direccion);
    }

    return null;
  }

  return destinoDeRuta(ruta);
}

/// Cómo se reparten los enlaces del menú.
///
/// - Los que la aplicación no sabe abrir no se ven.
/// - El de `/notificaciones` no es una pestaña ni un acceso: es la campana
///   de la cabecera ([campana]), y solo existe si el menú lo trae.
/// - Un enlace al perfil no se repite: ya tiene su pestaña.
/// - De los demás, los cuatro primeros van en la barra de abajo (junto a
///   «Perfil», que siempre está) y el resto en «Accesos rápidos» del inicio.
class NavegacionDeLaApp {
  static const int enLaBarra = 4;

  final List<EnlaceMenu> barra;
  final List<EnlaceMenu> accesos;

  /// El enlace de la campana (su nombre lo pone el administrador), o `null`
  /// si el menú no lo trae: entonces no hay campana.
  final EnlaceMenu? campana;

  const NavegacionDeLaApp({
    required this.barra,
    required this.accesos,
    this.campana,
  });

  factory NavegacionDeLaApp.desde(List<EnlaceMenu> enlaces) {
    const perfil = DestinoNativo(PantallaNativa.perfil);
    const avisos = DestinoNativo(PantallaNativa.avisos);

    EnlaceMenu? campana;
    final visibles = <EnlaceMenu>[];

    for (final enlace in enlaces) {
      final destino = destinoDe(enlace);

      if (destino == null || destino == perfil) continue;

      if (destino == avisos) {
        campana ??= enlace;
        continue;
      }

      visibles.add(enlace);
    }

    return NavegacionDeLaApp(
      barra: visibles.take(enLaBarra).toList(),
      accesos: visibles.skip(enLaBarra).toList(),
      campana: campana,
    );
  }
}
