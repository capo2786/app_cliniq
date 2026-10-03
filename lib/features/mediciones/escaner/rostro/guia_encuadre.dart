// lib/features/mediciones/escaner/rostro/guia_encuadre.dart

/// La guía de encuadre: de la detección del rostro y de la luz sale **una**
/// instrucción a la vez, la más importante.
///
/// Pura y probada: no sabe de la cámara ni de la pantalla. Con ML Kit mira
/// la caja del rostro (tamaño, centro, movimiento) y los ángulos; sin ML
/// Kit (respaldo por color de piel) solo puede decir si hay piel en el
/// marco y si hay luz.
library;

import '../serie_senal.dart';
import 'geometria.dart';

/// Lo que se le pide a la persona, por orden de prioridad.
enum InstruccionEncuadre {
  sinRostro('Pon tu cara dentro del marco'),
  acercate('Acércate un poco'),
  alejate('Aléjate un poco'),
  centra('Centra tu cara'),
  deFrente('Mira de frente a la cámara'),
  quieto('Quédate quieto'),
  masLuz('Busca un lugar con más luz'),
  perfecto('Perfecto, no te muevas');

  final String texto;

  const InstruccionEncuadre(this.texto);

  /// Todo bien: se puede medir.
  bool get bien => this == perfecto;

  /// Se ve un rostro, aunque falte acomodarlo.
  bool get hayRostro => this != sinRostro;
}

/// El centro del marco de la pantalla, en fracciones de la imagen como la
/// ve la persona: un poco arriba del medio, para dejar sitio al panel.
const Punto centroDelMarco = Punto(0.5, 0.42);

/// Los umbrales de la guía.
class ParametrosEncuadre {
  /// El ancho de la caja del rostro, en fracción del ancho de la imagen.
  final double anchoMinimo;
  final double anchoMaximo;

  /// Cuánto se puede alejar el centro de la caja del [centroDelMarco].
  final double desvioHorizontal;
  final double desvioVertical;

  /// Grados de giro a los lados (Y) y de inclinación (Z).
  final double giroMaximo;
  final double inclinacionMaxima;

  /// Cuánto puede moverse el centro de la caja (en anchos de la caja)
  /// durante [ventanaMovimiento].
  final double movimientoMaximo;
  final Duration ventanaMovimiento;

  /// La luminancia media (0–255) de la piel que se mide.
  final double luminanciaMinima;

  /// Sin ML Kit: la fracción del marco que tiene que ser piel.
  final double coberturaMinima;

  const ParametrosEncuadre({
    this.anchoMinimo = 0.35,
    this.anchoMaximo = 0.85,
    this.desvioHorizontal = 0.12,
    this.desvioVertical = 0.15,
    this.giroMaximo = 15,
    this.inclinacionMaxima = 12,
    this.movimientoMaximo = 0.06,
    this.ventanaMovimiento = const Duration(milliseconds: 700),
    this.luminanciaMinima = 60,
    this.coberturaMinima = 0.35,
  });
}

class GuiaDeEncuadre {
  final ParametrosEncuadre parametros;

  /// Los centros recientes de la caja (normalizados) y su ancho, uno por
  /// detección.
  final List<({Duration momento, Punto centro, double ancho})> _recientes = [];

  GuiaDeEncuadre({this.parametros = const ParametrosEncuadre()});

  /// La instrucción para este [cuadro].
  InstruccionEncuadre evaluar(CuadroPpg cuadro) {
    final p = parametros;

    if (cuadro.porColorDePiel) {
      _recientes.clear();
      if (cuadro.cobertura < p.coberturaMinima) {
        return InstruccionEncuadre.sinRostro;
      }
      return cuadro.luminancia < p.luminanciaMinima
          ? InstruccionEncuadre.masLuz
          : InstruccionEncuadre.perfecto;
    }

    final rostro = cuadro.rostro;
    if (rostro == null) {
      _recientes.clear();
      return InstruccionEncuadre.sinRostro;
    }

    final caja = rostro.cajaNormalizada;
    _recordar(rostro.momento, caja);

    if (caja.ancho < p.anchoMinimo) return InstruccionEncuadre.acercate;
    if (caja.ancho > p.anchoMaximo) return InstruccionEncuadre.alejate;
    if ((caja.centro.x - centroDelMarco.x).abs() > p.desvioHorizontal ||
        (caja.centro.y - centroDelMarco.y).abs() > p.desvioVertical) {
      return InstruccionEncuadre.centra;
    }
    if ((rostro.anguloY ?? 0).abs() > p.giroMaximo ||
        (rostro.anguloZ ?? 0).abs() > p.inclinacionMaxima) {
      return InstruccionEncuadre.deFrente;
    }
    if (_seMueve()) return InstruccionEncuadre.quieto;
    if (cuadro.luminancia < p.luminanciaMinima) {
      return InstruccionEncuadre.masLuz;
    }
    return InstruccionEncuadre.perfecto;
  }

  void _recordar(Duration momento, Caja caja) {
    if (_recientes.isNotEmpty && _recientes.last.momento == momento) return;
    _recientes.add((momento: momento, centro: caja.centro, ancho: caja.ancho));
    final desde = momento - parametros.ventanaMovimiento;
    _recientes.removeWhere((r) => r.momento < desde);
  }

  bool _seMueve() {
    if (_recientes.length < 2) return false;
    final ultimo = _recientes.last;
    if (ultimo.ancho <= 0) return false;
    return _recientes.any(
      (r) =>
          r.centro.distanciaA(ultimo.centro) / ultimo.ancho >
          parametros.movimientoMaximo,
    );
  }

  /// Se olvida el movimiento reciente (al empezar otra medición).
  void reiniciar() => _recientes.clear();
}
