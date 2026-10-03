// lib/core/configuracion/config_publica.dart

import 'package:equatable/equatable.dart';

part 'reglas_publicas.dart';

/// La configuración pública de la clínica: `GET /configuracion/publica`.
///
/// Es lo que el administrador ajusta en Administración › Configuración y la
/// aplicación necesita para funcionar como la clínica decidió: el nombre y el
/// logotipo, las horas para cambiar una cita, la ventana de la sala de video,
/// los recordatorios, la rejilla de horarios, los topes de archivos, los
/// tiempos de seguridad… Nada de eso está escrito en la aplicación.
///
/// La lectura es **estricta** con lo que la aplicación usa: si falta un campo
/// o no tiene la forma esperada, la respuesta entera se descarta
/// ([FormatException]) y se sigue con la última copia buena. Un campo que
/// falta no se rellena con un valor inventado. Lo que la aplicación no usa
/// (el RUC, las edades, las reglas del panel) no se lee.
class ConfigPublica extends Equatable {
  final DatosClinica clinica;
  final ReglasAgenda agenda;
  final ReglasTelemedicina telemedicina;
  final ReglasArchivos archivos;
  final ReglasSeguridad seguridad;
  final ReglasGenerales general;
  final ReglasClinicas clinico;

  /// La respuesta tal como llegó, para guardarla y volver a leerla igual.
  final Map<String, dynamic> datos;

  const ConfigPublica({
    required this.clinica,
    required this.agenda,
    required this.telemedicina,
    required this.archivos,
    required this.seguridad,
    required this.general,
    required this.clinico,
    this.datos = const {},
  });

  factory ConfigPublica.desdeJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('La configuración pública no es un objeto');
    }

    final lector = _Lector(Map<String, dynamic>.from(json), '');

    return ConfigPublica(
      clinica: DatosClinica._leer(lector.seccion('clinica')),
      agenda: ReglasAgenda._leer(lector.seccion('agenda')),
      telemedicina: ReglasTelemedicina._leer(lector.seccion('telemedicina')),
      archivos: ReglasArchivos._leer(lector.seccion('archivos')),
      seguridad: ReglasSeguridad._leer(lector.seccion('seguridad')),
      general: ReglasGenerales._leer(lector.seccion('general')),
      clinico: ReglasClinicas._leer(lector.seccion('clinico')),
      datos: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> aJson() => datos;

  @override
  List<Object?> get props => [
    clinica,
    agenda,
    telemedicina,
    archivos,
    seguridad,
    general,
    clinico,
  ];
}

/// `clinica`: quién es la clínica y cómo se la contacta.
class DatosClinica extends Equatable {
  final String nombre;
  final String telefono;
  final String correoContacto;
  final String telefonoEmergencia;
  final String eslogan;

  /// La dirección absoluta del logotipo (`GET /configuracion/logo?v=…`, que
  /// sale de MinIO) o, de un servidor anterior, un data URL (PNG, JPG o
  /// SVG). `null` si no hay, o si no es ninguna de las dos: sin logotipo
  /// propio se enseña el de la marca, que la aplicación ya trae dibujado.
  final String? logo;

  /// Nombre IANA (`America/Guayaquil`).
  final String zonaHoraria;

  /// Los dos colores de la marca de la clínica (`#RRGGBB`), o `null` si no
  /// llegan o no son un color: entonces el tema usa los de siempre (así lo
  /// dice el contrato).
  final String? colorPrimario;
  final String? colorAcento;

  const DatosClinica({
    required this.nombre,
    required this.telefono,
    required this.correoContacto,
    required this.telefonoEmergencia,
    required this.eslogan,
    required this.logo,
    required this.zonaHoraria,
    this.colorPrimario,
    this.colorAcento,
  });

  /// De dónde sale el logotipo, o `null` si no hay uno propio.
  OrigenDelLogo? get origenDelLogo => OrigenDelLogo.desde(logo);

  factory DatosClinica._leer(_Lector l) => DatosClinica(
    nombre: l.texto('nombre'),
    telefono: l.texto('telefono'),
    correoContacto: l.texto('correoContacto'),
    telefonoEmergencia: l.texto('telefonoEmergencia'),
    eslogan: l.texto('eslogan'),
    // Es opcional: uno que no se entiende no descarta la configuración,
    // deja el logotipo de marca.
    logo: OrigenDelLogo.desde(l.textoOpcional('logo'))?.texto,
    zonaHoraria: l.texto('zonaHoraria'),
    colorPrimario: l.colorOpcional('colorPrimario'),
    colorAcento: l.colorOpcional('colorAcento'),
  );

  @override
  List<Object?> get props => [
    nombre,
    telefono,
    correoContacto,
    telefonoEmergencia,
    eslogan,
    logo,
    zonaHoraria,
    colorPrimario,
    colorAcento,
  ];
}

/// De dónde sale el logotipo de la clínica (`clinica.logo`).
///
/// Hoy es una dirección absoluta a `GET /configuracion/logo`, pública, que
/// el servidor lee de MinIO; lleva `?v=<huella corta>`, así que cambia cada
/// vez que la clínica sube otro. Un servidor anterior lo manda como data
/// URL dentro de la configuración, y se sigue aceptando.
sealed class OrigenDelLogo extends Equatable {
  const OrigenDelLogo();

  /// Lo que llegó en la configuración, tal cual.
  String get texto;

  /// Lee `clinica.logo`: una dirección `https://` (o `http://`) con servidor,
  /// o un data URL de imagen. Cualquier otra cosa —una ruta relativa, otro
  /// esquema, un texto— es `null`.
  static OrigenDelLogo? desde(String? valor) {
    final texto = valor?.trim() ?? '';
    if (texto.isEmpty) return null;

    if (texto.toLowerCase().startsWith('data:')) {
      return texto.toLowerCase().startsWith('data:image/')
          ? LogoEnDataUrl(texto)
          : null;
    }

    final url = Uri.tryParse(texto);
    if (url == null ||
        !(url.isScheme('https') || url.isScheme('http')) ||
        url.host.isEmpty) {
      return null;
    }

    return LogoEnLaRed(url);
  }
}

/// El logotipo se baja de su dirección (y se guarda en el teléfono).
class LogoEnLaRed extends OrigenDelLogo {
  final Uri url;

  const LogoEnLaRed(this.url);

  @override
  String get texto => url.toString();

  @override
  List<Object?> get props => [url];
}

/// El logotipo viene dentro de la configuración, como data URL.
class LogoEnDataUrl extends OrigenDelLogo {
  final String dataUrl;

  const LogoEnDataUrl(this.dataUrl);

  @override
  String get texto => dataUrl;

  @override
  List<Object?> get props => [dataUrl];
}

/// Lee campos obligatorios de una sección y dice cuál falta si falta uno.
class _Lector {
  final Map<String, dynamic> _datos;
  final String _ruta;

  const _Lector(this._datos, this._ruta);

  String _nombre(String campo) => _ruta.isEmpty ? campo : '$_ruta.$campo';

  Never _falta(String campo, Object? valor) => throw FormatException(
    'Campo de la configuración ausente o no válido: ${_nombre(campo)}',
    valor?.toString(),
  );

  _Lector seccion(String campo) {
    final valor = _datos[campo];
    if (valor is! Map) _falta(campo, valor);

    return _Lector(Map<String, dynamic>.from(valor), _nombre(campo));
  }

  String texto(String campo) {
    final valor = _datos[campo];
    if (valor is! String) _falta(campo, valor);

    return valor.trim();
  }

  /// Un color `#RRGGBB` (o `#RGB`), o `null` si no llegó o no es un color.
  /// Es de los pocos campos opcionales: sin él se usan los tokens del tema.
  String? colorOpcional(String campo) {
    final valor = _datos[campo];
    if (valor is! String) return null;

    final texto = valor.trim();
    return RegExp(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').hasMatch(texto)
        ? texto
        : null;
  }

  /// Una lista de textos (puede venir vacía).
  List<String> textos(String campo) {
    final valor = _datos[campo];
    if (valor is! List || valor.any((x) => x is! String)) _falta(campo, valor);

    return [
      for (final x in valor)
        if ((x as String).trim().isNotEmpty) x.trim(),
    ];
  }

  /// Un objeto de enteros por clave (`{CRITICA: 4, ALTA: 24}`), con al
  /// menos una clave y todos los valores desde [minimo].
  Map<String, int> enterosPorClave(String campo, {int minimo = 0}) {
    final valor = _datos[campo];
    if (valor is! Map || valor.isEmpty) _falta(campo, valor);

    final lector = seccion(campo);

    return {
      for (final clave in valor.keys)
        clave.toString(): lector.entero(clave.toString(), minimo: minimo),
    };
  }

  String? textoOpcional(String campo) {
    final valor = _datos[campo];
    if (valor == null) return null;
    if (valor is! String) _falta(campo, valor);

    final texto = valor.trim();
    return texto.isEmpty ? null : texto;
  }

  /// Un entero; se acepta también un número escrito como texto («12»), que
  /// es como a veces lo guarda un formulario.
  int entero(String campo, {int minimo = 0}) {
    final valor = _datos[campo];
    final numero = switch (valor) {
      int() => valor,
      num() when valor == valor.roundToDouble() => valor.toInt(),
      String() => int.tryParse(valor.trim()),
      _ => null,
    };

    if (numero == null || numero < minimo) _falta(campo, valor);

    return numero;
  }

  /// Un entero entre [minimo] y [maximo], o `null` si no llegó.
  int? enteroOpcional(String campo, {int minimo = 0, int? maximo}) {
    final valor = _datos[campo];
    if (valor == null) return null;
    final numero = entero(campo, minimo: minimo);
    if (maximo != null && numero > maximo) _falta(campo, valor);
    return numero;
  }

  bool? booleanoOpcional(String campo) =>
      _datos[campo] == null ? null : booleano(campo);

  bool booleano(String campo) {
    final valor = _datos[campo];

    return switch (valor) {
      bool() => valor,
      'true' => true,
      'false' => false,
      _ => _falta(campo, valor),
    };
  }

  /// «HH:mm» de 00:00 a 23:59.
  String hora(String campo) {
    final valor = _datos[campo];
    final coincide = valor is String
        ? RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').firstMatch(valor.trim())
        : null;

    if (coincide == null) _falta(campo, valor);

    return coincide.group(0)!;
  }
}
