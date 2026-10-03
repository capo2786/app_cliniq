// lib/features/mediciones/escaner/rostro/delaunay.dart

/// La triangulación de Delaunay de unos puntos, con el algoritmo de
/// Bowyer–Watson. Es la malla que se dibuja sobre el rostro: los puntos son
/// los contornos que detecta ML Kit (~130) y nada más.
///
/// Pura y sin dependencias. Con coordenadas en píxeles (enteros, como las
/// que devuelve ML Kit) las pruebas de orientación y del círculo son
/// exactas en `double` para los triángulos de puntos reales; las del súper
/// triángulo, tan lejano, se deciden por el término dominante, que también
/// es exacto.
library;

import 'dart:math' as math;

import 'geometria.dart';

/// Un triángulo, por los índices de sus vértices en la lista de entrada,
/// en sentido positivo (área con signo > 0).
typedef Triangulo = (int, int, int);

/// Los triángulos de Delaunay de [puntos]. Los puntos repetidos se usan una
/// sola vez (el primero); con menos de tres puntos distintos, o todos en
/// una recta, no hay triángulos.
List<Triangulo> triangular(List<Punto> puntos) {
  // Sin repetidos: la clave es la posición exacta.
  final vistos = <Punto>{};
  final unicos = <int>[];
  for (var i = 0; i < puntos.length; i++) {
    if (vistos.add(puntos[i])) unicos.add(i);
  }
  if (unicos.length < 3) return const [];

  final caja = Caja.de([for (final i in unicos) puntos[i]])!;
  final lado = math.max(caja.ancho, caja.alto) + 1;
  final centro = caja.centro;

  // El súper triángulo, muy lejos: más allá del círculo de cualquier
  // triángulo fino del borde (si no, faltarían triángulos en el casco), y
  // girado para que ninguna arista de coordenadas enteras le sea paralela.
  final lejos = 1e7 * lado;
  Punto vertice(double angulo) => Punto(
    centro.x + lejos * math.cos(angulo),
    centro.y + lejos * math.sin(angulo),
  );
  const giro = 0.3217;
  final vertices = <Punto>[
    for (final i in unicos) puntos[i],
    vertice(giro),
    vertice(giro + 2 * math.pi / 3),
    vertice(giro + 4 * math.pi / 3),
  ];
  final n = unicos.length;
  final s0 = n, s1 = n + 1, s2 = n + 2;

  var triangulos = <_Tri>[_Tri.orientado(vertices, s0, s1, s2)];

  for (var p = 0; p < n; p++) {
    final punto = vertices[p];
    final malos = <_Tri>[];
    final buenos = <_Tri>[];
    for (final t in triangulos) {
      (t.contieneEnCirculo(vertices, punto) ? malos : buenos).add(t);
    }

    // El borde del hueco: las aristas de los malos que no comparten.
    final cuenta = <int, int>{};
    for (final t in malos) {
      for (final arista in t.aristas()) {
        cuenta[arista] = (cuenta[arista] ?? 0) + 1;
      }
    }
    for (final t in malos) {
      for (final (a, b) in t.paresDeAristas()) {
        if (cuenta[_clave(a, b)] == 1) {
          buenos.add(_Tri.orientado(vertices, a, b, p));
        }
      }
    }
    triangulos = buenos;
  }

  return [
    for (final t in triangulos)
      if (t.a < n && t.b < n && t.c < n && t.area(vertices) > 0)
        (unicos[t.a], unicos[t.b], unicos[t.c]),
  ];
}

/// Las aristas (sin repetir) de unos triángulos, cada una con el índice
/// menor primero.
List<(int, int)> aristasDe(List<Triangulo> triangulos) {
  final vistas = <int>{};
  final aristas = <(int, int)>[];
  void agregar(int a, int b) {
    final menor = a < b ? a : b;
    final mayor = a < b ? b : a;
    if (vistas.add(_clave(menor, mayor))) aristas.add((menor, mayor));
  }

  for (final (a, b, c) in triangulos) {
    agregar(a, b);
    agregar(b, c);
    agregar(c, a);
  }
  return aristas;
}

int _clave(int a, int b) => a < b ? (a << 20) | b : (b << 20) | a;

double _orientacion(Punto a, Punto b, Punto c) =>
    (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);

class _Tri {
  final int a;
  final int b;
  final int c;

  const _Tri(this.a, this.b, this.c);

  /// El triángulo (a, b, c) en sentido positivo.
  factory _Tri.orientado(List<Punto> v, int a, int b, int c) =>
      _orientacion(v[a], v[b], v[c]) >= 0 ? _Tri(a, b, c) : _Tri(a, c, b);

  double area(List<Punto> v) => _orientacion(v[a], v[b], v[c]) / 2;

  Iterable<int> aristas() => [_clave(a, b), _clave(b, c), _clave(c, a)];

  Iterable<(int, int)> paresDeAristas() => [(a, b), (b, c), (c, a)];

  /// Si [p] cae estrictamente dentro del círculo que pasa por los tres
  /// vértices (el determinante clásico, con el triángulo en sentido
  /// positivo). Un punto justo en el borde no cuenta.
  bool contieneEnCirculo(List<Punto> v, Punto p) {
    final ax = v[a].x - p.x, ay = v[a].y - p.y;
    final bx = v[b].x - p.x, by = v[b].y - p.y;
    final cx = v[c].x - p.x, cy = v[c].y - p.y;
    final det =
        (ax * ax + ay * ay) * (bx * cy - cx * by) -
        (bx * bx + by * by) * (ax * cy - cx * ay) +
        (cx * cx + cy * cy) * (ax * by - bx * ay);
    return det > 0;
  }
}
