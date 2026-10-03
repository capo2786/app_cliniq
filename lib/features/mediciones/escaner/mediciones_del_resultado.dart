// lib/features/mediciones/escaner/mediciones_del_resultado.dart

import '../data/models/medicion.dart';
import '../dominio/detalle_medicion.dart';
import '../dominio/destinos_medico.dart';
import 'motor_signos_camara.dart';

/// Las mediciones que se guardan de un resultado del escáner: la FC y, si
/// salió, la FR, con el método de la cámara, la calidad y el motor en las
/// notas. La FC lleva el detalle (solo números: los datos y las gráficas
/// del resultado); la onda de la respiración, solo si la FR salió.
///
/// Con [destino] van adjuntas a esa cita o consulta («Enviar a mi
/// médico»).
List<MedicionNueva> medicionesDelResultado(
  ResultadoEscaner r, {
  required DateTime medidoEn,
  ContextoMedicion? contexto,
  DestinoMedico? destino,
}) {
  MedicionNueva una(TipoMedicion tipo, int valor, {DetalleMedicion? detalle}) =>
      MedicionNueva(
        tipo: tipo,
        valor: valor,
        metodo: r.modo.metodo,
        calidad: double.parse(r.calidad.toStringAsFixed(2)),
        contexto: contexto,
        notas: r.notas,
        medidoEn: medidoEn.toUtc(),
        citaId: destino?.citaId,
        consultaId: destino?.consultaId,
        detalle: detalle,
      );

  final detalle = r.detalle;
  return [
    una(
      TipoMedicion.fc,
      r.fc!,
      detalle: r.fr == null ? detalle?.sinRespiracion() : detalle,
    ),
    if (r.fr != null) una(TipoMedicion.fr, r.fr!),
  ];
}
