import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/fechas/instante.dart';
import '../../../core/integraciones/costuras.dart';
import '../../../core/network/errores.dart';

/// La sala de una videoconsulta (`Videollamada`): a dónde entrar y con qué
/// permiso.
class Videollamada extends Equatable {
  final String dominio;
  final String sala;

  /// El token firmado que abre la sala (el SDK lo usa; también va dentro de
  /// [url]).
  final String jwt;

  /// `https://dominio/sala?jwt=…`: el respaldo, en el navegador integrado.
  final String url;

  /// Desde y hasta cuándo deja entrar el servidor (instantes reales).
  final DateTime? abreEn;
  final DateTime? cierraEn;

  /// Cuándo empezó y terminó de verdad, si el médico ya entró o salió.
  final DateTime? inicio;
  final DateTime? fin;

  final bool esModerador;

  const Videollamada({
    required this.dominio,
    required this.sala,
    required this.jwt,
    required this.url,
    this.abreEn,
    this.cierraEn,
    this.inicio,
    this.fin,
    this.esModerador = false,
  });

  factory Videollamada.desdeJson(Map<dynamic, dynamic> json) {
    return Videollamada(
      dominio: json['dominio']?.toString() ?? '',
      sala: json['sala']?.toString() ?? '',
      jwt: json['jwt']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      abreEn: leerInstante(json['abreEn']),
      cierraEn: leerInstante(json['cierraEn']),
      inicio: leerInstante(json['inicio']),
      fin: leerInstante(json['fin']),
      esModerador: json['esModerador'] == true,
    );
  }

  @override
  List<Object?> get props => [
    dominio,
    sala,
    jwt,
    url,
    abreEn,
    cierraEn,
    inicio,
    fin,
    esModerador,
  ];
}

/// No se pudo entrar a la videoconsulta; [mensaje] dice por qué, con las
/// palabras del servidor cuando las hay.
class ErrorDeVideollamada implements Exception {
  final String mensaje;

  const ErrorDeVideollamada(this.mensaje);

  @override
  String toString() => mensaje;
}

/// `GET /portal/citas/:id/videollamada`: la sala de una cita de
/// telemedicina, para el paciente o el titular.
///
/// El servidor decide todo: si la cita es suya, si la sala ya abrió o ya
/// cerró según la configuración de la clínica (`minutosAntes` del inicio,
/// `minutosDespues` del fin; por defecto 15 y 60) —409 con la explicación— y
/// si la videoconsulta está configurada —503—.
class VideollamadaService {
  final Dio _dio;

  VideollamadaService(this._dio);

  Future<Videollamada> pedir(String citaId) async {
    final respuesta = await _dio.get<dynamic>(
      '/portal/citas/$citaId/videollamada',
    );

    final datos = respuesta.data;
    if (datos is! Map) {
      throw const ErrorDeVideollamada(
        'La respuesta del servidor no trae la sala. Intenta de nuevo.',
      );
    }

    return Videollamada.desdeJson(datos);
  }
}

/// Qué decir cuando no se pudo pedir la sala.
///
/// 409 (la sala todavía no abre o ya cerró) y 503 (la videoconsulta no está
/// configurada) traen su propio texto del servidor, que es el mejor; si no
/// llega, se explica igual.
String mensajeDeVideollamada(Object error) {
  if (error is ErrorDeVideollamada) return error.mensaje;

  final delServidor = mensajeDelServidor(error);
  final estado = estadoDe(error);

  if (estado == 409) {
    return delServidor ??
        'La sala no está abierta ahora. Se abre poco antes de la cita y se '
            'cierra un rato después de que termina.';
  }

  if (estado == 503) {
    return delServidor ??
        'La videoconsulta no está disponible en este momento. Comunícate '
            'con la clínica para que te atiendan.';
  }

  return mensajeDeError(
    error,
    generico: 'No pudimos abrir la videoconsulta. Intenta de nuevo.',
  );
}

/// Lo que hace falta para entrar a una sala de Jitsi con el SDK.
class DatosDeSala extends Equatable {
  /// `https://<dominio>`: el servidor de video de la clínica.
  final String servidor;
  final String sala;

  /// El token firmado por el servidor, que abre la sala.
  final String token;

  /// El nombre de quien entra, como lo ven los demás.
  final String nombreVisible;

  /// El asunto de la sala, con el nombre de la clínica.
  final String asunto;

  const DatosDeSala({
    required this.servidor,
    required this.sala,
    required this.token,
    this.nombreVisible = '',
    this.asunto = '',
  });

  /// Los de la sala que dio el servidor, o `null` si le falta algo: el
  /// dominio (o, si no llega, el de la dirección de la sala), el nombre de
  /// la sala o el token.
  static DatosDeSala? de(
    Videollamada sala, {
    String nombreVisible = '',
    String asunto = '',
  }) {
    final dominio = dominioLimpio(
      sala.dominio.isNotEmpty ? sala.dominio : Uri.tryParse(sala.url)?.host,
    );
    if (dominio.isEmpty || sala.sala.isEmpty || sala.jwt.isEmpty) return null;

    return DatosDeSala(
      servidor: 'https://$dominio',
      sala: sala.sala,
      token: sala.jwt,
      nombreVisible: nombreVisible,
      asunto: asunto,
    );
  }

  @override
  List<Object?> get props => [servidor, sala, token, nombreVisible, asunto];
}

/// El dominio de video sin esquema ni barras (`meet.clinica.ec`), como lo
/// limpia el panel; vacío si no hay.
String dominioLimpio(String? dominio) => (dominio ?? '')
    .trim()
    .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
    .replaceAll(RegExp(r'/+$'), '');

/// El SDK de video, tras una interfaz: la aplicación entra a la sala con él,
/// y las pruebas lo cambian por un doble sin plataforma. El de verdad es
/// `SalaJitsi` (`sala_jitsi.dart`).
abstract class SalaDeVideo {
  /// Si el SDK funciona en esta plataforma (Android e iOS; en la web, no).
  bool get disponible;

  /// Abre la sala. Devuelve si se abrió.
  Future<bool> entrar(DatosDeSala datos);
}

/// Abre una dirección en el navegador integrado. Devuelve si se abrió.
typedef AbrirEnNavegador = Future<bool> Function(Uri direccion);

Future<bool> _abrirEnElNavegadorIntegrado(Uri direccion) =>
    launchUrl(direccion, mode: LaunchMode.inAppBrowserView);

/// La videoconsulta dentro de la aplicación.
///
/// Pide la sala al servidor (dominio, sala y token firmado) y entra con el
/// SDK oficial de Jitsi, con el nombre de quien entra y el asunto de la
/// clínica: la persona no sale de la aplicación, y el SDK pide la cámara y
/// el micrófono como cualquier llamada. Recién si el SDK no está (la web) o
/// falla, se abre la dirección firmada de la sala en el navegador integrado
/// ([SalaAbierta.enElNavegador], y la pantalla lo avisa).
class VideollamadaEnLaApp implements ServicioVideollamada {
  final VideollamadaService _servicio;
  final SalaDeVideo _sala;
  final AbrirEnNavegador _abrirEnNavegador;

  VideollamadaEnLaApp(
    this._servicio, {
    required this._sala,
    AbrirEnNavegador? abrirEnNavegador,
  }) : _abrirEnNavegador = abrirEnNavegador ?? _abrirEnElNavegadorIntegrado;

  @override
  bool get disponible => true;

  /// Pide la sala y entra. Si algo falla lanza [ErrorDeVideollamada] con lo
  /// que hay que decirle a la persona.
  @override
  Future<SalaAbierta> unirse(
    String citaId, {
    String nombreVisible = '',
    String asunto = '',
  }) async {
    final Videollamada sala;

    try {
      sala = await _servicio.pedir(citaId);
    } catch (error) {
      throw ErrorDeVideollamada(mensajeDeVideollamada(error));
    }

    final datos = DatosDeSala.de(
      sala,
      nombreVisible: nombreVisible,
      asunto: asunto,
    );

    if (datos != null && _sala.disponible && await _entrarConElSdk(datos)) {
      return SalaAbierta.enLaAplicacion;
    }

    return _respaldo(sala);
  }

  Future<bool> _entrarConElSdk(DatosDeSala datos) async {
    try {
      return await _sala.entrar(datos);
    } catch (_) {
      return false;
    }
  }

  /// El navegador integrado, con la dirección firmada de la sala.
  Future<SalaAbierta> _respaldo(Videollamada sala) async {
    final direccion = Uri.tryParse(sala.url);
    if (direccion == null || direccion.scheme != 'https') {
      throw const ErrorDeVideollamada(
        'La sala no tiene una dirección válida. Comunícate con la clínica.',
      );
    }

    var abierta = false;
    try {
      abierta = await _abrirEnNavegador(direccion);
    } catch (_) {
      abierta = false;
    }

    if (!abierta) {
      throw const ErrorDeVideollamada(
        'No pudimos abrir la videoconsulta. Intenta de nuevo en un momento.',
      );
    }

    return SalaAbierta.enElNavegador;
  }
}
