// lib/features/mediciones/escaner/mediciones_del_resultado.dart

import '../data/models/medicion.dart';
import '../dominio/destinos_medico.dart';
import 'motor_signos_camara.dart';

/// Las mediciones que se guardan de un resultado del escáner: la FC y, si
/// salió, la FR, con el método de la cámara, la calidad y el motor en las
/// notas. Nada más: el detalle y las gráficas se quedan en el teléfono.
///
/// Con [destino] van adjuntas a esa cita o consulta («Enviar a mi
/// médico»).
List<MedicionNueva> medicionesDelResultado(
  ResultadoEscaner r, {
  required DateTime medidoEn,
  ContextoMedicion? contexto,
  DestinoMedico? destino,
}) {
  MedicionNueva una(TipoMedicion tipo, int valor) => MedicionNueva(
    tipo: tipo,
    valor: valor,
    metodo: r.modo.metodo,
    calidad: double.parse(r.calidad.toStringAsFixed(2)),
    contexto: contexto,
    notas: r.notas,
    medidoEn: medidoEn.toUtc(),
    citaId: destino?.citaId,
    consultaId: destino?.consultaId,
  );

  return [
    una(TipoMedicion.fc, r.fc!),
    if (r.fr != null) una(TipoMedicion.fr, r.fr!),
  ];
}
