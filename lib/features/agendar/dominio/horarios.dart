// lib/features/agendar/dominio/horarios.dart

/// Jornada, configuración de agenda y bloqueos de un médico.
///
/// Es el puerto 1:1 de `core/models/horarios.model.ts` del panel web: los
/// mismos nombres, las mismas reglas y los mismos valores por defecto. Si el
/// web cambia una regla, se cambia aquí igual; dos lecturas distintas del
/// mismo horario harían que la aplicación ofreciera horas que el panel no.
library;

import '../../../core/fechas/fecha_local.dart';
import '../../citas/data/models/cita.dart';
import 'reglas_agendamiento.dart';

/// Los días de la semana con los nombres que guarda la API.
const List<String> diasSemana = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

/// El nombre del día con el índice de `Date.getDay()` de JavaScript
/// (domingo = 0). En Dart se llega con `fecha.weekday % 7`.
const List<String> diaPorIndice = [
  'Domingo',
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
];

/// El nombre del día de una fecha, como lo guarda la API.
String nombreDelDia(DateTime fecha) => diaPorIndice[fecha.weekday % 7];

/// Un turno de atención: «09:00» a «13:00».
class HorarioRango {
  final String inicio;
  final String fin;

  const HorarioRango({required this.inicio, required this.fin});

  factory HorarioRango.desdeJson(Map<dynamic, dynamic> json) => HorarioRango(
    inicio: json['inicio']?.toString() ?? '',
    fin: json['fin']?.toString() ?? '',
  );

  Map<String, dynamic> aJson() => {'inicio': inicio, 'fin': fin};

  @override
  bool operator ==(Object other) =>
      other is HorarioRango && other.inicio == inicio && other.fin == fin;

  @override
  int get hashCode => Object.hash(inicio, fin);

  @override
  String toString() => '$inicio–$fin';
}

/// La jornada de un día de la semana.
class HorarioDia {
  final String dia;
  final bool activo;
  final List<HorarioRango> rangos;

  const HorarioDia({
    required this.dia,
    required this.activo,
    required this.rangos,
  });

  factory HorarioDia.desdeJson(Map<dynamic, dynamic> json) => HorarioDia(
    dia: json['dia']?.toString() ?? '',
    activo: json['activo'] == true,
    rangos: [
      for (final rango in (json['rangos'] as List?) ?? const [])
        if (rango is Map) HorarioRango.desdeJson(rango),
    ],
  );

  Map<String, dynamic> aJson() => {
    'dia': dia,
    'activo': activo,
    'rangos': [for (final r in rangos) r.aJson()],
  };
}

/// Cómo arma su agenda cada médico: duración por modalidad, margen entre
/// pacientes y máximo de citas por día. Lo que no configura cae en los
/// valores de la clínica (`ReglasAgendamiento`).
class ConfigAgenda {
  /// Minutos por modalidad (código de la API → minutos).
  final Map<String, int> duraciones;

  /// Minutos libres obligatorios entre una cita y la siguiente.
  final int? margenMinutos;

  /// Máximo de citas por día; 0 o vacío = sin límite.
  final int? limiteDiario;

  const ConfigAgenda({
    this.duraciones = const {},
    this.margenMinutos,
    this.limiteDiario,
  });

  static ConfigAgenda? desdeJson(Object? json) {
    if (json is! Map) return null;

    final duraciones = <String, int>{};
    final crudas = json['duraciones'];
    if (crudas is Map) {
      for (final entrada in crudas.entries) {
        final minutos = entrada.value;
        if (minutos is num) {
          duraciones[entrada.key.toString().toUpperCase()] = minutos.toInt();
        }
      }
    }

    int? entero(Object? valor) => valor is num ? valor.toInt() : null;

    return ConfigAgenda(
      duraciones: duraciones,
      margenMinutos: entero(json['margenMinutos']),
      limiteDiario: entero(json['limiteDiario']),
    );
  }

  Map<String, dynamic> aJson() => {
    'duraciones': duraciones,
    'margenMinutos': margenMinutos,
    'limiteDiario': limiteDiario,
  };
}

/// Días en que el médico no atiende: vacaciones, congresos, feriados.
class BloqueoAgenda {
  /// «AAAA-MM-DD», inclusive.
  final String desde;

  /// «AAAA-MM-DD», inclusive.
  final String hasta;

  final String motivo;

  const BloqueoAgenda({
    required this.desde,
    required this.hasta,
    this.motivo = '',
  });

  static BloqueoAgenda? desdeJson(Object? json) {
    if (json is! Map) return null;

    final desde = json['desde']?.toString() ?? '';
    final hasta = json['hasta']?.toString() ?? '';
    if (desde.length < 10 || hasta.length < 10) return null;

    return BloqueoAgenda(
      desde: desde.substring(0, 10),
      hasta: hasta.substring(0, 10),
      motivo: json['motivo']?.toString() ?? '',
    );
  }

  Map<String, dynamic> aJson() => {
    'desde': desde,
    'hasta': hasta,
    'motivo': motivo,
  };
}

/// Lo que hace falta de un médico para armar su agenda.
abstract interface class MedicoConAgenda {
  List<HorarioDia> get horariosAtencion;
  ConfigAgenda? get configAgenda;
  List<BloqueoAgenda> get bloqueos;
}

/// Completa y ordena un horario que llega del servidor.
///
/// Un médico dado de alta antes de configurar su jornada llega sin días, o
/// con solo algunos: siempre se devuelven los siete, en orden, y un día sin
/// turnos cuenta como inactivo.
List<HorarioDia> normalizarHorarios(List<HorarioDia>? horarios) {
  return [
    for (final dia in diasSemana)
      () {
        final guardado = horarios?.where((h) => h.dia == dia).firstOrNull;

        return HorarioDia(
          dia: dia,
          activo:
              (guardado?.activo ?? false) &&
              (guardado?.rangos.isNotEmpty ?? false),
          rangos: [
            for (final r in guardado?.rangos ?? const <HorarioRango>[])
              HorarioRango(inicio: r.inicio, fin: r.fin),
          ],
        );
      }(),
  ];
}

/// «09:30» → 570.
int aMinutos(String hora) {
  final partes = hora.split(':');
  final h = int.tryParse(partes.isNotEmpty ? partes[0] : '') ?? 0;
  final m = partes.length > 1 ? int.tryParse(partes[1]) ?? 0 : 0;

  return h * 60 + m;
}

/// 570 → «09:30».
String aHora(int minutos) {
  final h = minutos ~/ 60;
  final m = minutos % 60;

  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

bool validarHorario(HorarioRango rango) =>
    aMinutos(rango.fin) > aMinutos(rango.inicio);

/// Resumen corto de la jornada: «Lu Ma Mi · 08:00–13:00, 14:00–18:00».
String resumenHorario(List<HorarioDia>? horarios) {
  final activos = normalizarHorarios(horarios).where((d) => d.activo).toList();
  if (activos.isEmpty) return 'Sin horario configurado';

  final dias = activos.map((d) => d.dia.substring(0, 2)).join(' ');
  final primero = activos.first.rangos
      .map((r) => '${r.inicio}–${r.fin}')
      .join(', ');

  String clave(HorarioDia d) =>
      d.rangos.map((r) => '${r.inicio}-${r.fin}').join(',');

  final todosIguales = activos.every((d) => clave(d) == clave(activos.first));

  return todosIguales ? '$dias · $primero' : '$dias · horario variable';
}

/// Duración en minutos de una modalidad con este médico: la suya, o la de la
/// clínica si no configuró ninguna.
int duracionDe(
  MedicoConAgenda? medico,
  TipoCita tipo,
  ReglasAgendamiento reglas,
) {
  final propia = medico?.configAgenda?.duraciones[tipo.codigo];

  return propia != null && propia > 0
      ? propia
      : reglas.duracionPorDefecto(tipo);
}

/// Minutos de margen entre citas del médico (nunca negativos).
int margenDe(MedicoConAgenda? medico) {
  final margen = medico?.configAgenda?.margenMinutos ?? 0;

  return margen < 0 ? 0 : margen;
}

/// El bloqueo que cubre esta fecha, si hay alguno.
///
/// Las fechas se comparan como texto «AAAA-MM-DD», que ordena igual que el
/// calendario.
BloqueoAgenda? bloqueoEn(MedicoConAgenda? medico, DateTime fecha) {
  final dia = fechaIso(fecha);

  for (final bloqueo in medico?.bloqueos ?? const <BloqueoAgenda>[]) {
    if (bloqueo.desde.compareTo(dia) <= 0 &&
        dia.compareTo(bloqueo.hasta) <= 0) {
      return bloqueo;
    }
  }

  return null;
}
