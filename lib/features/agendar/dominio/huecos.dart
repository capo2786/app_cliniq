// lib/features/agendar/dominio/huecos.dart

/// Qué horarios se le pueden ofrecer a un paciente con un médico.
///
/// Puerto 1:1 de `features/agenda/calendario/agenda.utils.ts` del panel web
/// (las funciones de agenda) y de la lógica de `portal/agendar/agendar.ts`
/// que elige el primer día. Los nombres son los mismos para poder
/// compararlos línea a línea. Todo es aritmética pura: el «ahora» llega como
/// parámetro y las pruebas lo fijan.
///
/// Todas las fechas son hora local de la clínica (ver `fecha_local.dart`).
/// El servidor vuelve a validar todo al guardar; esto existe para no ofrecer
/// horarios que después se rechazarían.
library;

import '../../../core/fechas/fecha_local.dart';
import '../../../core/formato/fechas.dart';
import 'horarios.dart';

/// Cada cuánto empieza un horario posible al agendar.
const int pasoMinutos = 15;

/// Con cuánta anticipación mínima se puede tomar un horario de hoy: una cita
/// que empieza en cinco minutos no le sirve a nadie.
const int minutosAnticipacion = 15;

/// Hasta cuántos días adelante se busca el siguiente día con atención.
const int diasBusqueda = 60;

/// Mañana, tarde o noche: los horarios se agrupan así en la pantalla.
enum Periodo {
  manana('Mañana'),
  tarde('Tarde'),
  noche('Noche');

  final String titulo;

  const Periodo(this.titulo);
}

/// Un intervalo que ya ocupa la agenda del médico.
///
/// El portal solo recibe inicio y fin de lo ocupado —nunca datos de otros
/// pacientes—, que es justo lo que hace falta para calcular los huecos.
class IntervaloOcupado {
  final String id;
  final DateTime inicio;
  final DateTime fin;

  /// Si todavía ocupa el horario (una cita cancelada lo libera).
  final bool ocupaHorario;

  const IntervaloOcupado({
    required this.id,
    required this.inicio,
    required this.fin,
    this.ocupaHorario = true,
  });

  @override
  bool operator ==(Object other) =>
      other is IntervaloOcupado &&
      other.id == id &&
      other.inicio == inicio &&
      other.fin == fin &&
      other.ocupaHorario == ocupaHorario;

  @override
  int get hashCode => Object.hash(id, inicio, fin, ocupaHorario);
}

/// Un horario que se puede ofrecer.
class Hueco {
  /// «09:30»
  final String hora;
  final DateTime inicio;
  final DateTime fin;
  final bool ocupado;
  final Periodo periodo;

  const Hueco({
    required this.hora,
    required this.inicio,
    required this.fin,
    required this.ocupado,
    required this.periodo,
  });

  @override
  bool operator ==(Object other) =>
      other is Hueco &&
      other.hora == hora &&
      other.inicio == inicio &&
      other.fin == fin &&
      other.ocupado == ocupado &&
      other.periodo == periodo;

  @override
  int get hashCode => Object.hash(hora, inicio, fin, ocupado, periodo);

  @override
  String toString() => 'Hueco($hora${ocupado ? ', ocupado' : ''})';
}

int minutosDelDia(DateTime fecha) => fecha.hour * 60 + fecha.minute;

/// El día dado a la hora indicada en minutos desde la medianoche.
DateTime _conMinutos(DateTime dia, int minutos) =>
    DateTime(dia.year, dia.month, dia.day, minutos ~/ 60, minutos % 60);

/// Los turnos de atención de ese día de la semana, válidos y en orden.
List<HorarioRango> rangosDelDia(List<HorarioDia>? horarios, DateTime fecha) {
  final nombre = nombreDelDia(fecha);
  final dia = normalizarHorarios(
    horarios,
  ).where((d) => d.dia == nombre).firstOrNull;

  if (dia == null || !dia.activo) return const [];

  return dia.rangos
      .where(
        (r) =>
            r.inicio.isNotEmpty &&
            r.fin.isNotEmpty &&
            aMinutos(r.fin) > aMinutos(r.inicio),
      )
      .toList()
    ..sort((a, b) => aMinutos(a.inicio).compareTo(aMinutos(b.inicio)));
}

/// Máximo de citas por día del médico; 0 = sin límite.
int limiteDiario(MedicoConAgenda? medico) {
  final limite = medico?.configAgenda?.limiteDiario ?? 0;

  return limite > 0 ? limite : 0;
}

/// Citas que todavía ocupan la agenda ese día, sin contar la que se
/// reprograma.
int _citasActivasDelDia(
  List<IntervaloOcupado> citas,
  DateTime fecha,
  String? excluirId,
) {
  return citas
      .where(
        (c) => c.ocupaHorario && c.id != excluirId && mismoDia(c.inicio, fecha),
      )
      .length;
}

bool limiteAlcanzado(
  MedicoConAgenda? medico,
  List<IntervaloOcupado> citas,
  DateTime fecha, {
  String? excluirId,
}) {
  final limite = limiteDiario(medico);

  return limite > 0 && _citasActivasDelDia(citas, fecha, excluirId) >= limite;
}

/// El próximo día (después de `desde`) en que se le puede dar cita al
/// médico: trabaja ese día de la semana, no está bloqueado y, si se pasan
/// sus citas, no llegó a su límite diario.
DateTime? siguienteDiaConAtencion(
  MedicoConAgenda? medico,
  DateTime desde, {
  List<IntervaloOcupado>? citas,
  String? excluirId,
}) {
  for (var i = 1; i <= diasBusqueda; i++) {
    final dia = sumarDias(inicioDelDia(desde), i);

    if (rangosDelDia(medico?.horariosAtencion, dia).isNotEmpty &&
        bloqueoEn(medico, dia) == null &&
        !(citas != null &&
            limiteAlcanzado(medico, citas, dia, excluirId: excluirId))) {
      return dia;
    }
  }

  return null;
}

/// Los horarios que se pueden ofrecer ese día.
///
/// Un horario solo aparece si cabe entero dentro de un turno —una consulta
/// de 30 minutos no puede empezar a las 12:45 si el turno acaba a las
/// 13:00—, y se marca ocupado si se cruza con cualquier cita que todavía
/// ocupa la agenda, salvo la que se reprograma. El margen del médico se suma
/// a cada lado de sus citas: con 10 minutos, una cita de 09:00 a 09:30
/// bloquea de 08:50 a 09:40.
List<Hueco> calcularHuecos({
  required DateTime fecha,
  required List<HorarioRango> rangos,
  required int duracion,
  int margen = 0,
  required List<IntervaloOcupado> citas,
  String? excluirId,
  required DateTime ahora,
}) {
  final margenDuracion = Duration(minutes: margen < 0 ? 0 : margen);
  final ocupan = citas
      .where(
        (c) => c.ocupaHorario && c.id != excluirId && mismoDia(c.inicio, fecha),
      )
      .toList();
  final vistos = <String>{};
  final huecos = <Hueco>[];

  for (final rango in rangos) {
    final finRango = aMinutos(rango.fin);

    for (
      var m = aMinutos(rango.inicio);
      m + duracion <= finRango;
      m += pasoMinutos
    ) {
      final hora = aHora(m);
      final inicio = _conMinutos(fecha, m);
      if (vistos.contains(hora) || !inicio.isAfter(ahora)) continue;

      final fin = inicio.add(Duration(minutes: duracion));
      vistos.add(hora);
      huecos.add(
        Hueco(
          hora: hora,
          inicio: inicio,
          fin: fin,
          ocupado: ocupan.any(
            (c) =>
                inicio.isBefore(c.fin.add(margenDuracion)) &&
                c.inicio.subtract(margenDuracion).isBefore(fin),
          ),
          periodo: m < 12 * 60
              ? Periodo.manana
              : m < 19 * 60
              ? Periodo.tarde
              : Periodo.noche,
        ),
      );
    }
  }

  return huecos..sort((a, b) => a.inicio.compareTo(b.inicio));
}

/// Los huecos agrupados por periodo, en orden: mañana, tarde, noche.
Map<Periodo, List<Hueco>> agruparPorPeriodo(List<Hueco> huecos) => {
  for (final periodo in Periodo.values)
    periodo: huecos.where((h) => h.periodo == periodo).toList(),
};

/// El «ahora» contra el que se ofrecen horarios: la hora actual más la
/// anticipación mínima.
DateTime ahoraConAnticipacion(DateTime ahora) =>
    ahora.add(const Duration(minutes: minutosAnticipacion));

/// Si hoy todavía cabe una cita de `duracion` minutos con el médico.
///
/// Igual que en el web: hoy vale si no está bloqueado y algún turno termina
/// lo bastante tarde como para que quepa una cita después de «ahora» (con la
/// anticipación ya sumada).
bool quedaHoy(MedicoConAgenda medico, int duracion, DateTime ahora) {
  final hoy = inicioDelDia(ahora);
  final limite = ahoraConAnticipacion(ahora);

  return bloqueoEn(medico, hoy) == null &&
      rangosDelDia(medico.horariosAtencion, hoy).any(
        (r) => hoy
            .add(Duration(minutes: aMinutos(r.fin) - duracion))
            .isAfter(limite),
      );
}

/// El primer día con atención: hoy solo si aún cabe una cita; si no, el
/// siguiente día con atención.
DateTime? primerDiaConAtencion(
  MedicoConAgenda medico,
  int duracion,
  DateTime ahora,
) {
  final hoy = inicioDelDia(ahora);

  return quedaHoy(medico, duracion, ahora)
      ? hoy
      : siguienteDiaConAtencion(medico, hoy);
}

/// «Hoy», «Lun 28 sep» o «Sin fechas próximas», para la tarjeta del médico.
String proximaFecha(MedicoConAgenda medico, int duracion, DateTime ahora) {
  final hoy = inicioDelDia(ahora);

  if (quedaHoy(medico, duracion, ahora)) return 'Hoy';

  final dia = siguienteDiaConAtencion(medico, hoy);

  return dia == null ? 'Sin fechas próximas' : FormatoFecha.diaMedio(dia);
}

/// Los próximos días con atención a partir de `desde` (incluido si atiende),
/// para la tira de fechas. Salta los días que no trabaja y los bloqueados.
List<DateTime> diasConAtencion(
  MedicoConAgenda medico,
  DateTime desde, {
  int cantidad = 21,
}) {
  final dias = <DateTime>[];
  final inicio = inicioDelDia(desde);

  if (rangosDelDia(medico.horariosAtencion, inicio).isNotEmpty &&
      bloqueoEn(medico, inicio) == null) {
    dias.add(inicio);
  }

  var cursor = inicio;
  while (dias.length < cantidad) {
    final siguiente = siguienteDiaConAtencion(medico, cursor);
    if (siguiente == null) break;

    dias.add(siguiente);
    cursor = siguiente;
  }

  return dias;
}
