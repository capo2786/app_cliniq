import 'package:equatable/equatable.dart';

/// Un dependiente: paciente sin cuenta propia que gestiona el titular.
///
/// Hijos menores, padres mayores, personas a su cargo. El titular les agenda
/// citas y recibe las confirmaciones en su propio correo.
class Dependiente extends Equatable {
  final String uid;
  final String nombre;
  final String tipoDocumento;
  final String? cedula;

  /// «AAAA-MM-DD»
  final String? fechaNacimiento;

  final String? sexo;
  final String? parentesco;
  final String? tipoSangre;
  final String? alergias;
  final String? antecedentesPersonales;
  final String? medicacionHabitual;

  const Dependiente({
    required this.uid,
    required this.nombre,
    this.tipoDocumento = 'CEDULA',
    this.cedula,
    this.fechaNacimiento,
    this.sexo,
    this.parentesco,
    this.tipoSangre,
    this.alergias,
    this.antecedentesPersonales,
    this.medicacionHabitual,
  });

  static String? _texto(Object? valor) {
    final t = valor?.toString().trim();
    return t == null || t.isEmpty ? null : t;
  }

  factory Dependiente.desdeJson(Map<dynamic, dynamic> json) {
    final nacimiento = _texto(json['fechaNacimiento']);

    return Dependiente(
      uid: _texto(json['uid']) ?? _texto(json['_id']) ?? '',
      nombre: _texto(json['nombre']) ?? '',
      tipoDocumento: _texto(json['tipoDocumento']) ?? 'CEDULA',
      cedula: _texto(json['cedula']),
      fechaNacimiento: nacimiento == null || nacimiento.length < 10
          ? nacimiento
          : nacimiento.substring(0, 10),
      sexo: _texto(json['sexo']),
      parentesco: _texto(json['parentesco']),
      tipoSangre: _texto(json['tipoSangre']),
      alergias: _texto(json['alergias']),
      antecedentesPersonales: _texto(json['antecedentesPersonales']),
      medicacionHabitual: _texto(json['medicacionHabitual']),
    );
  }

  Map<String, dynamic> aJson() => {
    'uid': uid,
    'nombre': nombre,
    'tipoDocumento': tipoDocumento,
    'cedula': cedula,
    'fechaNacimiento': fechaNacimiento,
    'sexo': sexo,
    'parentesco': parentesco,
    'tipoSangre': tipoSangre,
    'alergias': alergias,
    'antecedentesPersonales': antecedentesPersonales,
    'medicacionHabitual': medicacionHabitual,
  };

  @override
  List<Object?> get props => [
    uid,
    nombre,
    tipoDocumento,
    cedula,
    fechaNacimiento,
    sexo,
    parentesco,
    tipoSangre,
    alergias,
    antecedentesPersonales,
    medicacionHabitual,
  ];
}

/// Lo que se manda para crear o editar un dependiente: los campos que
/// acepta `POST/PATCH /portal/dependientes`.
class DatosDependiente {
  final String nombre;
  final String parentesco;
  final String fechaNacimiento;
  final String tipoDocumento;
  final String cedula;
  final String? sexo;
  final String? tipoSangre;
  final String alergias;
  final String antecedentesPersonales;
  final String medicacionHabitual;

  const DatosDependiente({
    required this.nombre,
    required this.parentesco,
    required this.fechaNacimiento,
    this.tipoDocumento = 'CEDULA',
    this.cedula = '',
    this.sexo,
    this.tipoSangre,
    this.alergias = '',
    this.antecedentesPersonales = '',
    this.medicacionHabitual = '',
  });

  /// Igual que el panel web: la cédula, el sexo y el tipo de sangre solo van
  /// si se llenaron; los textos clínicos van siempre, porque vacíos
  /// significan «borrar lo que había» al editar.
  Map<String, dynamic> aJson() => {
    'nombre': nombre.trim(),
    'parentesco': parentesco.trim(),
    'fechaNacimiento': fechaNacimiento,
    'tipoDocumento': tipoDocumento,
    if (cedula.trim().isNotEmpty) 'cedula': cedula.trim(),
    if (sexo != null && sexo!.isNotEmpty) 'sexo': sexo,
    if (tipoSangre != null && tipoSangre!.isNotEmpty) 'tipoSangre': tipoSangre,
    'alergias': alergias.trim(),
    'antecedentesPersonales': antecedentesPersonales.trim(),
    'medicacionHabitual': medicacionHabitual.trim(),
  };
}
