// lib/features/dependientes/dominio/validaciones.dart

/// Validaciones de los formularios de personas.
///
/// Puerto de `esCedulaValida` (`core/models/usuario.model.ts`) y de los
/// validadores de `core/validadores.ts` del panel web: la misma regla en las
/// dos puntas, para que la aplicación no deje pasar algo que el panel
/// rechazaría ni al revés.
library;

import '../../../core/fechas/fecha_local.dart';

/// Cédula ecuatoriana con dígito verificador (módulo 10).
///
/// Diez dígitos, provincia 01–24 (o 30 para ecuatorianos en el exterior),
/// tercer dígito menor que 6 para personas naturales y el último dígito
/// verificador según el módulo 10. Atrapa los errores de tipeo más comunes
/// —dos dígitos cambiados de lugar, uno de más o de menos— antes de que
/// alguien quede registrado con una cédula que no es la suya.
bool esCedulaValida(String cedula) {
  if (!RegExp(r'^\d{10}$').hasMatch(cedula)) return false;

  final provincia = int.parse(cedula.substring(0, 2));
  if (!((provincia >= 1 && provincia <= 24) || provincia == 30)) return false;
  if (int.parse(cedula[2]) >= 6) return false;

  var suma = 0;
  for (var i = 0; i < 9; i++) {
    final digito = int.parse(cedula[i]);
    final valor = i.isEven ? digito * 2 : digito;
    suma += valor > 9 ? valor - 9 : valor;
  }

  final verificador = (10 - (suma % 10)) % 10;

  return verificador == int.parse(cedula[9]);
}

/// Pasaporte: de 5 a 20 letras o números.
bool esPasaporteValido(String valor) =>
    RegExp(r'^[A-Za-z0-9]{5,20}$').hasMatch(valor);

/// El error de un número de documento, o `null` si vale (o está vacío: el
/// documento es opcional).
String? errorDeDocumento(String? valor, String tipoDocumento) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return null;

  if (tipoDocumento == 'PASAPORTE') {
    return esPasaporteValido(texto)
        ? null
        : 'El pasaporte debe tener entre 5 y 20 letras o números.';
  }

  return esCedulaValida(texto)
      ? null
      : 'La cédula no es válida. Revisa los diez dígitos.';
}

/// Si una fecha «AAAA-MM-DD» cae después de hoy.
bool esFechaFutura(String valor, DateTime hoy) =>
    valor.compareTo(fechaIso(hoy)) > 0;

/// El error de una fecha de nacimiento obligatoria, o `null` si vale.
String? errorDeFechaNacimiento(String? valor, DateTime hoy) {
  final texto = valor?.trim() ?? '';

  if (texto.isEmpty) return 'La fecha de nacimiento es obligatoria.';
  if (deFechaIso(texto) == null) return 'Esa fecha no es válida.';
  if (texto.compareTo('1900-01-01') < 0) return 'Revisa el año de nacimiento.';
  if (esFechaFutura(texto, hoy)) return 'La fecha no puede estar en el futuro.';

  return null;
}

/// El error de un nombre de persona (3 a 120 caracteres), o `null`.
String? errorDeNombre(String? valor) {
  final texto = valor?.trim() ?? '';

  if (texto.isEmpty) return 'El nombre es obligatorio.';
  if (texto.length < 3) return 'Debe tener al menos 3 caracteres.';
  if (texto.length > 120) return 'Máximo 120 caracteres.';

  return null;
}

/// Teléfono: de 7 a 15 caracteres entre dígitos, espacios, guiones y un
/// «+» inicial. Opcional.
String? errorDeTelefono(String? valor) {
  final texto = valor?.trim() ?? '';
  if (texto.isEmpty) return null;

  return RegExp(r'^\+?[0-9\s-]{7,15}$').hasMatch(texto)
      ? null
      : 'Escribe un teléfono de 7 a 15 dígitos.';
}

/// Un texto con tope de caracteres.
String? errorDeLargo(String? valor, int maximo) {
  final texto = valor?.trim() ?? '';

  return texto.length > maximo ? 'Máximo $maximo caracteres.' : null;
}

/// Edad en años cumplidos a partir de «AAAA-MM-DD», o `null`.
int? edad(String? fechaNacimiento, DateTime hoy) {
  final fecha = deFechaIso(fechaNacimiento);
  if (fecha == null) return null;

  var anios = hoy.year - fecha.year;
  if (hoy.month < fecha.month ||
      (hoy.month == fecha.month && hoy.day < fecha.day)) {
    anios -= 1;
  }

  return anios >= 0 ? anios : null;
}

/// Los valores que acepta la API para sexo y tipo de sangre.
const Map<String, String> nombresDeSexo = {
  'F': 'Femenino',
  'M': 'Masculino',
  'O': 'Otro',
};

const List<String> tiposDeSangre = [
  'A+',
  'A-',
  'B+',
  'B-',
  'AB+',
  'AB-',
  'O+',
  'O-',
];

const Map<String, String> nombresDeDocumento = {
  'CEDULA': 'Cédula',
  'PASAPORTE': 'Pasaporte',
};
