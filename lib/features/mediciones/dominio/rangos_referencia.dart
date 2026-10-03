// lib/features/mediciones/dominio/rangos_referencia.dart

/// Los rangos de **referencia para adultos** de cada signo vital: los que
/// se usan para decir «En rango», «Alta» o «Baja» y para la franja verde
/// de las gráficas. No son los rangos que acepta el servidor
/// (`rangoDelTipo`, mucho más anchos: solo descartan errores de tipeo).
///
/// Son los mismos que usa el panel de la clínica. Referenciales: el médico
/// es quien interpreta cada valor.
library;

import '../data/models/medicion.dart';
import 'reglas_mediciones.dart';

/// Un rango de referencia, con una nota si depende del momento («en
/// ayunas»).
class RangoReferencia {
  final num minimo;
  final num maximo;
  final String? nota;

  const RangoReferencia(this.minimo, this.maximo, {this.nota});

  bool contiene(num valor) => valor >= minimo && valor <= maximo;

  /// «60–100», «36,0–37,5».
  String texto({int decimales = 0}) =>
      '${_numero(minimo, decimales)}–${_numero(maximo, decimales)}';

  static String _numero(num v, int decimales) => decimales == 0
      ? numeroLegible(v)
      : v.toStringAsFixed(decimales).replaceAll('.', ',');
}

/// El rango de referencia de cada tipo (la sistólica, en la presión), o
/// `null` si no tiene (el peso depende de cada persona).
RangoReferencia? referenciaDelTipo(TipoMedicion tipo) => switch (tipo) {
  TipoMedicion.fc => const RangoReferencia(60, 100),
  TipoMedicion.fr => const RangoReferencia(12, 20),
  TipoMedicion.pa => const RangoReferencia(90, 120),
  TipoMedicion.spo2 => const RangoReferencia(95, 100),
  TipoMedicion.temp => const RangoReferencia(36.0, 37.5),
  TipoMedicion.glucosa => const RangoReferencia(70, 100, nota: 'en ayunas'),
  TipoMedicion.peso => null,
};

/// La diastólica de la presión.
const RangoReferencia referenciaDiastolica = RangoReferencia(60, 80);

/// El texto que va debajo de cada gráfica con franja.
String leyendaDeReferencia(TipoMedicion tipo) {
  final nota = referenciaDelTipo(tipo)?.nota;
  return nota == null
      ? 'Referencia para adultos'
      : 'Referencia para adultos ($nota)';
}

enum EstadoDeRango { bajo, enRango, alto }

/// Dónde cae un valor respecto de su referencia, o `null` si el tipo no
/// tiene. En la presión cuentan las dos: alta si cualquiera pasa de su
/// máximo, baja si cualquiera queda por debajo de su mínimo.
EstadoDeRango? estadoDeRango(TipoMedicion tipo, num valor, {num? valor2}) {
  final rango = referenciaDelTipo(tipo);
  if (rango == null) return null;
  final altos = [
    valor > rango.maximo,
    if (tipo == TipoMedicion.pa && valor2 != null)
      valor2 > referenciaDiastolica.maximo,
  ];
  final bajos = [
    valor < rango.minimo,
    if (tipo == TipoMedicion.pa && valor2 != null)
      valor2 < referenciaDiastolica.minimo,
  ];
  if (altos.contains(true)) return EstadoDeRango.alto;
  if (bajos.contains(true)) return EstadoDeRango.bajo;
  return EstadoDeRango.enRango;
}

/// «En rango (60–100)», «Alta» o «Baja»; `null` si no hay referencia.
String? etiquetaDeRango(TipoMedicion tipo, num valor, {num? valor2}) {
  final estado = estadoDeRango(tipo, valor, valor2: valor2);
  if (estado == null) return null;
  final rango = referenciaDelTipo(tipo)!;
  final decimales = tipo == TipoMedicion.temp ? 1 : 0;
  final texto = tipo == TipoMedicion.pa
      ? '${rango.texto()} / ${referenciaDiastolica.texto()}'
      : rango.texto(decimales: decimales);
  return switch (estado) {
    EstadoDeRango.enRango =>
      rango.nota == null
          ? 'En rango ($texto)'
          : 'En rango ($texto, ${rango.nota})',
    EstadoDeRango.alto => 'Alta',
    EstadoDeRango.bajo => 'Baja',
  };
}
