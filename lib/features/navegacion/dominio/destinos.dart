// lib/features/navegacion/dominio/destinos.dart

import '../../../core/config/entorno.dart';
import '../data/menu_service.dart';

/// Las pantallas propias de la aplicación a las que puede llevar un enlace.
enum PantallaNativa { inicio, citas, agendar, dependientes, consultas, perfil }

/// Las rutas del panel que la aplicación sabe abrir con una pantalla suya.
/// Las rutas son del sistema (no se administran); lo que el administrador
/// elige es cuáles se ven, en qué orden, con qué nombre, icono y color.
const Map<String, PantallaNativa> rutasNativas = {
  '/inicio': PantallaNativa.inicio,
  '/mis-citas': PantallaNativa.citas,
  '/portal/agendar': PantallaNativa.agendar,
  '/portal/dependientes': PantallaNativa.dependientes,
  '/portal/consultas': PantallaNativa.consultas,
  '/perfil': PantallaNativa.perfil,
};

/// A dónde lleva un enlace del menú.
sealed class DestinoDeEnlace {
  const DestinoDeEnlace();
}

/// Una pantalla de la aplicación.
class DestinoNativo extends DestinoDeEnlace {
  final PantallaNativa pantalla;

  const DestinoNativo(this.pantalla);

  @override
  bool operator ==(Object other) =>
      other is DestinoNativo && other.pantalla == pantalla;

  @override
  int get hashCode => pantalla.hashCode;

  @override
  String toString() => 'DestinoNativo($pantalla)';
}

/// Una página que se abre en el navegador.
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

/// Ruta conocida → su pantalla; ruta desconocida → `https://<web><ruta>` en
/// el navegador; enlace `EXTERNO` → su dirección tal cual.
DestinoDeEnlace destinoDe(EnlaceMenu enlace) {
  final ruta = enlace.route.trim();

  if (enlace.externo) {
    final esDireccion = RegExp(r'^https?://').hasMatch(ruta);
    return DestinoWeb(esDireccion ? ruta : Entorno.urlWeb(ruta));
  }

  final sinBarraFinal = ruta.length > 1 && ruta.endsWith('/')
      ? ruta.substring(0, ruta.length - 1)
      : ruta;
  final pantalla = rutasNativas[sinBarraFinal];

  return pantalla != null
      ? DestinoNativo(pantalla)
      : DestinoWeb(Entorno.urlWeb(ruta));
}

/// Cómo se reparten los enlaces: los cuatro primeros van en la barra de
/// abajo (junto a «Perfil», que siempre está) y el resto en «Accesos
/// rápidos» del inicio. Un enlace al perfil no se repite: ya tiene su
/// pestaña.
class NavegacionDeLaApp {
  static const int enLaBarra = 4;

  final List<EnlaceMenu> barra;
  final List<EnlaceMenu> accesos;

  const NavegacionDeLaApp({required this.barra, required this.accesos});

  factory NavegacionDeLaApp.desde(List<EnlaceMenu> enlaces) {
    final sinPerfil = [
      for (final e in enlaces)
        if (destinoDe(e) != const DestinoNativo(PantallaNativa.perfil)) e,
    ];

    return NavegacionDeLaApp(
      barra: sinPerfil.take(enLaBarra).toList(),
      accesos: sinPerfil.skip(enLaBarra).toList(),
    );
  }
}
