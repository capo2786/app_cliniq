// lib/features/mediciones/dominio/ppg/constantes.dart

/// Las constantes del procesamiento de la PPG: la frecuencia de análisis,
/// las bandas del pulso y de la respiración y los mínimos.
library;

/// La frecuencia a la que se remuestrea toda señal antes de analizarla.
const double frecuenciaAnalisis = 30;

/// La banda de la frecuencia cardiaca: 42 a 210 latidos por minuto.
const double fcMinimaHz = 0.7;
const double fcMaximaHz = 3.5;

/// La banda de la frecuencia respiratoria: 6 a 30 respiraciones por minuto.
const double frMinimaHz = 0.1;
const double frMaximaHz = 0.5;

/// Con menos calidad que esta no se da la frecuencia respiratoria.
const double calidadMinimaFr = 0.6;

/// Cuántos segundos hacen falta, como mínimo, para dar un resultado.
const double segundosMinimos = 8;
