// lib/features/mediciones/dominio/destinos_medico.dart

import 'package:equatable/equatable.dart';

import '../../../core/formato/fechas.dart';
import '../../citas/data/models/cita.dart';
import '../../consultas/data/models/consulta.dart';

/// A dónde se puede adjuntar una medición para el médico: la próxima cita
/// de telemedicina o una consulta en línea abierta.
class DestinoMedico extends Equatable {
  final String? citaId;
  final String? consultaId;

  /// «Cita de telemedicina del lunes 5 de octubre, 10:30».
  final String titulo;

  /// El médico, si se sabe.
  final String? detalle;

  const DestinoMedico.cita(String id, {required this.titulo, this.detalle})
    : citaId = id,
      consultaId = null;

  const DestinoMedico.consulta(String id, {required this.titulo, this.detalle})
    : consultaId = id,
      citaId = null;

  /// La de una cita, ya armada (para abrir «Mis signos vitales» desde ella).
  factory DestinoMedico.deCita(Cita cita) => DestinoMedico.cita(
    cita.id,
    titulo:
        'Cita de telemedicina del ${FormatoFecha.diaLargo(cita.inicio).toLowerCase()}, '
        '${FormatoFecha.hora(cita.inicio)}',
    detalle: cita.medicoVisible,
  );

  /// La de una consulta en línea.
  factory DestinoMedico.deConsulta(ConsultaResumen consulta) =>
      DestinoMedico.consulta(
        consulta.id,
        titulo: consulta.codigo.isEmpty
            ? 'Consulta en línea'
            : 'Consulta en línea ${consulta.codigo}',
        detalle: [
          ?consulta.medicoVisible,
          if (consulta.motivoNombre.isNotEmpty) consulta.motivoNombre,
        ].join(' · '),
      );

  @override
  List<Object?> get props => [citaId, consultaId, titulo, detalle];
}

/// Es de esa persona: el titular ([pacienteId] `null`) o un dependiente.
bool _esDe(
  String pacienteDelRegistro,
  bool paraDependiente,
  String? pacienteId,
  String uid,
) {
  if (pacienteId == null || pacienteId.isEmpty || pacienteId == uid) {
    return pacienteDelRegistro.isEmpty
        ? !paraDependiente
        : pacienteDelRegistro == uid;
  }
  return pacienteDelRegistro == pacienteId;
}

/// Las opciones de «Enviar a mi médico» para un paciente: la **próxima**
/// cita de telemedicina pendiente (que todavía no terminó) y las consultas
/// en línea abiertas (enviadas, en revisión o respondidas).
///
/// [ahora] es la hora de la clínica (las citas son hora congelada).
List<DestinoMedico> destinosParaElMedico({
  required List<Cita> citas,
  required List<ConsultaResumen> consultas,
  required String uid,
  required DateTime ahora,
  String? pacienteId,
}) {
  final telemedicina = [
    for (final c in citas)
      if (c.pendiente &&
          c.tipo == TipoCita.telemedicina &&
          c.fin.isAfter(ahora) &&
          _esDe(c.pacienteId ?? '', c.paraDependiente, pacienteId, uid))
        c,
  ]..sort((a, b) => a.inicio.compareTo(b.inicio));

  final abiertas = [
    for (final c in consultas)
      if (c.estado.enCurso &&
          _esDe(c.pacienteId, c.paraDependiente, pacienteId, uid))
        c,
  ];

  return [
    if (telemedicina.isNotEmpty) DestinoMedico.deCita(telemedicina.first),
    for (final c in abiertas) DestinoMedico.deConsulta(c),
  ];
}
