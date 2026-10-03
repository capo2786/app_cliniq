// lib/features/mediciones/dominio/ppg/calidad.dart

/// La calidad de la señal (SQI) y por qué sale baja.
library;

import 'estadistica.dart';

/// Por qué la calidad salió baja, para darle a la persona un consejo útil.
enum MotivoCalidad {
  /// La señal no cambia: la cámara no ve el pulso (nada delante, o la yema
  /// apenas apoyada).
  senalPlana,

  /// En el modo dedo, la yema no cubre la cámara.
  sinCobertura,

  /// La imagen está quemada: se aprieta demasiado o hay demasiada luz.
  saturada,

  /// Hay pulso, pero el movimiento lo tapa.
  movimiento,

  /// La cámara entregó muy pocos cuadros por segundo.
  pocosCuadros,

  /// Muy pocos segundos para decir algo.
  pocosDatos,
}

/// Lo que se sabe de la calidad de una señal, de 0 a 1.
class CalidadSenal {
  final double valor;

  /// Prominencia del pico espectral (0–1).
  final double prominencia;

  /// Diferencia en lpm entre el espectro y el conteo de picos, o `null` si
  /// no hubo picos que contar.
  final double? desacuerdo;

  /// Variación de los intervalos entre latidos.
  final double? variacion;

  final MotivoCalidad? motivo;

  const CalidadSenal({
    required this.valor,
    this.prominencia = 0,
    this.desacuerdo,
    this.variacion,
    this.motivo,
  });

  static const CalidadSenal nula = CalidadSenal(
    valor: 0,
    motivo: MotivoCalidad.pocosDatos,
  );
}

/// Lo que se midió de la cámara, además de la señal, en el modo dedo.
class CondicionesDedo {
  /// Fracción media de la imagen cubierta por la yema (roja y brillante).
  final double cobertura;

  /// Fracción media de píxeles quemados en el canal usado.
  final double saturacion;

  const CondicionesDedo({required this.cobertura, required this.saturacion});
}

/// La calidad (SQI) a partir de sus partes. Pública para probarla.
///
/// - La **prominencia** pesa más: por debajo de 0,25 no hay pulso que se
///   distinga del ruido; desde 0,65 el pulso domina la banda.
/// - El **acuerdo** entre el espectro y el conteo de picos: hasta 3 lpm de
///   diferencia es pleno; desde 12, nulo.
/// - La **regularidad** de los intervalos (coeficiente de variación hasta
///   0,12 pleno; desde 0,4, nulo): el movimiento los desordena.
/// - En el modo dedo, la **cobertura** (desde 0,85 plena, por debajo de
///   0,5 nula) y la **saturación** (hasta 0,3 sin castigo, desde 0,85
///   nula).
CalidadSenal calcularCalidad({
  required double prominencia,
  double? desacuerdo,
  double? variacion,
  CondicionesDedo? dedo,
}) {
  final pProminencia = rampa(prominencia, 0.25, 0.65);
  final pAcuerdo = desacuerdo == null ? 0.0 : rampa(desacuerdo, 12, 3);
  final pRegular = variacion == null ? 0.0 : rampa(variacion, 0.4, 0.12);

  var valor = pProminencia * (0.45 + 0.4 * pAcuerdo + 0.15 * pRegular);

  MotivoCalidad? motivo;
  if (pProminencia < 0.3) {
    motivo = MotivoCalidad.senalPlana;
  } else if (pAcuerdo < 0.5 || pRegular < 0.3) {
    motivo = MotivoCalidad.movimiento;
  }

  if (dedo != null) {
    final pCobertura = rampa(dedo.cobertura, 0.5, 0.85);
    final pSaturacion = rampa(dedo.saturacion, 0.85, 0.3);
    valor *= pCobertura * pSaturacion;
    if (pCobertura < 0.6) {
      motivo = MotivoCalidad.sinCobertura;
    } else if (pSaturacion < 0.6) {
      motivo = MotivoCalidad.saturada;
    }
  }

  valor = limitar01(valor);
  return CalidadSenal(
    valor: valor,
    prominencia: prominencia,
    desacuerdo: desacuerdo,
    variacion: variacion,
    motivo: valor >= 0.6 ? null : motivo,
  );
}
