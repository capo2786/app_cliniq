// lib/features/clinicas/dominio/clinica.dart

import 'dart:convert';

import 'package:equatable/equatable.dart';

/// Una clínica de Cliniq: la empresa a la que pertenece una cuenta.
///
/// Hay una sola aplicación en las tiendas para todas las clínicas, y cada una
/// tiene su base de datos. La aplicación guarda la última clínica con que se
/// entró (o la del código o el enlace del registro) y la manda en la cabecera
/// `X-Empresa` de las peticiones sin sesión: el acceso, el registro, la
/// configuración pública, los catálogos y los legales. Con la sesión abierta
/// manda el token, que ya dice de qué clínica es.
///
/// Llega de tres lugares, siempre con el mismo dibujo:
///
/// - `GET /empresas/publica/:codigo`: `{codigo, nombre, logoUrl?,
///   colorPrimario, colorAcento}`;
/// - el 409 `EMPRESA_AMBIGUA` del acceso: `empresas: [{codigo, nombre,
///   logoUrl?, colorPrimario}]`;
/// - el `empresa: {id, codigo, nombre}` del usuario de `/auth/me` y del
///   acceso.
class Clinica extends Equatable {
  /// Lo que va en `X-Empresa`. Se guarda como lo devolvió el servidor.
  final String codigo;

  final String nombre;

  /// La dirección del logotipo, si la clínica subió uno. Puede venir
  /// relativa a la API: ver [direccionDelLogo].
  final String? logoUrl;

  /// `#RRGGBB`, o `null` si no llegó o no es un color.
  final String? colorPrimario;
  final String? colorAcento;

  const Clinica({
    required this.codigo,
    required this.nombre,
    this.logoUrl,
    this.colorPrimario,
    this.colorAcento,
  });

  /// Lee una clínica de la API (o de la copia guardada), o `null` si no
  /// trae un código: sin código no hay a dónde mandar la cabecera.
  static Clinica? desdeJson(Object? json) {
    if (json is! Map) return null;

    final codigo = limpiarCodigo(json['codigo']?.toString() ?? '');
    if (codigo.isEmpty) return null;

    final nombre = json['nombre']?.toString().trim() ?? '';

    return Clinica(
      codigo: codigo,
      nombre: nombre.isEmpty ? codigo : nombre,
      logoUrl: _textoOpcional(json['logoUrl']),
      colorPrimario: colorValido(json['colorPrimario']),
      colorAcento: colorValido(json['colorAcento']),
    );
  }

  Map<String, dynamic> aJson() => {
    'codigo': codigo,
    'nombre': nombre,
    if (logoUrl != null) 'logoUrl': logoUrl,
    if (colorPrimario != null) 'colorPrimario': colorPrimario,
    if (colorAcento != null) 'colorAcento': colorAcento,
  };

  /// La misma clínica con lo que se sabe ahora de su marca. Lo que no llega
  /// se conserva.
  Clinica conMarca({
    String? nombre,
    String? logoUrl,
    String? colorPrimario,
    String? colorAcento,
  }) => Clinica(
    codigo: codigo,
    nombre: (nombre?.trim().isNotEmpty ?? false) ? nombre!.trim() : this.nombre,
    logoUrl: logoUrl ?? this.logoUrl,
    colorPrimario: colorValido(colorPrimario) ?? this.colorPrimario,
    colorAcento: colorValido(colorAcento) ?? this.colorAcento,
  );

  /// Si es la misma clínica que [otra]: el código, sin mirar mayúsculas.
  bool esLaMismaQue(Clinica? otra) => mismoCodigo(codigo, otra?.codigo);

  /// Dos letras para cuando no hay logotipo: «Clínica Andina» → «CA».
  String get iniciales {
    final palabras = nombre
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty && p.toLowerCase() != 'de')
        .toList();
    if (palabras.isEmpty) return '?';

    final letras = palabras.length == 1
        ? palabras.first.substring(0, palabras.first.length.clamp(1, 2))
        : '${palabras.first[0]}${palabras[1][0]}';

    return letras.toUpperCase();
  }

  @override
  List<Object?> get props => [
    codigo,
    nombre,
    logoUrl,
    colorPrimario,
    colorAcento,
  ];
}

/// El código como se escribe en un campo o llega en un enlace: sin espacios
/// alrededor ni dentro. Las mayúsculas se respetan: el servidor decide y la
/// aplicación guarda el código que él devuelve.
String limpiarCodigo(String codigo) => codigo.replaceAll(RegExp(r'\s+'), '');

/// Si dos códigos son de la misma clínica, sin mirar mayúsculas.
bool mismoCodigo(String? a, String? b) {
  if (a == null || b == null) return false;
  return limpiarCodigo(a).toLowerCase() == limpiarCodigo(b).toLowerCase();
}

/// Lo que se le dice a quien escribe un código que no puede ser uno, o
/// `null` si se puede consultar. Las letras, los números y los guiones son
/// lo único que lleva un código de clínica.
String? errorDeCodigo(String texto) {
  final codigo = limpiarCodigo(texto);
  if (codigo.isEmpty) return 'Escribe el código que te dio tu clínica.';
  if (codigo.length > 40) return 'Ese código es demasiado largo.';
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]*$').hasMatch(codigo)) {
    return 'El código solo lleva letras, números y guiones.';
  }
  return null;
}

/// Un color `#RRGGBB` (o `#RGB`), o `null` si no lo es.
String? colorValido(Object? valor) {
  if (valor is! String) return null;
  final texto = valor.trim();

  return RegExp(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').hasMatch(texto)
      ? texto
      : null;
}

/// La dirección absoluta del logotipo de [clinica], o `null` si no tiene o
/// no se entiende.
///
/// El servidor la puede mandar absoluta (`https://…`) o relativa a la API
/// (`/api/configuracion/logo?e=demo`, `configuracion/logo`): entonces se
/// arma con el servidor de [api] (`Entorno.apiUrl`). Una ruta con `/` se
/// toma desde la raíz del servidor; una sin barra, desde la base de la API.
Uri? direccionDelLogo(Clinica clinica, String api) {
  final texto = clinica.logoUrl?.trim() ?? '';
  if (texto.isEmpty) return null;

  final logo = Uri.tryParse(texto);
  if (logo == null) return null;

  if (logo.hasScheme) {
    final web = logo.isScheme('https') || logo.isScheme('http');
    return web && logo.host.isNotEmpty ? logo : null;
  }

  final base = Uri.tryParse(api);
  if (base == null || base.host.isEmpty) return null;

  final conBarra = base.path.endsWith('/')
      ? base
      : base.replace(path: '${base.path}/');
  return conBarra.resolveUri(logo);
}

/// La clínica que dice el token de la sesión (`empresaCodigo`, firmado por
/// la API), o `null` si no la dice o no se puede leer. Es el respaldo para
/// cuando el perfil no trae `empresaSesion`; el nombre llega después, con
/// la configuración pública.
///
/// Solo se lee: la firma la comprueba la API en cada petición.
Clinica? clinicaDelToken(String? token) {
  final partes = token?.split('.') ?? const <String>[];
  if (partes.length != 3) return null;

  try {
    final carga = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))),
    );
    if (carga is! Map) return null;

    final codigo = carga['empresaCodigo'];
    return codigo is String
        ? Clinica.desdeJson({
            'codigo': codigo,
            'nombre': carga['empresaNombre'],
          })
        : null;
  } catch (_) {
    return null;
  }
}

String? _textoOpcional(Object? valor) {
  final texto = valor?.toString().trim() ?? '';
  return texto.isEmpty ? null : texto;
}
