// lib/features/mediciones/escaner/rostro/region_de_interes.dart

/// Las zonas de piel que se miden en el rostro: la frente y las dos
/// mejillas, como polígonos hechos con los contornos que detectó ML Kit.
///
/// - **Frente:** sobre las cejas, subiendo una fracción de la altura del
///   rostro (sin pasar del óvalo).
/// - **Mejillas:** entre el borde inferior del ojo, el costado de la nariz,
///   la comisura del labio superior y el óvalo de la cara.
///
/// Dentro de estos polígonos solo cuentan los puntos que además son piel
/// por su color (así quedan fuera las cejas, el pelo y los lentes). Sin
/// contornos, se usan rectángulos dentro de la caja del rostro.
library;

import 'dart:math' as math;

import 'geometria.dart';
import 'rostro_detectado.dart';

class RegionDeInteres {
  final List<Punto> frente;

  /// La mejilla que queda a la izquierda de la pantalla.
  final List<Punto> mejillaIzquierda;

  /// La que queda a la derecha.
  final List<Punto> mejillaDerecha;

  /// El óvalo de la cara, si se conoce: ninguna muestra cae fuera de él.
  final List<Punto>? limite;

  const RegionDeInteres({
    required this.frente,
    required this.mejillaIzquierda,
    required this.mejillaDerecha,
    this.limite,
  });

  List<List<Punto>> get poligonos => [frente, mejillaIzquierda, mejillaDerecha];

  bool _dentroDelLimite(Punto p) {
    final l = limite;
    return l == null || l.length < 3 || puntoEnPoligono(p, l);
  }

  bool contiene(Punto p) =>
      _dentroDelLimite(p) && poligonos.any((pol) => puntoEnPoligono(p, pol));

  /// Los puntos de la rejilla de cada zona (unos [porZona] por zona, como
  /// mucho) que caen dentro del óvalo.
  List<Punto> muestras({int porZona = 300}) => [
    for (final zona in poligonos)
      for (final p in muestrasEnPoligono(zona, maximo: porZona))
        if (_dentroDelLimite(p)) p,
  ];
}

/// Las zonas de [rostro]. [alturaFrente] es la fracción de la altura del
/// rostro que sube la frente desde las cejas.
RegionDeInteres regionDesdeRostro(
  RostroDetectado rostro, {
  double alturaFrente = 0.16,
}) {
  final frente = _frente(rostro, alturaFrente);
  final mejillas = _mejillas(rostro);
  final caja = _regionDeLaCaja(rostro.caja);
  return RegionDeInteres(
    frente: frente ?? caja.frente,
    mejillaIzquierda: mejillas?.$1 ?? caja.mejillaIzquierda,
    mejillaDerecha: mejillas?.$2 ?? caja.mejillaDerecha,
    limite: rostro.contornos[ContornoRostro.ovalo],
  );
}

/// Sin contornos: rectángulos en proporción a la caja del rostro.
RegionDeInteres _regionDeLaCaja(Caja c) {
  List<Punto> rect(double x0, double y0, double x1, double y1) => [
    Punto(c.izquierda + x0 * c.ancho, c.arriba + y0 * c.alto),
    Punto(c.izquierda + x1 * c.ancho, c.arriba + y0 * c.alto),
    Punto(c.izquierda + x1 * c.ancho, c.arriba + y1 * c.alto),
    Punto(c.izquierda + x0 * c.ancho, c.arriba + y1 * c.alto),
  ];
  return RegionDeInteres(
    frente: rect(0.30, 0.10, 0.70, 0.25),
    mejillaIzquierda: rect(0.15, 0.50, 0.38, 0.72),
    mejillaDerecha: rect(0.62, 0.50, 0.85, 0.72),
  );
}

List<Punto>? _frente(RostroDetectado r, double alturaFrente) {
  final c = r.contornos;
  final cejas = [
    ...?c[ContornoRostro.cejaIzquierdaArriba],
    ...?c[ContornoRostro.cejaDerechaArriba],
  ]..sort((a, b) => a.x.compareTo(b.x));
  if (cejas.length < 4) return null;

  final alto = r.caja.alto;
  final ovalo = c[ContornoRostro.ovalo];
  final techo = (ovalo == null || ovalo.isEmpty)
      ? r.caja.arriba
      : ovalo.map((p) => p.y).reduce(math.min) + 0.02 * alto;
  final medio = (cejas.first.x + cejas.last.x) / 2;

  // Un poco más angosta que las cejas (las sienes tienen pelo) y un poco
  // por encima de ellas.
  final abajo = [
    for (final p in cejas)
      Punto(medio + (p.x - medio) * 0.85, p.y - 0.03 * alto),
  ];
  // Arriba se angosta otro poco: la frente se curva hacia las sienes.
  final arriba = [
    for (final p in abajo.reversed)
      Punto(
        medio + (p.x - medio) * 0.85,
        math.max(p.y - alturaFrente * alto, techo),
      ),
  ];
  return [...abajo, ...arriba];
}

(List<Punto>, List<Punto>)? _mejillas(RostroDetectado r) {
  final c = r.contornos;
  final ojos = [c[ContornoRostro.ojoIzquierdo], c[ContornoRostro.ojoDerecho]];
  final nariz = c[ContornoRostro.baseNariz];
  final labio = c[ContornoRostro.labioSuperiorArriba];
  if (ojos.any((o) => o == null || o.length < 4) ||
      nariz == null ||
      nariz.isEmpty ||
      labio == null ||
      labio.length < 2) {
    return null;
  }

  final mejillas = [for (final ojo in ojos) _mejilla(r, ojo!, nariz, labio)];
  // Cuál queda a la izquierda de la pantalla, por la posición de su ojo.
  final primeroALaIzquierda =
      centroideDe(ojos[0]!).x <= centroideDe(ojos[1]!).x;
  return primeroALaIzquierda
      ? (mejillas[0], mejillas[1])
      : (mejillas[1], mejillas[0]);
}

List<Punto> _mejilla(
  RostroDetectado r,
  List<Punto> ojo,
  List<Punto> nariz,
  List<Punto> labio,
) {
  final alto = r.caja.alto;
  final ancho = r.caja.ancho;
  final centroOjo = centroideDe(ojo);
  final centroNariz = centroideDe(nariz);
  final izquierda = centroOjo.x < centroNariz.x;
  double haciaFuera(double x, double d) => izquierda ? x - d : x + d;
  bool delLado(Punto p) =>
      izquierda ? p.x < centroNariz.x : p.x > centroNariz.x;

  // El borde inferior del ojo, de afuera hacia adentro, un poco más abajo
  // para no tomar las pestañas.
  final bajoOjo = [
    for (final p in ojo)
      if (p.y >= centroOjo.y) Punto(p.x, p.y + 0.03 * alto),
  ]..sort((a, b) => izquierda ? a.x.compareTo(b.x) : b.x.compareTo(a.x));

  // El costado de la nariz y la comisura, un poco hacia la mejilla.
  final aleta = nariz.reduce(
    (a, b) => (izquierda ? a.x < b.x : a.x > b.x) ? a : b,
  );
  final comisura = labio.reduce(
    (a, b) => (izquierda ? a.x < b.x : a.x > b.x) ? a : b,
  );
  final costado = Punto(haciaFuera(aleta.x, 0.04 * ancho), aleta.y);
  final esquina = Punto(
    haciaFuera(comisura.x, 0.03 * ancho),
    comisura.y - 0.02 * alto,
  );

  // El óvalo de ese lado, entre la altura del ojo y la de la comisura, de
  // abajo hacia arriba y metido hacia la mejilla (el borde trae fondo).
  final ovalo = r.contornos[ContornoRostro.ovalo] ?? const <Punto>[];
  var borde = [
    for (final p in ovalo)
      if (delLado(p) && p.y > centroOjo.y && p.y < esquina.y) p,
  ]..sort((a, b) => b.y.compareTo(a.y));
  if (borde.length < 2) {
    final x = izquierda
        ? r.caja.izquierda + 0.08 * ancho
        : r.caja.derecha - 0.08 * ancho;
    borde = [Punto(x, esquina.y), Punto(x, centroOjo.y + 0.05 * alto)];
  }
  final mejilla = r
      .contornos[izquierda
          ? ContornoRostro.mejillaIzquierda
          : ContornoRostro.mejillaDerecha]
      ?.firstOrNull;
  final centro =
      mejilla ?? centroideDe([...bajoOjo, costado, esquina, ...borde]);
  final metido = [for (final p in borde) p.hacia(centro, 0.18)];

  return [...bajoOjo, costado, esquina, ...metido];
}

/// Una rejilla de puntos dentro de [poligono], con unos [maximo] nodos en
/// la caja que lo contiene (los de dentro son menos). Así el costo por
/// cuadro está acotado sea cual sea el tamaño del rostro.
List<Punto> muestrasEnPoligono(List<Punto> poligono, {int maximo = 300}) {
  final caja = Caja.de(poligono);
  if (caja == null || caja.ancho <= 0 || caja.alto <= 0 || maximo <= 0) {
    return const [];
  }
  final paso = math.sqrt(caja.ancho * caja.alto / maximo);
  final columnas = math.max(1, (caja.ancho / paso).floor());
  final filas = math.max(1, (caja.alto / paso).floor());
  final muestras = <Punto>[];
  for (var j = 0; j < filas; j++) {
    for (var i = 0; i < columnas; i++) {
      final p = Punto(
        caja.izquierda + caja.ancho * (i + 0.5) / columnas,
        caja.arriba + caja.alto * (j + 0.5) / filas,
      );
      if (puntoEnPoligono(p, poligono)) muestras.add(p);
    }
  }
  return muestras;
}
