// lib/features/mediciones/escaner/rostro/suavizado.dart

/// El suavizado de los puntos del rostro entre detecciones.
///
/// ML Kit detecta unas 8–10 veces por segundo y la pantalla se pinta a 60:
/// si la malla saltara de una detección a la siguiente se vería a tirones.
/// [SuavizadorDePuntos] acerca cada punto a su última posición detectada
/// con una media móvil exponencial en el tiempo (constante [tau]), así se
/// mueve fluido y sin inventar nada: solo recorre el camino entre dos
/// detecciones reales.
library;

import 'dart:math' as math;

import 'geometria.dart';

class SuavizadorDePuntos {
  /// Cuánto tarda en recorrer el 63 % del camino hacia el objetivo.
  final Duration tau;

  List<Punto> _actuales = const [];
  List<Punto> _objetivo = const [];

  SuavizadorDePuntos({this.tau = const Duration(milliseconds: 90)});

  /// Las posiciones de ahora (vacía si no hay rostro).
  List<Punto> get puntos => _actuales;

  bool get vacio => _actuales.isEmpty;

  /// Una detección nueva. Si cambia el número de puntos (falta un
  /// contorno, o es el primer rostro) se salta directo, sin recorrido.
  void fijarObjetivo(List<Punto> objetivo) {
    _objetivo = List.unmodifiable(objetivo);
    if (_actuales.length != objetivo.length) _actuales = _objetivo;
  }

  /// Sin rostro: se olvida todo.
  void limpiar() {
    _actuales = const [];
    _objetivo = const [];
  }

  /// Avanza [transcurrido] hacia el objetivo.
  void avanzar(Duration transcurrido) {
    if (_objetivo.isEmpty || identical(_actuales, _objetivo)) return;
    final dt = transcurrido.inMicroseconds;
    if (dt <= 0) return;
    final alfa = tau.inMicroseconds <= 0
        ? 1.0
        : 1 - math.exp(-dt / tau.inMicroseconds);
    _actuales = [
      for (var i = 0; i < _objetivo.length; i++)
        _actuales[i].hacia(_objetivo[i], alfa),
    ];
  }
}
