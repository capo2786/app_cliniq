// lib/features/auth/data/models/datos_registro.dart

import 'package:equatable/equatable.dart';

import '../../dominio/registro.dart';

/// Lo que se manda para crear una cuenta de paciente (`POST /auth/registro`).
///
/// Los campos son los que el gateway deja pasar (`CAMPOS_REGISTRO`) y se
/// arreglan como los arregla el panel antes de enviarlos: el nombre sin
/// espacios de más, el correo en minúsculas, el documento en mayúsculas y
/// lo opcional (teléfono, sexo) solo si se escribió.
class DatosRegistro extends Equatable {
  final String nombre;
  final String email;
  final String telefono;
  final String tipoDocumento;
  final String cedula;

  /// «AAAA-MM-DD».
  final String fechaNacimiento;

  /// Un código del catálogo `SEXO`, o vacío si prefiere no decirlo.
  final String sexo;

  final String password;

  const DatosRegistro({
    required this.nombre,
    required this.email,
    required this.tipoDocumento,
    required this.cedula,
    required this.fechaNacimiento,
    required this.password,
    this.telefono = '',
    this.sexo = '',
  });

  /// El correo como se envía y como se muestra después («te enviamos un
  /// enlace a …»).
  String get correo => email.trim().toLowerCase();

  /// El cuerpo de la petición. `aceptaTerminos` va siempre en `true`: la
  /// pantalla no deja enviar sin aceptar los documentos, como el panel.
  Map<String, dynamic> aJson() {
    final telefono = this.telefono.trim();

    return {
      'nombre': normalizarNombre(nombre),
      'email': correo,
      if (telefono.isNotEmpty) 'telefono': telefono,
      'tipoDocumento': tipoDocumento,
      'cedula': cedula.trim().toUpperCase(),
      'fechaNacimiento': fechaNacimiento,
      if (sexo.isNotEmpty) 'sexo': sexo,
      'password': password,
      'aceptaTerminos': true,
    };
  }

  @override
  List<Object?> get props => [
    nombre,
    email,
    telefono,
    tipoDocumento,
    cedula,
    fechaNacimiento,
    sexo,
    password,
  ];
}
