// lib/features/mediciones/dominio/tendencias.dart

/// Las «Tendencias» de «Mis signos vitales»: por cada tipo con datos en el
/// periodo, el último valor, el mínimo, el promedio y el máximo, y los
/// puntos para la gráfica (los de la cámara marcados aparte de los de los
/// aparatos). Puro y probado: solo cuenta lo registrado, nunca rellena.
library;

import 'dart:math' as math;

import '../data/models/medicion.dart';

/// El periodo de las tendencias.
enum PeriodoTendencia {
  semana(7, '7 días'),
  mes(30, '30 días'),
  trimestre(90, '3 meses');

  final int dias;
  final String nombre;

  const PeriodoTendencia(this.dias, this.nombre);

  /// Desde cuándo cuenta, visto desde [ahora].
  DateTime desde(DateTime ahora) => ahora.subtract(Duration(days: dias));
}

/// Un punto de la gráfica: cuándo, el valor (y la diastólica en la
/// presión) y si salió de la cámara.
typedef PuntoTendencia = ({
  DateTime instante,
  double valor,
  double? valor2,
  bool deCamara,
});

/// El mínimo, el promedio y el máximo de unos valores.
typedef Resumen = ({double minimo, double promedio, double maximo});

class TendenciaDelTipo {
  final TipoMedicion tipo;

  /// La medición más reciente del periodo.
  final Medicion ultima;

  /// De la más antigua a la más reciente.
  final List<PuntoTendencia> puntos;

  final Resumen resumen;

  /// En la presión, el de la diastólica.
  final Resumen? resumen2;

  const TendenciaDelTipo({
    required this.tipo,
    required this.ultima,
    required this.puntos,
    required this.resumen,
    this.resumen2,
  });

  bool get conCamara => puntos.any((p) => p.deCamara);
  bool get conAparatos => puntos.any((p) => !p.deCamara);
}

/// El orden de las tarjetas.
const List<TipoMedicion> ordenDeTendencias = [
  TipoMedicion.fc,
  TipoMedicion.pa,
  TipoMedicion.spo2,
  TipoMedicion.temp,
  TipoMedicion.glucosa,
  TipoMedicion.peso,
  TipoMedicion.fr,
];

bool esDeCamara(MetodoMedicion metodo) =>
    metodo == MetodoMedicion.camaraDedo ||
    metodo == MetodoMedicion.camaraRostro;

Resumen? _resumir(Iterable<double> valores) {
  if (valores.isEmpty) return null;
  final lista = valores.toList();
  return (
    minimo: lista.reduce(math.min),
    promedio: lista.reduce((a, b) => a + b) / lista.length,
    maximo: lista.reduce(math.max),
  );
}

/// Las tendencias de [mediciones] en el [periodo] que termina [ahora], en
/// el orden de [ordenDeTendencias]; solo los tipos con datos.
List<TendenciaDelTipo> calcularTendencias(
  List<Medicion> mediciones,
  PeriodoTendencia periodo,
  DateTime ahora,
) {
  final desde = periodo.desde(ahora);
  final tendencias = <TendenciaDelTipo>[];
  for (final tipo in ordenDeTendencias) {
    final delTipo = [
      for (final m in mediciones)
        if (m.tipo == tipo &&
            !m.medidoEn.isBefore(desde) &&
            !m.medidoEn.isAfter(ahora.add(const Duration(minutes: 5))))
          m,
    ]..sort((a, b) => a.medidoEn.compareTo(b.medidoEn));
    if (delTipo.isEmpty) continue;

    final puntos = [
      for (final m in delTipo)
        (
          instante: m.medidoEn,
          valor: m.valor.toDouble(),
          valor2: m.valor2?.toDouble(),
          deCamara: esDeCamara(m.metodo),
        ),
    ];
    tendencias.add(
      TendenciaDelTipo(
        tipo: tipo,
        ultima: delTipo.last,
        puntos: puntos,
        resumen: _resumir(puntos.map((p) => p.valor))!,
        resumen2: tipo == TipoMedicion.pa
            ? _resumir([
                for (final p in puntos)
                  if (p.valor2 != null) p.valor2!,
              ])
            : null,
      ),
    );
  }
  return tendencias;
}
