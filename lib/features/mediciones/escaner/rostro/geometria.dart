// lib/features/mediciones/escaner/rostro/geometria.dart

/// La geometría plana del rostro: puntos, cajas, polígonos y el ajuste de
/// una imagen que cubre la pantalla.
///
/// Es pura (sin Flutter ni cámara) para probarla con figuras sintéticas.
library;

import 'dart:math' as math;

/// Un punto del plano. En el escáner, en píxeles de la imagen tal como la
/// ve la persona (derecha y, con la cámara frontal, espejada).
class Punto {
  final double x;
  final double y;

  const Punto(this.x, this.y);

  Punto operator +(Punto otro) => Punto(x + otro.x, y + otro.y);

  Punto operator -(Punto otro) => Punto(x - otro.x, y - otro.y);

  Punto operator *(double factor) => Punto(x * factor, y * factor);

  double distanciaA(Punto otro) => math.sqrt(distancia2A(otro));

  double distancia2A(Punto otro) {
    final dx = x - otro.x;
    final dy = y - otro.y;
    return dx * dx + dy * dy;
  }

  /// El punto a una fracción [t] del camino hacia [otro].
  Punto hacia(Punto otro, double t) =>
      Punto(x + (otro.x - x) * t, y + (otro.y - y) * t);

  @override
  bool operator ==(Object other) =>
      other is Punto && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Punto($x, $y)';
}

/// Un rectángulo alineado con los ejes.
class Caja {
  final double izquierda;
  final double arriba;
  final double derecha;
  final double abajo;

  const Caja(this.izquierda, this.arriba, this.derecha, this.abajo);

  /// La caja más chica que contiene a todos los [puntos], o `null` si no
  /// hay ninguno.
  static Caja? de(Iterable<Punto> puntos) {
    double? x0, y0, x1, y1;
    for (final p in puntos) {
      x0 = x0 == null ? p.x : math.min(x0, p.x);
      y0 = y0 == null ? p.y : math.min(y0, p.y);
      x1 = x1 == null ? p.x : math.max(x1, p.x);
      y1 = y1 == null ? p.y : math.max(y1, p.y);
    }
    if (x0 == null) return null;
    return Caja(x0, y0!, x1!, y1!);
  }

  double get ancho => derecha - izquierda;
  double get alto => abajo - arriba;
  Punto get centro => Punto((izquierda + derecha) / 2, (arriba + abajo) / 2);

  bool contiene(Punto p) =>
      p.x >= izquierda && p.x <= derecha && p.y >= arriba && p.y <= abajo;

  /// La misma caja dividida por el tamaño de la imagen (0–1).
  Caja normalizada(double anchoImagen, double altoImagen) => Caja(
    izquierda / anchoImagen,
    arriba / altoImagen,
    derecha / anchoImagen,
    abajo / altoImagen,
  );

  @override
  bool operator ==(Object other) =>
      other is Caja &&
      other.izquierda == izquierda &&
      other.arriba == arriba &&
      other.derecha == derecha &&
      other.abajo == abajo;

  @override
  int get hashCode => Object.hash(izquierda, arriba, derecha, abajo);

  @override
  String toString() => 'Caja($izquierda, $arriba, $derecha, $abajo)';
}

/// Si [p] cae dentro del [poligono] (regla par-impar, por cruce de rayos).
/// Un polígono de menos de tres vértices no contiene nada.
bool puntoEnPoligono(Punto p, List<Punto> poligono) {
  final n = poligono.length;
  if (n < 3) return false;
  var dentro = false;
  for (var i = 0, j = n - 1; i < n; j = i++) {
    final a = poligono[i];
    final b = poligono[j];
    final cruza =
        (a.y > p.y) != (b.y > p.y) &&
        p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x;
    if (cruza) dentro = !dentro;
  }
  return dentro;
}

/// El área con signo de un polígono (fórmula del zapatero): positiva si
/// sus vértices van en el sentido de x hacia y.
double areaConSigno(List<Punto> poligono) {
  var doble = 0.0;
  for (var i = 0, j = poligono.length - 1; i < poligono.length; j = i++) {
    doble += poligono[j].x * poligono[i].y - poligono[i].x * poligono[j].y;
  }
  return doble / 2;
}

/// El centro de masa de unos puntos (su promedio).
Punto centroideDe(List<Punto> puntos) {
  if (puntos.isEmpty) return const Punto(0, 0);
  var sx = 0.0, sy = 0.0;
  for (final p in puntos) {
    sx += p.x;
    sy += p.y;
  }
  return Punto(sx / puntos.length, sy / puntos.length);
}

/// Cómo se dibuja una imagen que **cubre** una vista sin deformarse
/// (`BoxFit.cover`): la escala y el corrimiento. Lo que sobra por un lado
/// queda fuera, centrado.
class AjusteCubrir {
  final double escala;
  final double dx;
  final double dy;

  const AjusteCubrir._(this.escala, this.dx, this.dy);

  factory AjusteCubrir({
    required double anchoImagen,
    required double altoImagen,
    required double anchoVista,
    required double altoVista,
  }) {
    if (anchoImagen <= 0 || altoImagen <= 0) {
      return const AjusteCubrir._(1, 0, 0);
    }
    final escala = math.max(anchoVista / anchoImagen, altoVista / altoImagen);
    return AjusteCubrir._(
      escala,
      (anchoVista - anchoImagen * escala) / 2,
      (altoVista - altoImagen * escala) / 2,
    );
  }

  /// De un píxel de la imagen a la vista.
  Punto aVista(Punto p) => Punto(p.x * escala + dx, p.y * escala + dy);

  /// De la vista a un píxel de la imagen.
  Punto aImagen(Punto p) => Punto((p.x - dx) / escala, (p.y - dy) / escala);
}
