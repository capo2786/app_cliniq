import 'package:equatable/equatable.dart';

/// Los permisos del portal del paciente, con los nombres de la API.
class Permisos {
  const Permisos._();

  /// Acceso total: lo tienen los administradores.
  static const String comodin = '*';

  static const String misCitas = 'portal.mis_citas';
  static const String agendar = 'portal.agendar';
  static const String dependientes = 'portal.dependientes';
  static const String consultas = 'portal.consultas';
}

/// El contacto de emergencia del paciente.
class ContactoEmergencia extends Equatable {
  final String nombre;
  final String telefono;
  final String? parentesco;

  const ContactoEmergencia({
    required this.nombre,
    required this.telefono,
    this.parentesco,
  });

  static ContactoEmergencia? desdeJson(Object? json) {
    if (json is! Map) return null;

    final nombre = json['nombre']?.toString().trim() ?? '';
    final telefono = json['telefono']?.toString().trim() ?? '';
    if (nombre.isEmpty && telefono.isEmpty) return null;

    final parentesco = json['parentesco']?.toString().trim();

    return ContactoEmergencia(
      nombre: nombre,
      telefono: telefono,
      parentesco: parentesco == null || parentesco.isEmpty ? null : parentesco,
    );
  }

  Map<String, dynamic> aJson() => {
    'nombre': nombre,
    'telefono': telefono,
    if (parentesco != null) 'parentesco': parentesco,
  };

  @override
  List<Object?> get props => [nombre, telefono, parentesco];
}

/// La persona con la sesión abierta, tal como la devuelve la API.
///
/// Se guarda el mapa entero que mandó el servidor y se leen los campos desde
/// ahí. Así la copia guardada en el teléfono conserva también lo que esta
/// versión de la aplicación todavía no enseña —el embarazo, el representante—
/// y una versión futura lo encuentra intacto.
class Usuario extends Equatable {
  final Map<String, dynamic> datos;

  const Usuario(this.datos);

  factory Usuario.desdeJson(Map<dynamic, dynamic> json) =>
      Usuario(Map<String, dynamic>.from(json));

  Map<String, dynamic> aJson() => Map<String, dynamic>.from(datos);

  String? _texto(String campo) {
    final valor = datos[campo]?.toString().trim();
    return valor == null || valor.isEmpty ? null : valor;
  }

  List<String> _lista(String campo) {
    final valor = datos[campo];
    return valor is List ? valor.map((x) => x.toString()).toList() : const [];
  }

  String get uid => _texto('uid') ?? _texto('_id') ?? '';

  String get nombre => _texto('nombre') ?? '';

  String get email => _texto('email') ?? '';

  /// El tipo de usuario de la API (1 administrador, 2 médico, 3 paciente…).
  int get tipo => int.tryParse(datos['role']?.toString() ?? '') ?? 0;

  List<String> get permisos => _lista('permisos');

  /// Los nombres de sus roles (`PACIENTE`…), como los manda la API.
  List<String> get roles => _lista('roles');

  /// Claves de los documentos legales que todavía no aceptó.
  List<String> get legalPendientes => _lista('legalPendientes');

  bool get tieneLegalesPendientes => legalPendientes.isNotEmpty;

  bool get dosFactores => datos['dosFactores'] == true;

  String? get cedula => _texto('cedula');

  String? get telefono => _texto('telefono');

  String get tipoDocumento => _texto('tipoDocumento') ?? 'CEDULA';

  /// «AAAA-MM-DD», o `null` si no se registró.
  String? get fechaNacimiento {
    final valor = _texto('fechaNacimiento');
    return valor == null || valor.length < 10 ? valor : valor.substring(0, 10);
  }

  String? get sexo => _texto('sexo');

  String? get direccion => _texto('direccion');

  String? get tipoSangre => _texto('tipoSangre');

  String? get alergias => _texto('alergias');

  ContactoEmergencia? get contactoEmergencia =>
      ContactoEmergencia.desdeJson(datos['contactoEmergencia']);

  String? get antecedentesPersonales => _texto('antecedentesPersonales');

  String? get antecedentesFamiliares => _texto('antecedentesFamiliares');

  String? get habitos => _texto('habitos');

  String? get medicacionHabitual => _texto('medicacionHabitual');

  /// Si tiene un permiso. El comodín de los administradores los abre todos.
  bool puede(String permiso) =>
      permisos.contains(Permisos.comodin) || permisos.contains(permiso);

  /// Si la cuenta es de un paciente: tiene «mis citas» por sí misma.
  ///
  /// Se mira el permiso **exacto** y no con [puede]: el comodín de los
  /// administradores no abre el portal del paciente (`*` excluye `portal.*`
  /// en la API), y el personal de la clínica trabaja en el panel web.
  bool get esPaciente => permisos.contains(Permisos.misCitas);

  /// El primer nombre, para el saludo: «Hola, Ana» y no el nombre completo.
  String get primerNombre {
    final partes = nombre.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return partes.isEmpty ? '' : partes.first;
  }

  /// Dos letras para el avatar mientras no haya foto.
  String get iniciales {
    final partes = nombre
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();

    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();

    return (partes.first[0] + partes[1][0]).toUpperCase();
  }

  @override
  List<Object?> get props => [datos];
}
