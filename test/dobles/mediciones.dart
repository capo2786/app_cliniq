// test/dobles/mediciones.dart

/// Dobles de las mediciones del paciente y del escáner: las respuestas de
/// `/portal/mediciones` y una fuente de cuadros falsa que entrega una señal
/// sintética, sin cámara.
library;

import 'dart:async';

import 'package:app_cliniq/features/mediciones/data/models/medicion.dart';
import 'package:app_cliniq/features/mediciones/escaner/fuente_de_cuadros.dart';
import 'package:app_cliniq/features/mediciones/escaner/serie_senal.dart';
import 'package:flutter/widgets.dart';

import 'senales.dart';

/// Una medición como la devuelve el API.
Map<String, dynamic> medicionJson({
  String id = 'm1',
  String tipo = 'PA',
  num valor = 128,
  num? valor2 = 82,
  String metodo = 'DISPOSITIVO',
  double? calidad,
  String? contexto = 'REPOSO',
  String medidoEn = '2026-10-03T15:20:00.000Z',
  bool? experimental = false,
  String? usadaEnAtencionId,
  String? citaId,
}) => {
  '_id': id,
  'pacienteId': 'u1',
  'registradoPor': 'u1',
  'tipo': tipo,
  'valor': valor,
  'valor2': tipo == 'PA' ? valor2 : null,
  'unidad': switch (tipo) {
    'PA' => 'mmHg',
    'FC' => 'lpm',
    'FR' => 'rpm',
    'SPO2' => '%',
    'TEMP' => '°C',
    'GLUCOSA' => 'mg/dL',
    _ => 'kg',
  },
  'metodo': metodo,
  'calidad': calidad,
  'contexto': contexto,
  'medidoEn': medidoEn,
  'experimental': experimental,
  'usadaEnAtencionId': usadaEnAtencionId,
  'citaId': citaId,
  'creadoEn': medidoEn,
};

/// Una medición por enviar: el pulso de un aparato.
MedicionNueva medicionNueva({num valor = 78}) => MedicionNueva(
  tipo: TipoMedicion.fc,
  valor: valor,
  metodo: MetodoMedicion.dispositivo,
  medidoEn: DateTime.utc(2026, 10, 3, 15),
);

/// Los cuadros del modo dedo a partir de una serie sintética (el rojo de
/// cada cuadro), con la yema cubriendo la cámara.
List<CuadroPpg> cuadrosDeDedo(
  Serie serie, {
  double cobertura = 0.97,
  double saturacion = 0.02,
}) => [
  for (var i = 0; i < serie.tiempos.length; i++)
    CuadroPpg(
      momento: Duration(microseconds: (serie.tiempos[i] * 1e6).round()),
      rojo: serie.valores[i],
      verde: serie.valores[i] * 0.18,
      azul: serie.valores[i] * 0.12,
      luminancia: serie.valores[i] * 0.42,
      cobertura: cobertura,
      saturacion: saturacion,
    ),
];

/// Los cuadros del modo rostro a partir de una serie RGB sintética.
List<CuadroPpg> cuadrosDeRostro(SerieRgb serie, {double piel = 0.8}) => [
  for (var i = 0; i < serie.tiempos.length; i++)
    CuadroPpg(
      momento: Duration(microseconds: (serie.tiempos[i] * 1e6).round()),
      rojo: serie.rojo[i],
      verde: serie.verde[i],
      azul: serie.azul[i],
      luminancia:
          0.299 * serie.rojo[i] +
          0.587 * serie.verde[i] +
          0.114 * serie.azul[i],
      cobertura: piel,
    ),
];

/// Una fuente de cuadros falsa: sin cámara. La prueba decide qué cuadros
/// llegan ([emitir]) y si abrir falla ([errorAlAbrir]).
class FuenteFalsa implements FuenteDeCuadros {
  final StreamController<CuadroPpg> _salida =
      StreamController<CuadroPpg>.broadcast(sync: true);

  /// Si está puesto, abrir lanza este error.
  ErrorDeCamara? errorAlAbrir;

  final List<ModoEscaner> abiertas = [];
  int cerradas = 0;
  int ajustes = 0;

  bool get abierta => abiertas.length > cerradas;

  @override
  Stream<CuadroPpg> get cuadros => _salida.stream;

  @override
  Future<void> abrir(ModoEscaner modo) async {
    final error = errorAlAbrir;
    if (error != null) throw error;
    abiertas.add(modo);
  }

  void emitir(List<CuadroPpg> cuadros) {
    for (final c in cuadros) {
      _salida.add(c);
    }
  }

  @override
  Widget vistaPrevia(BuildContext context) => const ColoredBox(
    key: Key('vista-previa-falsa'),
    color: Color(0x00000000),
  );

  @override
  Future<void> cerrar() async {
    if (abierta) cerradas++;
  }

  @override
  Future<bool> abrirAjustes() async {
    ajustes++;
    return true;
  }
}
