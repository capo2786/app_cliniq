// lib/features/agendar/dominio/huecos.dart

/// Cómo se enseñan los turnos libres que calcula la API.
///
/// Antes este archivo calculaba los huecos a partir de la jornada del médico
/// y de lo ocupado, en un puerto del cálculo del panel web. Ahora la API
/// calcula los turnos libres con las mismas reglas con que valida la reserva
/// (`GET /portal/turnos/:doctorId`), y aquí solo queda la presentación: los
/// días que tienen turnos, los turnos de un día agrupados en mañana, tarde y
/// noche, y las palabras con que se dice cuándo es un turno («hoy», «mañana»,
/// «lun 29»).
///
/// Todo es aritmética pura: el «ahora» llega como parámetro y las pruebas lo
/// fijan. Todas las fechas son hora local de la clínica (ver
/// `fecha_local.dart`).
library;

import '../../../core/fechas/fecha_local.dart';
import '../../../core/formato/fechas.dart';
import '../data/models/turnos.dart';
import 'reglas_agendamiento.dart';

export 'reglas_agendamiento.dart';

/*
 * Los cortes de mañana, tarde y noche y la anticipación mínima son los de la
 * configuración de la clínica (ver `ReglasAgendamiento`): llegan como
 * parámetro, nunca escritos aquí.
 */

/// Mañana, tarde o noche: los horarios se agrupan así en la pantalla.
enum Periodo {
  manana('Mañana'),
  tarde('Tarde'),
  noche('Noche');

  final String titulo;

  const Periodo(this.titulo);
}

/// Un turno libre, listo para pintarse como ficha.
class Hueco {
  /// «09:30»
  final String hora;
  final DateTime inicio;
  final DateTime fin;
  final Periodo periodo;

  const Hueco({
    required this.hora,
    required this.inicio,
    required this.fin,
    required this.periodo,
  });

  /// La ficha de un turno de la API.
  factory Hueco.deTurno(Turno turno, ReglasAgendamiento reglas) => Hueco(
    hora: FormatoFecha.hora(turno.inicio),
    inicio: turno.inicio,
    fin: turno.fin,
    periodo: periodoDe(minutosDelDia(turno.inicio), reglas),
  );

  /// Si es el mismo horario que [otro]: mismo inicio y mismo fin.
  bool mismoHorario(Hueco otro) => otro.inicio == inicio && otro.fin == fin;

  @override
  bool operator ==(Object other) =>
      other is Hueco &&
      other.hora == hora &&
      other.inicio == inicio &&
      other.fin == fin &&
      other.periodo == periodo;

  @override
  int get hashCode => Object.hash(hora, inicio, fin, periodo);

  @override
  String toString() => 'Hueco(${fechaIso(inicio)} $hora)';
}

int minutosDelDia(DateTime fecha) => fecha.hour * 60 + fecha.minute;

/// Mañana, tarde o noche según los cortes de la clínica.
Periodo periodoDe(int minutoDelDia, ReglasAgendamiento reglas) =>
    minutoDelDia < reglas.minutoInicioTarde
    ? Periodo.manana
    : minutoDelDia < reglas.minutoInicioNoche
    ? Periodo.tarde
    : Periodo.noche;

/// Los huecos agrupados por periodo, en orden: mañana, tarde, noche.
Map<Periodo, List<Hueco>> agruparPorPeriodo(List<Hueco> huecos) => {
  for (final periodo in Periodo.values)
    periodo: huecos.where((h) => h.periodo == periodo).toList(),
};

/// El «ahora» contra el que todavía se puede tomar un turno: la hora actual
/// más la anticipación mínima de la clínica.
///
/// La API ya aplica la anticipación al calcular los turnos. Esto solo sirve
/// para no seguir ofreciendo, en una pantalla que lleva un rato abierta, un
/// turno que entretanto dejó de cumplirla.
DateTime ahoraConAnticipacion(DateTime ahora, ReglasAgendamiento reglas) =>
    ahora.add(Duration(minutes: reglas.minutosAnticipacion));

/// Los turnos que todavía se pueden ofrecer: los que empiezan después de
/// [limite] y no están en [descartados] (los que el servidor rechazó por
/// estar tomados).
List<Turno> turnosVigentes(
  List<Turno> turnos, {
  required DateTime limite,
  Set<DateTime> descartados = const {},
}) => [
  for (final t in turnos)
    if (t.inicio.isAfter(limite) && !descartados.contains(t.inicio)) t,
];

/// Los días que tienen algún turno, en orden.
List<DateTime> diasConTurnos(List<Turno> turnos) {
  final dias = <DateTime>{for (final t in turnos) inicioDelDia(t.inicio)};

  return dias.toList()..sort();
}

/// Las fichas de los turnos de ese día, en orden.
List<Hueco> huecosDelDia(
  List<Turno> turnos,
  DateTime dia,
  ReglasAgendamiento reglas,
) {
  return [
    for (final t in turnos)
      if (mismoDia(t.inicio, dia)) Hueco.deTurno(t, reglas),
  ]..sort((a, b) => a.inicio.compareTo(b.inicio));
}

/// El día en palabras naturales: «hoy», «mañana», «lun 29» dentro de la
/// semana que viene y «lun 12 oct» más allá, donde el número solo ya no
/// dice de qué mes es.
String diaNatural(DateTime fecha, DateTime ahora) {
  final hoy = inicioDelDia(ahora);
  final dia = inicioDelDia(fecha);

  if (dia == hoy) return 'hoy';
  if (dia == sumarDias(hoy, 1)) return 'mañana';

  final corto = '${FormatoFecha.diaCorto(dia).toLowerCase()} ${dia.day}';
  final cercano = dia.isAfter(hoy) && dia.isBefore(sumarDias(hoy, 7));

  return cercano
      ? corto
      : '$corto ${FormatoFecha.mesCortoMayusculas(dia).toLowerCase()}';
}

/// «hoy a las 15:30», «mañana a las 09:00», «lun 29 a las 09:00».
String turnoNatural(DateTime inicio, DateTime ahora) =>
    '${diaNatural(inicio, ahora)} a las ${FormatoFecha.hora(inicio)}';

/// «1 médico», «3 médicos».
String cantidadDeMedicos(int cantidad) =>
    cantidad == 1 ? '1 médico' : '$cantidad médicos';

/// «3 médicos · próximo turno hoy a las 15:30», o solo «3 médicos» si no
/// se sabe cuándo es el próximo.
String resumenDisponibilidad(int medicos, DateTime? proximo, DateTime ahora) {
  final cantidad = cantidadDeMedicos(medicos);

  return proximo == null
      ? cantidad
      : '$cantidad · próximo turno ${turnoNatural(proximo, ahora)}';
}
