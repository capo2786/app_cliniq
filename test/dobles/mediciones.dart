// test/dobles/mediciones.dart

/// Dobles de las mediciones del paciente y del escáner: las respuestas de
/// `/portal/mediciones` y una fuente de cuadros falsa que entrega una señal
/// sintética, sin cámara.
library;

import 'package:app_cliniq/features/mediciones/data/models/medicion.dart';

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
