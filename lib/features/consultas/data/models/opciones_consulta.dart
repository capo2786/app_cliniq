import 'package:equatable/equatable.dart';

import 'campo_formulario.dart';

/// Un motivo de consulta tal como lo ve el paciente (`MotivoPublico`): sin
/// el criterio clínico, que es solo para el personal.
class MotivoPublico extends Equatable {
  final String id;

  /// El nombre exacto del catálogo de especialidades, o `*` si vale para
  /// cualquiera.
  final String especialidad;

  final String nombre;
  final String descripcion;
  final List<CampoFormulario> campos;

  /// Hay que adjuntar al menos un archivo para poder enviarla.
  final bool requiereAdjunto;

  final bool activo;
  final int orden;
  final bool isSystem;

  const MotivoPublico({
    required this.id,
    required this.nombre,
    this.especialidad = '*',
    this.descripcion = '',
    this.campos = const [],
    this.requiereAdjunto = false,
    this.activo = true,
    this.orden = 0,
    this.isSystem = false,
  });

  static MotivoPublico? desdeJson(Object? json) {
    if (json is! Map) return null;

    final id = json['_id']?.toString().trim() ?? '';
    if (id.isEmpty) return null;

    final orden = json['orden'];

    return MotivoPublico(
      id: id,
      especialidad: json['especialidad']?.toString().trim() ?? '*',
      nombre: json['nombre']?.toString().trim() ?? 'Motivo',
      descripcion: json['descripcion']?.toString().trim() ?? '',
      campos: interpretarCampos(json['campos']),
      requiereAdjunto: json['requiereAdjunto'] == true,
      activo: json['activo'] != false,
      orden: orden is num ? orden.toInt() : 0,
      isSystem: json['isSystem'] == true,
    );
  }

  @override
  List<Object?> get props => [
    id,
    especialidad,
    nombre,
    descripcion,
    campos,
    requiereAdjunto,
    activo,
    orden,
    isSystem,
  ];
}

/// Un médico que atiende consultas en línea: solo lo que el paciente necesita
/// para elegirlo.
class MedicoConsulta extends Equatable {
  final String uid;
  final String nombre;
  final String especialidad;

  const MedicoConsulta({
    required this.uid,
    required this.nombre,
    this.especialidad = '',
  });

  /// «Dr(a). Ana Pérez», como en el resto de la aplicación.
  String get nombreVisible => 'Dr(a). $nombre';

  static MedicoConsulta? desdeJson(Object? json) {
    if (json is! Map) return null;

    final uid = json['uid']?.toString().trim() ?? '';
    if (uid.isEmpty) return null;

    return MedicoConsulta(
      uid: uid,
      nombre: json['nombre']?.toString().trim() ?? 'Médico',
      especialidad: json['especialidad']?.toString().trim() ?? '',
    );
  }

  @override
  List<Object?> get props => [uid, nombre, especialidad];
}

/// Una especialidad con sus motivos y sus médicos.
class EspecialidadConsulta extends Equatable {
  final String nombre;
  final List<MotivoPublico> motivos;
  final List<MedicoConsulta> medicos;

  const EspecialidadConsulta({
    required this.nombre,
    this.motivos = const [],
    this.medicos = const [],
  });

  /// Los motivos activos en el orden que fijó la clínica.
  List<MotivoPublico> get motivosOrdenados =>
      motivos.where((m) => m.activo).toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));

  static EspecialidadConsulta? desdeJson(Object? json) {
    if (json is! Map) return null;

    final nombre = json['nombre']?.toString().trim() ?? '';
    if (nombre.isEmpty) return null;

    return EspecialidadConsulta(
      nombre: nombre,
      motivos: [
        for (final m in (json['motivos'] as List?) ?? const [])
          ?MotivoPublico.desdeJson(m),
      ],
      medicos: [
        for (final m in (json['medicos'] as List?) ?? const [])
          ?MedicoConsulta.desdeJson(m),
      ],
    );
  }

  @override
  List<Object?> get props => [nombre, motivos, medicos];
}

/// `GET /portal/consultas/opciones`: lo que se puede pedir y a quién.
///
/// La API ya deja solo las especialidades con al menos un médico que atiende
/// en línea y un motivo activo; aquí se descartan, además, las que llegaran
/// vacías, para no ofrecer un callejón sin salida.
List<EspecialidadConsulta> interpretarOpciones(Object? datos) {
  final lista = datos is Map ? datos['especialidades'] : null;
  if (lista is! List) return const [];

  return [for (final e in lista) ?EspecialidadConsulta.desdeJson(e)]
      .where((e) => e.medicos.isNotEmpty && e.motivosOrdenados.isNotEmpty)
      .toList();
}
