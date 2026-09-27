import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../../core/fechas/instante.dart';
import '../../../core/network/errores.dart';
import 'permisos_de_video.dart';

/// La sala de una videoconsulta (`Videollamada`): a dónde entrar y con qué
/// permiso.
class Videollamada extends Equatable {
  final String dominio;
  final String sala;

  /// El token firmado que abre la sala (también va dentro de [url]).
  final String jwt;

  /// `https://dominio/sala?jwt=…`. La aplicación arma la suya (con los
  /// ajustes de Jitsi); de esta solo toma el dominio si no llega aparte.
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

/// Lo que hace falta para abrir una sala de Jitsi dentro de la aplicación.
class DatosDeSala extends Equatable {
  /// El servidor de video de la clínica, sin esquema: `meet.clinica.ec`.
  final String dominio;
  final String sala;

  /// El token firmado por el servidor, que abre la sala. Trae el nombre de
  /// quien entra, como lo ven los demás.
  final String token;

  /// Hasta cuándo deja entrar el servidor (un instante real).
  final DateTime? cierraEn;

  const DatosDeSala({
    required this.dominio,
    required this.sala,
    required this.token,
    this.cierraEn,
  });

  /// Los de la sala que dio el servidor, o `null` si le falta algo: el
  /// dominio (o, si no llega, el de la dirección de la sala), el nombre de
  /// la sala o el token.
  static DatosDeSala? de(Videollamada sala) {
    final dominio = dominioLimpio(
      sala.dominio.isNotEmpty ? sala.dominio : Uri.tryParse(sala.url)?.host,
    );
    if (dominio.isEmpty || sala.sala.isEmpty || sala.jwt.isEmpty) return null;

    return DatosDeSala(
      dominio: dominio,
      sala: sala.sala,
      token: sala.jwt,
      cierraEn: sala.cierraEn,
    );
  }

  @override
  List<Object?> get props => [dominio, sala, token, cierraEn];
}

/// El dominio de video sin esquema ni barras (`meet.clinica.ec`), como lo
/// limpia el panel; vacío si no hay.
String dominioLimpio(String? dominio) => (dominio ?? '')
    .trim()
    .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
    .replaceAll(RegExp(r'/+$'), '');

/// Lo que la sala le cuenta a la pantalla que la contiene.
class OyenteDeSala {
  /// La página de la sala terminó de cargar.
  final VoidCallback alCargar;

  /// Entró a la conferencia.
  final VoidCallback alEntrar;

  /// Colgó, la echaron, el médico terminó la sala o Jitsi quiso llevarla
  /// fuera de la sala: se vuelve a la cita.
  final VoidCallback alTerminar;

  /// La sala no cargó; [mensaje] es lo que hay que decirle a la persona.
  final ValueChanged<String> alFallar;

  const OyenteDeSala({
    required this.alCargar,
    required this.alEntrar,
    required this.alTerminar,
    required this.alFallar,
  });
}

/// La sala de video dentro de la aplicación, tras una interfaz: la de
/// verdad es la página de Jitsi en un WebView (`SalaJitsi`, en
/// `sala_jitsi.dart`), y las pruebas la cambian por un doble sin plataforma.
abstract class SalaDeVideo {
  /// El widget de la sala, que llena el espacio que se le dé. [asunto] va a
  /// los ajustes de Jitsi.
  Widget construir(
    DatosDeSala datos, {
    required String asunto,
    required OyenteDeSala oyente,
  });
}

/// La videoconsulta de una cita de telemedicina.
///
/// Todo lo que la pantalla necesita para abrirla sale de aquí: pedir la
/// sala al servidor, pedir la cámara y el micrófono y dibujar la sala. Así
/// las pruebas cambian las tres cosas con un solo doble.
abstract class ServicioVideollamada {
  /// Si se puede entrar desde la aplicación. Apagado, la tarjeta de la cita
  /// explica que el enlace llega por correo.
  bool get disponible;

  /// La cámara y el micrófono del teléfono.
  PermisosDeVideo get permisos;

  /// La sala embebida.
  SalaDeVideo get sala;

  /// Pide la sala de la cita al servidor. Si no se puede, lanza
  /// [ErrorDeVideollamada] con lo que hay que decirle a la persona.
  Future<DatosDeSala> pedirSala(String citaId);
}

/// La videoconsulta dentro de la aplicación.
///
/// Pide la sala al servidor (dominio, sala y token firmado) y la pantalla
/// la abre en una ventana propia, sobre la cita: la página de Jitsi en un
/// WebView bajo la cabecera de Cliniq ([SalaDeVideo]). La persona nunca
/// sale de la aplicación: ni navegador, ni pestañas personalizadas, ni una
/// actividad de Jitsi aparte. Funciona en Android e iOS; en la web no se
/// ofrece.
class VideollamadaEnLaApp implements ServicioVideollamada {
  final VideollamadaService _servicio;

  @override
  final SalaDeVideo sala;

  @override
  final PermisosDeVideo permisos;

  /// Para las pruebas; sin él, Android e iOS.
  final bool? _disponible;

  VideollamadaEnLaApp(
    this._servicio, {
    required this.sala,
    required this.permisos,
    this._disponible,
  });

  @override
  bool get disponible =>
      _disponible ??
      (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS));

  @override
  Future<DatosDeSala> pedirSala(String citaId) async {
    final Videollamada sala;

    try {
      sala = await _servicio.pedir(citaId);
    } catch (error) {
      throw ErrorDeVideollamada(mensajeDeVideollamada(error));
    }

    final datos = DatosDeSala.de(sala);
    if (datos == null) {
      throw const ErrorDeVideollamada(
        'La sala no llegó completa del servidor. Intenta de nuevo o '
        'comunícate con la clínica.',
      );
    }

    return datos;
  }
}
