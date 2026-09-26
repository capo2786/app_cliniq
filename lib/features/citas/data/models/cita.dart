import 'package:equatable/equatable.dart';

import '../../../../core/fechas/fecha_local.dart';

/// Las tres maneras de atender una cita.
enum TipoCita {
  presencial('PRESENCIAL', 'Presencial', 'En consultorio', 30),
  telemedicina('TELEMEDICINA', 'Telemedicina', 'Videollamada en vivo', 20),
  asincrona('ASINCRONA', 'Asíncrona', 'Revisión de exámenes o mensajes', 15);

  /// Como lo escribe la API.
  final String codigo;

  final String nombre;
  final String descripcion;

  /// Minutos que ocupa en la agenda si el médico no configuró los suyos
  /// (los mismos valores de la clínica que usa el panel web).
  final int duracionPorDefecto;

  const TipoCita(
    this.codigo,
    this.nombre,
    this.descripcion,
    this.duracionPorDefecto,
  );

  static TipoCita desdeCodigo(Object? codigo) {
    final texto = codigo?.toString().toUpperCase().trim();

    return TipoCita.values.firstWhere(
      (tipo) => tipo.codigo == texto,
      orElse: () => TipoCita.presencial,
    );
  }
}

/// En qué quedó una cita.
enum EstadoCita {
  programada('PROGRAMADA', 'Programada'),
  reagendada('REAGENDADA', 'Reagendada'),
  atendida('ATENDIDA', 'Atendida'),
  noAsistio('NO_ASISTIO', 'No asistió'),
  cancelada('CANCELADA', 'Cancelada');

  final String codigo;
  final String nombre;

  const EstadoCita(this.codigo, this.nombre);

  /// Programada o reagendada: todavía va a ocurrir y se puede mover.
  bool get pendiente =>
      this == EstadoCita.programada || this == EstadoCita.reagendada;

  static EstadoCita desdeCodigo(Object? codigo) {
    final texto = codigo?.toString().toUpperCase().trim();

    return EstadoCita.values.firstWhere(
      (estado) => estado.codigo == texto,
      orElse: () => EstadoCita.programada,
    );
  }
}

/// Una cita, lista para pintar: fechas en hora local de la clínica.
class Cita extends Equatable {
  final String id;
  final DateTime inicio;
  final DateTime fin;
  final TipoCita tipo;
  final EstadoCita estado;
  final String doctorId;

  /// Nombre del médico. Solo llega en «mis citas»: el paciente no puede
  /// listar médicos por su cuenta.
  final String? medico;
  final String? especialidad;

  /// El motivo de consulta que escribió quien agendó.
  final String? motivo;

  final String? motivoCancelacion;

  /// Para quién es la cita (el titular o uno de sus dependientes).
  final String? pacienteNombre;
  final String? pacienteId;

  /// Es de un dependiente del titular, no del titular mismo.
  final bool paraDependiente;

  const Cita({
    required this.id,
    required this.inicio,
    required this.fin,
    required this.tipo,
    required this.estado,
    required this.doctorId,
    this.medico,
    this.especialidad,
    this.motivo,
    this.motivoCancelacion,
    this.pacienteNombre,
    this.pacienteId,
    this.paraDependiente = false,
  });

  bool get pendiente => estado.pendiente;

  Duration get duracion => fin.difference(inicio);

  /// «Dr(a). Ana Pérez», como en el panel web.
  String get medicoVisible {
    final nombre = medico?.trim() ?? '';
    return nombre.isEmpty ? 'Médico por confirmar' : 'Dr(a). $nombre';
  }

  static String? _texto(Object? valor) {
    final texto = valor?.toString().trim();
    return texto == null || texto.isEmpty ? null : texto;
  }

  /// Lee una cita de la API. Las fechas pasan por `aFechaLocal`: la `Z` que
  /// traen se descarta, nunca se convierte.
  factory Cita.desdeJson(Map<dynamic, dynamic> json) {
    final pacienteNombre =
        _texto(json['pacienteNombre']) ?? _texto(json['title']);

    return Cita(
      id: _texto(json['_id']) ?? _texto(json['id']) ?? '',
      inicio: aFechaLocal(json['start']),
      fin: aFechaLocal(json['end']),
      tipo: TipoCita.desdeCodigo(json['type']),
      estado: EstadoCita.desdeCodigo(json['status']),
      doctorId: _texto(json['doctorId']) ?? '',
      medico: _texto(json['doctorName']),
      especialidad: _texto(json['doctorSpecialty']),
      motivo: _texto(json['reason']),
      motivoCancelacion: _texto(json['cancelReason']),
      pacienteNombre: pacienteNombre,
      pacienteId: _texto(json['pacienteId']) ?? _texto(json['patientId']),
      paraDependiente: json['paraDependiente'] == true,
    );
  }

  /// Para la copia guardada en el teléfono: con los mismos nombres de la API
  /// y las fechas ya en hora local sin zona, así se vuelve a leer igual.
  Map<String, dynamic> aJson() => {
    '_id': id,
    'start': aTextoLocal(inicio),
    'end': aTextoLocal(fin),
    'type': tipo.codigo,
    'status': estado.codigo,
    'doctorId': doctorId,
    'doctorName': medico,
    'doctorSpecialty': especialidad,
    'reason': motivo,
    'cancelReason': motivoCancelacion,
    'pacienteNombre': pacienteNombre,
    'pacienteId': pacienteId,
    'paraDependiente': paraDependiente,
  };

  Cita copiarCon({
    DateTime? inicio,
    DateTime? fin,
    EstadoCita? estado,
    String? medico,
    String? especialidad,
    String? pacienteNombre,
    bool? paraDependiente,
  }) {
    return Cita(
      id: id,
      inicio: inicio ?? this.inicio,
      fin: fin ?? this.fin,
      tipo: tipo,
      estado: estado ?? this.estado,
      doctorId: doctorId,
      medico: medico ?? this.medico,
      especialidad: especialidad ?? this.especialidad,
      motivo: motivo,
      motivoCancelacion: motivoCancelacion,
      pacienteNombre: pacienteNombre ?? this.pacienteNombre,
      pacienteId: pacienteId,
      paraDependiente: paraDependiente ?? this.paraDependiente,
    );
  }

  @override
  List<Object?> get props => [
    id,
    inicio,
    fin,
    tipo,
    estado,
    doctorId,
    medico,
    especialidad,
    motivo,
    motivoCancelacion,
    pacienteNombre,
    pacienteId,
    paraDependiente,
  ];
}
