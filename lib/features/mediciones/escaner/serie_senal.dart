// lib/features/mediciones/escaner/serie_senal.dart

/// Lo que el escáner saca de la cámara: números por cuadro, nunca imágenes.
///
/// La extracción (de la imagen a [CuadroPpg]) y el cálculo (de la serie a
/// la FC, en `dominio/procesamiento_ppg.dart`) están separados a propósito:
/// la [SerieSenal] es lo único que pasa de uno a otro, y se puede escribir
/// como JSON ([SerieSenal.aJsonParaAnalisis]) con la forma `{metodo, t,
/// canales}` por si mañana otro motor la analiza. Hoy no sale del teléfono.
library;

import 'package:equatable/equatable.dart';

import '../data/models/medicion.dart';

/// Cómo se mide con la cámara.
enum ModoEscaner {
  /// La yema sobre la cámara trasera, con el flash encendido. El
  /// recomendado: el más confiable.
  dedo(MetodoMedicion.camaraDedo),

  /// El rostro frente a la cámara frontal (beta): depende de la luz y de
  /// estar quieto.
  rostro(MetodoMedicion.camaraRostro);

  /// El método con que se guarda la medición.
  final MetodoMedicion metodo;

  const ModoEscaner(this.metodo);
}

/// Un cuadro de la cámara ya reducido a números. La imagen se suelta en
/// cuanto se calculan: ningún cuadro se guarda.
class CuadroPpg extends Equatable {
  /// Desde que empezó la medición.
  final Duration momento;

  /// Los promedios (0–255) de la región que se mira: el centro de la
  /// imagen en el modo dedo; la piel de la frente y las mejillas en el
  /// modo rostro.
  final double rojo;
  final double verde;
  final double azul;
  final double luminancia;

  /// Modo dedo: la fracción de la región cubierta por la yema (roja y
  /// brillante). Modo rostro: la fracción de la región que es piel.
  final double cobertura;

  /// La fracción de píxeles quemados (≥ 250) en el rojo.
  final double saturacion;

  const CuadroPpg({
    required this.momento,
    required this.rojo,
    required this.verde,
    required this.azul,
    required this.luminancia,
    this.cobertura = 1,
    this.saturacion = 0,
  });

  double get segundos => momento.inMicroseconds / 1e6;

  @override
  List<Object?> get props => [
    momento,
    rojo,
    verde,
    azul,
    luminancia,
    cobertura,
    saturacion,
  ];
}

/// La serie de una medición: los tiempos y los canales de cada cuadro.
class SerieSenal extends Equatable {
  final ModoEscaner modo;

  /// En segundos desde el inicio.
  final List<double> tiempos;

  final List<double> rojo;
  final List<double> verde;
  final List<double> azul;
  final List<double> luminancia;
  final List<double> cobertura;
  final List<double> saturacion;

  const SerieSenal({
    required this.modo,
    required this.tiempos,
    required this.rojo,
    required this.verde,
    required this.azul,
    required this.luminancia,
    required this.cobertura,
    required this.saturacion,
  });

  factory SerieSenal.de(ModoEscaner modo, List<CuadroPpg> cuadros) =>
      SerieSenal(
        modo: modo,
        tiempos: [for (final c in cuadros) c.segundos],
        rojo: [for (final c in cuadros) c.rojo],
        verde: [for (final c in cuadros) c.verde],
        azul: [for (final c in cuadros) c.azul],
        luminancia: [for (final c in cuadros) c.luminancia],
        cobertura: [for (final c in cuadros) c.cobertura],
        saturacion: [for (final c in cuadros) c.saturacion],
      );

  int get length => tiempos.length;

  double get duracion => tiempos.length < 2 ? 0 : tiempos.last - tiempos.first;

  /// Los últimos [segundos] de la serie.
  SerieSenal ultimos(double segundos) {
    if (tiempos.isEmpty) return this;
    final desde = tiempos.last - segundos;
    var i = 0;
    while (i < tiempos.length && tiempos[i] < desde) {
      i++;
    }
    List<double> corte(List<double> x) => x.sublist(i);
    return SerieSenal(
      modo: modo,
      tiempos: corte(tiempos),
      rojo: corte(rojo),
      verde: corte(verde),
      azul: corte(azul),
      luminancia: corte(luminancia),
      cobertura: corte(cobertura),
      saturacion: corte(saturacion),
    );
  }

  /// La forma `{metodo, t (ms), canales: {y?, r?, g?, b?}}`: el modo dedo
  /// lleva el rojo y la luminancia; el rostro, los tres colores. Sin
  /// imágenes: solo números.
  Map<String, dynamic> aJsonParaAnalisis() => {
    'metodo': modo.metodo.codigo,
    't': [for (final t in tiempos) (t * 1000).round()],
    'canales': switch (modo) {
      ModoEscaner.dedo => {'y': luminancia, 'r': rojo},
      ModoEscaner.rostro => {'r': rojo, 'g': verde, 'b': azul},
    },
  };

  /// Todo, para volver a leerla igual ([desdeJson]).
  Map<String, dynamic> aJson() => {
    'modo': modo.name,
    'tiempos': tiempos,
    'rojo': rojo,
    'verde': verde,
    'azul': azul,
    'luminancia': luminancia,
    'cobertura': cobertura,
    'saturacion': saturacion,
  };

  static SerieSenal? desdeJson(Object? json) {
    if (json is! Map) return null;
    final modo = ModoEscaner.values
        .where((m) => m.name == json['modo'])
        .firstOrNull;
    if (modo == null) return null;

    List<double>? lista(String campo) {
      final valor = json[campo];
      if (valor is! List) return null;
      return [
        for (final v in valor)
          if (v is num) v.toDouble() else double.nan,
      ];
    }

    final tiempos = lista('tiempos');
    final canales = [
      lista('rojo'),
      lista('verde'),
      lista('azul'),
      lista('luminancia'),
      lista('cobertura'),
      lista('saturacion'),
    ];
    if (tiempos == null ||
        canales.any((c) => c == null || c.length != tiempos.length)) {
      return null;
    }

    return SerieSenal(
      modo: modo,
      tiempos: tiempos,
      rojo: canales[0]!,
      verde: canales[1]!,
      azul: canales[2]!,
      luminancia: canales[3]!,
      cobertura: canales[4]!,
      saturacion: canales[5]!,
    );
  }

  @override
  List<Object?> get props => [
    modo,
    tiempos,
    rojo,
    verde,
    azul,
    luminancia,
    cobertura,
    saturacion,
  ];
}
