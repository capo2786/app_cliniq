// lib/core/configuracion/config_publica.dart

import 'package:equatable/equatable.dart';

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

/// `agenda`: citas, recordatorios y rejilla de horarios.
class ReglasAgenda extends Equatable {
  final int horasMinimasCambio;

  final bool recordatoriosActivos;
  final bool recordatorio24h;
  final bool recordatorio1h;
  final bool recordatorioInicio;

  /// Minutos por modalidad cuando el médico no configuró los suyos.
  final int duracionPresencial;
  final int duracionTelemedicina;
  final int duracionAsincrona;

  final int pasoMinutos;
  final int minutosAnticipacionReserva;
  final int diasHorizonteReserva;

  /// «HH:mm»: desde cuándo un horario cuenta como de la tarde o de la noche.
  final String horaInicioTarde;
  final String horaInicioNoche;

  const ReglasAgenda({
    required this.horasMinimasCambio,
    required this.recordatoriosActivos,
    required this.recordatorio24h,
    required this.recordatorio1h,
    required this.recordatorioInicio,
    required this.duracionPresencial,
    required this.duracionTelemedicina,
    required this.duracionAsincrona,
    required this.pasoMinutos,
    required this.minutosAnticipacionReserva,
    required this.diasHorizonteReserva,
    required this.horaInicioTarde,
    required this.horaInicioNoche,
  });

  factory ReglasAgenda._leer(_Lector l) => ReglasAgenda(
    horasMinimasCambio: l.entero('horasMinimasCambio'),
    recordatoriosActivos: l.booleano('recordatoriosActivos'),
    recordatorio24h: l.booleano('recordatorio24h'),
    recordatorio1h: l.booleano('recordatorio1h'),
    recordatorioInicio: l.booleano('recordatorioInicio'),
    duracionPresencial: l.entero('duracionPresencial', minimo: 1),
    duracionTelemedicina: l.entero('duracionTelemedicina', minimo: 1),
    duracionAsincrona: l.entero('duracionAsincrona', minimo: 1),
    pasoMinutos: l.entero('pasoMinutos', minimo: 1),
    minutosAnticipacionReserva: l.entero('minutosAnticipacionReserva'),
    diasHorizonteReserva: l.entero('diasHorizonteReserva', minimo: 1),
    horaInicioTarde: l.hora('horaInicioTarde'),
    horaInicioNoche: l.hora('horaInicioNoche'),
  );

  @override
  List<Object?> get props => [
    horasMinimasCambio,
    recordatoriosActivos,
    recordatorio24h,
    recordatorio1h,
    recordatorioInicio,
    duracionPresencial,
    duracionTelemedicina,
    duracionAsincrona,
    pasoMinutos,
    minutosAnticipacionReserva,
    diasHorizonteReserva,
    horaInicioTarde,
    horaInicioNoche,
  ];
}

/// `telemedicina`: la sala de video y las consultas en línea.
class ReglasTelemedicina extends Equatable {
  /// Cuántos minutos antes del inicio abre la sala y cuántos después del fin
  /// la cierra.
  final int minutosAntes;
  final int minutosDespues;

  final int horasRespuesta;
  final int diasSeguimiento;
  final int maxArchivosConsulta;

  const ReglasTelemedicina({
    required this.minutosAntes,
    required this.minutosDespues,
    required this.horasRespuesta,
    required this.diasSeguimiento,
    required this.maxArchivosConsulta,
  });

  factory ReglasTelemedicina._leer(_Lector l) => ReglasTelemedicina(
    minutosAntes: l.entero('minutosAntes'),
    minutosDespues: l.entero('minutosDespues'),
    horasRespuesta: l.entero('horasRespuesta', minimo: 1),
    diasSeguimiento: l.entero('diasSeguimiento'),
    maxArchivosConsulta: l.entero('maxArchivosConsulta'),
  );

  @override
  List<Object?> get props => [
    minutosAntes,
    minutosDespues,
    horasRespuesta,
    diasSeguimiento,
    maxArchivosConsulta,
  ];
}

/// `archivos`: el tope de cada archivo que se sube y los tipos que la
/// clínica acepta.
class ReglasArchivos extends Equatable {
  final int tamanoMaximoMb;

  /// Tipos MIME aceptados (`application/pdf`, `image/jpeg`…), elegidos por
  /// el administrador entre los que el servidor sabe verificar por su
  /// contenido.
  final List<String> tipos;

  const ReglasArchivos({required this.tamanoMaximoMb, required this.tipos});

  /// El tope en bytes, como lo mide el servidor (1 MB = 1024 × 1024).
  int get tamanoMaximoBytes => tamanoMaximoMb * 1024 * 1024;

  factory ReglasArchivos._leer(_Lector l) => ReglasArchivos(
    tamanoMaximoMb: l.entero('tamanoMaximoMb', minimo: 1),
    tipos: [for (final t in l.textos('tipos')) t.toLowerCase()],
  );

  @override
  List<Object?> get props => [tamanoMaximoMb, tipos];
}

/// `seguridad`: contraseñas, bloqueos y códigos.
class ReglasSeguridad extends Equatable {
  final int passwordMinimo;
  final int bloqueoMinutos;
  final int otpMinutos;

  /// Cuántos dígitos tiene el código de verificación en dos pasos.
  final int otpDigitos;
  final int resetMinutos;
  final int reenvioSegundos;

  const ReglasSeguridad({
    required this.passwordMinimo,
    required this.bloqueoMinutos,
    required this.otpMinutos,
    required this.otpDigitos,
    required this.resetMinutos,
    required this.reenvioSegundos,
  });

  factory ReglasSeguridad._leer(_Lector l) => ReglasSeguridad(
    passwordMinimo: l.entero('passwordMinimo', minimo: 1),
    bloqueoMinutos: l.entero('bloqueoMinutos'),
    otpMinutos: l.entero('otpMinutos'),
    otpDigitos: l.entero('otpDigitos', minimo: 1),
    resetMinutos: l.entero('resetMinutos'),
    reenvioSegundos: l.entero('reenvioSegundos'),
  );

  @override
  List<Object?> get props => [
    passwordMinimo,
    bloqueoMinutos,
    otpMinutos,
    otpDigitos,
    resetMinutos,
    reenvioSegundos,
  ];
}

/// `general`: lo que queda de la sección general que la aplicación usa.
class ReglasGenerales extends Equatable {
  /// Si la cédula ecuatoriana se valida con su dígito verificador (módulo
  /// 10). Apagado, basta con que tenga diez dígitos.
  final bool validarCedula;

  /// Los días que tiene la clínica para responder una solicitud ARCO (el
  /// servidor calcula con ellos el `plazoVence` de cada una).
  final int arcoPlazoDias;

  /// Hasta cuántos días después de una cita atendida se puede responder su
  /// encuesta.
  final int encuestasDiasVentana;

  /// Horas de respuesta de soporte por severidad del ticket
  /// (`{CRITICA: 4, ALTA: 24, …}`), las mismas con que el servidor calcula
  /// el vencimiento de cada ticket.
  final Map<String, int> soporteHorasSla;

  /// A cuántas horas del vencimiento un ticket abierto «vence pronto».
  final int soporteHorasAviso;

  const ReglasGenerales({
    required this.validarCedula,
    required this.arcoPlazoDias,
    required this.encuestasDiasVentana,
    required this.soporteHorasSla,
    required this.soporteHorasAviso,
  });

  factory ReglasGenerales._leer(_Lector l) => ReglasGenerales(
    validarCedula: l.booleano('validarCedula'),
    arcoPlazoDias: l.entero('arcoPlazoDias', minimo: 1),
    encuestasDiasVentana: l.entero('encuestasDiasVentana', minimo: 1),
    soporteHorasSla: l.enterosPorClave('soporteHorasSla', minimo: 1),
    soporteHorasAviso: l.entero('soporteHorasAviso', minimo: 1),
  );

  @override
  List<Object?> get props => [
    validarCedula,
    arcoPlazoDias,
    encuestasDiasVentana,
    soporteHorasSla,
    soporteHorasAviso,
  ];
}

/// `clinico`: las reglas clínicas de apoyo que la aplicación usa.
class ReglasClinicas extends Equatable {
  /// Los días que suma la regla de Naegele a la fecha de la última
  /// menstruación para la fecha probable de parto (Mi salud).
  final int diasGestacion;

  const ReglasClinicas({required this.diasGestacion});

  factory ReglasClinicas._leer(_Lector l) =>
      ReglasClinicas(diasGestacion: l.entero('diasGestacion', minimo: 1));

  @override
  List<Object?> get props => [diasGestacion];
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
