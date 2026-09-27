import 'package:equatable/equatable.dart';

import '../../../../core/fechas/fecha_local.dart';
import '../../../citas/data/models/cita.dart';
import 'medico_portal.dart';

/// Los turnos libres que calcula la API.
///
/// La API es la que sabe qué horarios se pueden reservar: aplica la jornada,
/// los bloqueos, la duración, el margen, el límite diario, la anticipación,
/// el horizonte y la rejilla con las mismas reglas con que valida la
/// reserva. La aplicación solo los lee y los enseña; no vuelve a calcular
/// nada. Las fechas llegan en hora local de la clínica, sin zona
/// (`2026-09-28T08:00:00`), y se leen con `fecha_local.dart`.
///
/// Una entrada ilegible se descarta: un turno con una fecha rota no se puede
/// ofrecer, y es mejor no enseñarlo que enseñar una hora inventada.

/// La modalidad con el código exacto de la API, o `null` si no es ninguna.
///
/// No usa [TipoCita.desdeCodigo], que cae en presencial: un turno con una
/// modalidad desconocida no se puede reservar como presencial.
TipoCita? modalidadDeCodigo(Object? codigo) {
  final texto = codigo?.toString().toUpperCase().trim();

  for (final tipo in TipoCita.values) {
    if (tipo.codigo == texto) return tipo;
  }

  return null;
}

/// Un turno libre: `{ inicio, fin }`.
class Turno extends Equatable {
  final DateTime inicio;
  final DateTime fin;

  const Turno({required this.inicio, required this.fin});

  /// El turno, o `null` si falta una fecha o el fin no va después del inicio.
  static Turno? desdeJson(Object? json) {
    if (json is! Map) return null;

    final inicio = leerFechaLocal(json['inicio']);
    final fin = leerFechaLocal(json['fin']);
    if (inicio == null || fin == null || !fin.isAfter(inicio)) return null;

    return Turno(inicio: inicio, fin: fin);
  }

  @override
  List<Object?> get props => [inicio, fin];

  @override
  String toString() => 'Turno(${aTextoLocal(inicio)}–${aTextoLocal(fin)})';
}

/// `GET /portal/turnos/:doctorId`: los turnos libres de un médico en una
/// modalidad.
class TurnosMedico extends Equatable {
  final String doctorId;
  final TipoCita modalidad;

  /// Minutos de cada turno con este médico en esta modalidad.
  final int duracion;

  /// En orden y sin repetidos.
  final List<Turno> turnos;

  const TurnosMedico({
    required this.doctorId,
    required this.modalidad,
    required this.duracion,
    this.turnos = const [],
  });

  /// Lee la respuesta a lo pedido: el médico y la modalidad son los de la
  /// consulta, que es con lo que el bloc la reconoce.
  factory TurnosMedico.desdeJson(
    Map<dynamic, dynamic> json, {
    required String doctorId,
    required TipoCita modalidad,
  }) {
    final vistos = <DateTime>{};
    final turnos = <Turno>[
      for (final t in (json['turnos'] as List?) ?? const [])
        ?Turno.desdeJson(t),
    ]..sort((a, b) => a.inicio.compareTo(b.inicio));
    turnos.retainWhere((t) => vistos.add(t.inicio));

    final duracion = json['duracion'];

    return TurnosMedico(
      doctorId: doctorId,
      modalidad: modalidad,
      duracion: duracion is num && duracion > 0
          ? duracion.toInt()
          : (turnos.isEmpty
                ? 0
                : turnos.first.fin.difference(turnos.first.inicio).inMinutes),
      turnos: turnos,
    );
  }

  @override
  List<Object?> get props => [doctorId, modalidad, duracion, turnos];
}

/// El próximo turno libre de un médico (`medicos[].proximo`) o de una
/// especialidad (`especialidades[].proximo`, que además dice con qué
/// médico es).
class ProximoTurno extends Equatable {
  final DateTime inicio;
  final DateTime fin;

  /// En qué modalidad: sin filtro de modalidad, la más cercana de las que
  /// ofrece el médico.
  final TipoCita modalidad;

  /// Con qué médico. Solo viene en el de una especialidad; en el de un
  /// médico es el propio médico.
  final String? doctorId;

  const ProximoTurno({
    required this.inicio,
    required this.fin,
    required this.modalidad,
    this.doctorId,
  });

  static ProximoTurno? desdeJson(Object? json) {
    if (json is! Map) return null;

    final turno = Turno.desdeJson(json);
    final modalidad = modalidadDeCodigo(json['modalidad']);
    if (turno == null || modalidad == null) return null;

    final doctor = json['doctorId']?.toString().trim() ?? '';

    return ProximoTurno(
      inicio: turno.inicio,
      fin: turno.fin,
      modalidad: modalidad,
      doctorId: doctor.isEmpty ? null : doctor,
    );
  }

  /// El mismo, con el médico dicho.
  ProximoTurno conMedico(String doctorId) => ProximoTurno(
    inicio: inicio,
    fin: fin,
    modalidad: modalidad,
    doctorId: doctorId,
  );

  Turno get turno => Turno(inicio: inicio, fin: fin);

  @override
  List<Object?> get props => [inicio, fin, modalidad, doctorId];
}

/// Una especialidad con médicos que tienen turnos libres.
class EspecialidadDisponible extends Equatable {
  final String nombre;

  /// Cuántos de sus médicos tienen turnos libres.
  final int medicos;

  /// El primer turno disponible con cualquiera de ellos.
  final ProximoTurno? proximo;

  const EspecialidadDisponible({
    required this.nombre,
    required this.medicos,
    this.proximo,
  });

  static EspecialidadDisponible? desdeJson(Object? json) {
    if (json is! Map) return null;

    final nombre = json['nombre']?.toString().trim() ?? '';
    if (nombre.isEmpty) return null;

    final medicos = json['medicos'];

    return EspecialidadDisponible(
      nombre: nombre,
      medicos: medicos is num && medicos > 0 ? medicos.toInt() : 0,
      proximo: ProximoTurno.desdeJson(json['proximo']),
    );
  }

  @override
  List<Object?> get props => [nombre, medicos, proximo];
}

/// `GET /portal/proximos-turnos`: solo los médicos con algún turno libre
/// dentro del horizonte, y las especialidades que tienen alguno de ellos.
class ProximosTurnos extends Equatable {
  /// En el orden del catálogo `ESPECIALIDAD`, como las manda la API.
  final List<EspecialidadDisponible> especialidades;

  /// Del turno más cercano al más lejano.
  final List<MedicoPortal> medicos;

  const ProximosTurnos({
    this.especialidades = const [],
    this.medicos = const [],
  });

  /// Lee la respuesta tal como llega: el orden es el de la API.
  factory ProximosTurnos.desdeJson(Map<dynamic, dynamic> json) {
    return ProximosTurnos(
      especialidades: [
        for (final e in (json['especialidades'] as List?) ?? const [])
          ?EspecialidadDisponible.desdeJson(e),
      ],
      medicos: [
        for (final m in (json['medicos'] as List?) ?? const [])
          if (m is Map) MedicoPortal.desdeJson(m),
      ]..retainWhere((m) => m.uid.isNotEmpty),
    );
  }

  @override
  List<Object?> get props => [especialidades, medicos];
}
