import '../../../citas/data/models/cita.dart';
import '../../dominio/horarios.dart';

/// Lo que el portal sabe de un médico: nada de correo, teléfono ni cédula.
class MedicoPortal implements MedicoConAgenda {
  final String uid;
  final String nombre;
  final String? especialidad;
  final String? ciudad;

  /// Las modalidades que ofrece. La API ya devuelve las tres cuando el
  /// médico no configuró ninguna.
  final List<TipoCita> modalidades;

  @override
  final List<HorarioDia> horariosAtencion;

  @override
  final ConfigAgenda? configAgenda;

  @override
  final List<BloqueoAgenda> bloqueos;

  const MedicoPortal({
    required this.uid,
    required this.nombre,
    this.especialidad,
    this.ciudad,
    this.modalidades = TipoCita.values,
    this.horariosAtencion = const [],
    this.configAgenda,
    this.bloqueos = const [],
  });

  /// «Dr(a). Ana Pérez»
  String get nombreVisible => 'Dr(a). $nombre';

  /// Las modalidades en el orden de siempre; sin dato, las tres (igual que
  /// `modalidadesDe` en el web).
  List<TipoCita> get modalidadesOfrecidas => modalidades.isEmpty
      ? TipoCita.values
      : TipoCita.values.where(modalidades.contains).toList();

  factory MedicoPortal.desdeJson(Map<dynamic, dynamic> json) {
    String? texto(Object? valor) {
      final t = valor?.toString().trim();
      return t == null || t.isEmpty ? null : t;
    }

    final modalidades = <TipoCita>[
      for (final m in (json['modalidades'] as List?) ?? const [])
        for (final tipo in TipoCita.values)
          if (tipo.codigo == m.toString().toUpperCase()) tipo,
    ];

    return MedicoPortal(
      uid: texto(json['uid']) ?? texto(json['_id']) ?? '',
      nombre: texto(json['nombre']) ?? 'Médico',
      especialidad: texto(json['especialidad']),
      ciudad: texto(json['ciudad']),
      modalidades: modalidades,
      horariosAtencion: [
        for (final dia in (json['horariosAtencion'] as List?) ?? const [])
          if (dia is Map) HorarioDia.desdeJson(dia),
      ],
      configAgenda: ConfigAgenda.desdeJson(json['configAgenda']),
      bloqueos: [
        for (final b in (json['bloqueos'] as List?) ?? const [])
          ?BloqueoAgenda.desdeJson(b),
      ],
    );
  }
}
