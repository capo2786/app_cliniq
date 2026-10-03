// lib/features/mediciones/escaner/valores_del_resultado.dart

import '../dominio/detalle_medicion.dart';
import 'motor_signos_camara.dart';

/// Lo que enseñan las tarjetas del resultado (`TarjetasResultado`): la FC,
/// la FR, la variabilidad y la calidad. Sale del resultado del escáner o de
/// una medición guardada, para que las dos pantallas enseñen las mismas
/// tarjetas.
class ValoresDelResultado {
  final int? fc;
  final int? fr;
  final Vfc? vfc;

  /// De 0 a 1.
  final double? calidad;

  const ValoresDelResultado({this.fc, this.fr, this.vfc, this.calidad});

  /// Del resultado del escáner: la variabilidad del servidor o, si no vino,
  /// la del teléfono cuando alcanza para enseñarse.
  factory ValoresDelResultado.deResultado(ResultadoEscaner r) =>
      ValoresDelResultado(
        fc: r.fc,
        fr: r.fr,
        vfc: r.vfc ?? vfcDelDetalle(r.detalle),
        calidad: r.calidad,
      );

  /// No hay ninguna tarjeta que enseñar.
  bool get vacio => fc == null && fr == null && vfc == null && calidad == null;
}

/// SDNN y RMSSD calculados en el teléfono, solo si la variabilidad del
/// [detalle] es válida (buena calidad, 30 s, 20 intervalos y como mucho un
/// 10 % corregidos).
Vfc? vfcDelDetalle(DetalleMedicion? detalle) {
  final m = detalle?.metricasVfc;
  return m == null ? null : Vfc(sdnn: m.sdnn, rmssd: m.rmssd);
}
