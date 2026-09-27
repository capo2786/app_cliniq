// lib/features/auth/dominio/registro.dart

/// Las reglas del autorregistro de pacientes, sin pantalla.
///
/// Son las del panel web (`features/auth/registro`, `core/validadores.ts` y
/// `ui/fortaleza`), con sus mismos mensajes, y las del API
/// (`auth-ms/src/auth/registro/registro.service.ts`, `validarRegistro`): la
/// aplicación no deja pasar lo que el servidor rechazaría ni al revés. Los
/// números que la clínica administra (la contraseña mínima, validar la
/// cédula) llegan por parámetro.
library;

import '../../dependientes/dominio/validaciones.dart';
import '../../legal/data/legal_service.dart';

/// Largo máximo del nombre y del correo en el formulario del panel.
const int nombreMaximo = 120;
const int correoMaximo = 120;

/// El API no acepta contraseñas de más de 128 caracteres.
const int contrasenaMaxima = 128;

/// Nombres y apellidos: obligatorio, de 3 a 120 caracteres.
String? errorDeNombreRegistro(String? valor) {
  final texto = normalizarNombre(valor ?? '');

  if (texto.isEmpty) return 'Escribe tus nombres y apellidos.';
  if (texto.length < 3) return 'Debe tener al menos 3 caracteres.';
  if (texto.length > nombreMaximo) return 'Máximo $nombreMaximo caracteres.';

  return null;
}

/*
 * El correo como lo acepta `Validators.email` de Angular, con un dominio de
 * al menos dos partes: el API (`isEmail`) exige el punto que Angular deja
 * pasar («ana@clinica» no llega a ninguna parte).
 */
final RegExp _correo = RegExp(
  r"^[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-zA-Z0-9!#$%&'*+/=?^_`{|}~-]+)*"
  r'@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
  r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*'
  r'\.[a-zA-Z]{2,}$',
);

/// Correo electrónico: obligatorio, con forma de correo y hasta 120
/// caracteres.
String? errorDeCorreoRegistro(String? valor) {
  final texto = valor?.trim() ?? '';

  if (texto.isEmpty) return 'Escribe tu correo.';
  if (!_correo.hasMatch(texto)) return 'Ese correo no parece válido.';
  if (texto.length > correoMaximo) return 'Máximo $correoMaximo caracteres.';

  return null;
}

/// El número del documento: obligatorio. La cédula se revisa con el módulo
/// 10 si la clínica lo pide ([validarCedula], `general.validarCedula`); el
/// pasaporte, de 5 a 20 letras o números.
String? errorDeDocumentoRegistro(
  String? valor,
  String tipoDocumento, {
  required bool validarCedula,
}) {
  if ((valor?.trim() ?? '').isEmpty) {
    return 'Escribe el número de tu documento.';
  }

  return errorDeDocumento(valor, tipoDocumento, validarCedula: validarCedula);
}

/// La fecha de nacimiento («AAAA-MM-DD»): obligatoria y no futura.
String? errorDeFechaRegistro(String? valor, DateTime hoy) {
  if ((valor?.trim() ?? '').isEmpty) return 'Indica tu fecha de nacimiento.';

  return errorDeFechaNacimiento(valor, hoy);
}

/// La contraseña: obligatoria, con el mínimo de la clínica
/// (`seguridad.passwordMinimo`) y el máximo del API.
String? errorDeContrasenaRegistro(String? valor, {required int minimo}) {
  final texto = valor ?? '';

  if (texto.isEmpty) return 'Crea una contraseña.';
  if (texto.length < minimo) return 'Debe tener al menos $minimo caracteres.';
  if (texto.length > contrasenaMaxima) {
    return 'La contraseña no puede superar $contrasenaMaxima caracteres.';
  }

  return null;
}

/// La contraseña repetida: obligatoria e igual a la primera.
String? errorDeConfirmacion(String? valor, String contrasena) {
  final texto = valor ?? '';

  if (texto.isEmpty) return 'Repite la contraseña.';
  if (texto != contrasena) return 'Las contraseñas no coinciden.';

  return null;
}

/// Lo que se dice si falta aceptar los documentos legales.
const String mensajeFaltaAceptar =
    'Debes aceptar los términos y la política de privacidad para crear tu '
    'cuenta.';

/// Lo que se dice cuando el formulario tiene errores.
const String mensajeRevisaLosCampos = 'Revisa los campos marcados en rojo.';

/// Qué tan difícil de adivinar es una contraseña, de 0 a 4 (`puntajePassword`
/// del panel): llegar al mínimo de la clínica suma un punto y superarlo por
/// cuatro, otro; mezclar mayúsculas y minúsculas, poner números o símbolos,
/// uno cada cosa.
int puntajeDeContrasena(String valor, int minimo) {
  if (valor.isEmpty) return 0;

  var puntos = 0;
  if (valor.length >= minimo) puntos++;
  if (valor.length >= minimo + 4) puntos++;
  if (RegExp('[a-z]').hasMatch(valor) && RegExp('[A-Z]').hasMatch(valor)) {
    puntos++;
  }
  if (RegExp(r'\d').hasMatch(valor)) puntos++;
  if (RegExp('[^A-Za-z0-9]').hasMatch(valor)) puntos++;

  return puntos > 4 ? 4 : puntos;
}

/// La pista que acompaña a cada puntaje, la misma del panel.
String pistaDeContrasena(int puntaje, int minimo) => switch (puntaje) {
  0 => 'Muy débil',
  1 => 'Débil: usa al menos $minimo caracteres',
  2 => 'Aceptable: combina mayúsculas, números o símbolos',
  3 => 'Buena',
  _ => 'Muy buena',
};

/// Los espacios de los extremos fuera y los de en medio, de a uno: como el
/// panel antes de enviar el nombre.
String normalizarNombre(String nombre) =>
    nombre.trim().replaceAll(RegExp(r'\s+'), ' ');

/// El tipo de usuario de un paciente en el API (`UserRole.PACIENTE`).
const int tipoPaciente = 3;

/// Los documentos cuya aceptación registra el API al crear la cuenta
/// (`aceptaTerminos: true` en `POST /auth/registro`): las claves son del
/// sistema, como en el panel (`<app-enlace-legal clave="TERMINOS">`). Los
/// demás documentos de los pacientes se aceptan al entrar por primera vez,
/// en la pantalla de aceptación.
const List<String> clavesAceptadasAlRegistrarse = ['TERMINOS', 'PRIVACIDAD'];

/// Los documentos vigentes de los pacientes, repartidos: los que se aceptan
/// en el registro (en el orden de [clavesAceptadasAlRegistrarse]) y los que
/// se aceptarán al entrar (en el orden del servidor).
({List<DocumentoLegal> alRegistrarse, List<DocumentoLegal> alEntrar})
repartirDocumentosDelPaciente(List<DocumentoLegal> documentos) {
  final delPaciente = [
    for (final d in documentos)
      if (d.aplicaA(tipoDeUsuario: tipoPaciente, roles: const ['PACIENTE'])) d,
  ];

  return (
    alRegistrarse: [
      for (final clave in clavesAceptadasAlRegistrarse)
        ...delPaciente.where((d) => d.clave == clave).take(1),
    ],
    alEntrar: [
      for (final d in delPaciente)
        if (!clavesAceptadasAlRegistrarse.contains(d.clave)) d,
    ],
  );
}
