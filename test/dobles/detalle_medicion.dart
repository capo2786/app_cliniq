// test/dobles/detalle_medicion.dart

/// Dobles del «Detalle de la medición»: un detalle medido de verdad (dedo a
/// 72 lpm, 31 s, con respiración) y el pulso y la respiración de un mismo
/// escaneo como los da la lista.
library;

import 'package:app_cliniq/features/mediciones/dominio/detalle_medicion.dart';
import 'package:app_cliniq/features/mediciones/escaner/motor_signos_camara.dart';
import 'package:app_cliniq/features/mediciones/escaner/serie_senal.dart';

import 'mediciones.dart';
import 'senales.dart';

DetalleMedicion detalleMedido({int semilla = 91}) {
  final serie = SerieSenal.de(
    ModoEscaner.dedo,
    cuadrosDeDedo(
      Sintetizador(semilla).dedo(lpm: 72, segundos: 31, respiracionRpm: 15),
    ),
  );
  return const MotorInterno().analizar(serie).detalle!;
}

/// El pulso de la cámara como lo da la lista (sin el detalle).
Map<String, dynamic> pulsoEnLista({bool tieneDetalle = true}) => medicionJson(
  id: 'fc1',
  tipo: 'FC',
  valor: 72,
  metodo: 'CAMARA_DEDO',
  calidad: 0.86,
  contexto: 'REPOSO',
  medidoEn: '2026-10-02T14:00:00.000Z',
)..addAll({'notas': 'motor: interno-ppg v1', 'tieneDetalle': tieneDetalle});

/// La respiración del mismo escaneo.
Map<String, dynamic> respiracionEnLista() => medicionJson(
  id: 'fr1',
  tipo: 'FR',
  valor: 15,
  metodo: 'CAMARA_DEDO',
  calidad: 0.86,
  contexto: 'REPOSO',
  medidoEn: '2026-10-02T14:00:00.000Z',
)..['notas'] = 'motor: interno-ppg v1';
