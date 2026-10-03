// lib/features/mediciones/presentacion/detalle/ficha_medicion.dart

/// Lo que decide qué enseña «Detalle de la medición», sin Flutter: el caso
/// (con detalle, de la cámara sin él, de un aparato…), la otra medición del
/// mismo escaneo, las tarjetas, los datos y el origen del análisis.
///
/// Pura y probada (`test/detalle_medicion_page_test.dart`).
library;

import '../../data/cola_mediciones.dart';
import '../../data/models/medicion.dart';
import '../../dominio/rangos_referencia.dart';
import '../../dominio/reglas_mediciones.dart';
import '../../escaner/valores_del_resultado.dart';

/// Qué cuerpo lleva la pantalla.
enum CasoDeDetalle {
  /// El pulso de la cámara con su detalle: las tarjetas y las seis gráficas
  /// del resultado.
  conDetalle,

  /// El servidor guarda un detalle, pero todavía no llegó (cargando, sin
  /// red y sin copia) o no se pudo leer.
  detalleSinCargar,

  /// El pulso de la cámara de antes de que se guardara el detalle.
  anteriorAlDetalle,

  /// La respiración de la cámara: el detalle va con el pulso del mismo
  /// escaneo.
  respiracionDeCamara,

  /// Un aparato de casa o un registro a mano: los datos, sin gráficas.
  aparato,
}

/// El mensaje de las mediciones de la cámara de antes del detalle.
const String notaAnteriorAlDetalle =
    'Esta medición es anterior al detalle: las gráficas se guardan en las '
    'mediciones nuevas.';

/// El mensaje de la respiración de la cámara.
const String notaRespiracionDeCamara =
    'Las gráficas del escáner están en el pulso de esta misma medición.';

CasoDeDetalle casoDe(Medicion m) {
  if (!m.metodo.esCamara) return CasoDeDetalle.aparato;
  if (m.detalle != null) return CasoDeDetalle.conDetalle;
  if (m.tipo != TipoMedicion.fc) return CasoDeDetalle.respiracionDeCamara;
  return m.tieneDetalle
      ? CasoDeDetalle.detalleSinCargar
      : CasoDeDetalle.anteriorAlDetalle;
}

/// Hay que pedir la medición completa: no se tiene, o tiene un detalle que
/// todavía no llegó.
bool hayQuePedirla(Medicion? m) =>
    m == null || (m.tieneDetalle && m.detalle == null);

/// La otra medición del mismo escaneo (la FR del pulso o el pulso de la
/// FR): de la cámara, del mismo método y del mismo momento.
Medicion? companeraDe(Medicion m, Iterable<Medicion> otras) {
  if (!m.metodo.esCamara) return null;
  final otroTipo = switch (m.tipo) {
    TipoMedicion.fc => TipoMedicion.fr,
    TipoMedicion.fr => TipoMedicion.fc,
    _ => null,
  };
  if (otroTipo == null) return null;
  for (final o in otras) {
    if (o.id != m.id &&
        o.tipo == otroTipo &&
        o.metodo == m.metodo &&
        o.medidoEn.isAtSameMomentAs(m.medidoEn)) {
      return o;
    }
  }
  return null;
}

/// Las tarjetas del resultado para una medición de la cámara guardada: la
/// FC y la FR (de ella y de su compañera), la variabilidad calculada en el
/// teléfono si es válida y la calidad.
ValoresDelResultado valoresDeTarjetas(Medicion m, {Medicion? companera}) {
  int? valorDe(TipoMedicion tipo) => m.tipo == tipo
      ? m.valor.round()
      : companera?.tipo == tipo
      ? companera!.valor.round()
      : null;
  final pulso = m.tipo == TipoMedicion.fc ? m : companera;
  return ValoresDelResultado(
    fc: valorDe(TipoMedicion.fc),
    fr: valorDe(TipoMedicion.fr),
    vfc: vfcDelDetalle(pulso?.detalle),
    calidad: m.calidad ?? companera?.calidad,
  );
}

/// La línea del origen de una medición de la cámara, por el motor de sus
/// notas («motor: senales-ms 1.0.0»), o `null` si no se sabe.
String? origenDelAnalisis(String? notas) {
  final texto = notas?.trim() ?? '';
  if (!texto.startsWith('motor:')) return null;
  final motor = texto.substring('motor:'.length).trim();
  if (motor.startsWith('senales-ms')) {
    return 'Analizado en el servidor (experimental)';
  }
  if (motor.startsWith('interno')) return 'Calculado en el teléfono';
  return null;
}

/// Las notas que escribió la persona (sin la línea del motor).
String? notasVisibles(String? notas) {
  final texto = notas?.trim();
  return texto == null || texto.isEmpty || texto.startsWith('motor:')
      ? null
      : texto;
}

/// Los datos de una medición de un aparato o a mano, para las tarjetas
/// pequeñas: la sistólica y la diastólica en la presión (o el valor), el
/// rango de referencia, el momento y cómo se midió.
List<(String, String)> datosDeMedicion(Medicion m) {
  final unidad = m.unidad ?? unidadDelTipo(m.tipo);
  final rango = etiquetaDeRango(m.tipo, m.valor, valor2: m.valor2);
  return [
    if (m.tipo == TipoMedicion.pa && m.valor2 != null) ...[
      ('Sistólica (la alta)', '${numeroLegible(m.valor)} $unidad'),
      ('Diastólica (la baja)', '${numeroLegible(m.valor2!)} $unidad'),
    ] else
      (nombreDelTipo(m.tipo), valorDeMedicion(m)),
    ?(rango == null ? null : ('Referencia', rango)),
    ?(m.contexto == null ? null : ('Momento', nombreDelContexto(m.contexto!))),
    ('Cómo se midió', nombreDelMetodo(m.metodo)),
  ];
}

/// Una medición de la cola, como si fuera del servidor, para enseñarla con
/// la misma pantalla (con un identificador local).
Medicion medicionDePendiente(MedicionNueva n, {required String id}) => Medicion(
  id: id,
  tipo: n.tipo,
  valor: n.valor,
  valor2: n.valor2,
  metodo: n.metodo,
  calidad: n.calidad,
  contexto: n.contexto,
  notas: n.notas,
  medidoEn: n.medidoEn,
  citaId: n.citaId,
  consultaId: n.consultaId,
  experimental: n.metodo.esCamara,
  detalle: n.admiteDetalle ? n.detalle : null,
  tieneDetalle: n.admiteDetalle && n.detalle != null,
);

/// Las mediciones de un envío pendiente, ya como [Medicion]: primero la
/// que lleva el detalle (el pulso de la cámara), si hay.
List<Medicion> medicionesDelEnvio(EnvioPendiente envio) {
  final todas = [
    for (final (i, n) in envio.mediciones.indexed)
      medicionDePendiente(n, id: '${envio.idLocal}-$i'),
  ];
  final conDetalle = todas.indexWhere((m) => m.detalle != null);
  if (conDetalle > 0) todas.insert(0, todas.removeAt(conDetalle));
  return todas;
}
