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

  /// El token firmado que abre la sala. Va dentro de [url].
  final String jwt;

  /// `https://dominio/sala?jwt=…`: lo que se abre en el navegador.
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

/// Abre una dirección fuera de la aplicación. Devuelve si se abrió.
typedef AbrirFuera = Future<bool> Function(Uri direccion);

Future<bool> _abrirEnElNavegador(Uri direccion) =>
    launchUrl(direccion, mode: LaunchMode.externalApplication);

/// La videoconsulta en el navegador del teléfono.
///
/// La sala es de Jitsi y el navegador ya sabe pedir la cámara y el
/// micrófono, compartir pantalla y seguir con la pantalla apagada: meterla
/// dentro de la aplicación obligaría a cargar un SDK de video entero para
/// hacer lo mismo peor. La aplicación pide la sala, recibe su dirección
/// firmada y la abre fuera.
class VideollamadaEnNavegador implements ServicioVideollamada {
  final VideollamadaService _servicio;
  final AbrirFuera _abrir;

  VideollamadaEnNavegador(this._servicio, {AbrirFuera? abrir})
    : _abrir = abrir ?? _abrirEnElNavegador;

  @override
  bool get disponible => true;

  /// Pide la sala y la abre. Si algo falla lanza [ErrorDeVideollamada] con
  /// lo que hay que decirle a la persona.
  @override
  Future<void> unirse(String citaId) async {
    final Videollamada sala;

    try {
      sala = await _servicio.pedir(citaId);
    } catch (error) {
      throw ErrorDeVideollamada(mensajeDeVideollamada(error));
    }

    final direccion = Uri.tryParse(sala.url);
    if (direccion == null || direccion.scheme != 'https') {
      throw const ErrorDeVideollamada(
        'La sala no tiene una dirección válida. Comunícate con la clínica.',
      );
    }

    var abierta = false;
    try {
      abierta = await _abrir(direccion);
    } catch (_) {
      abierta = false;
    }

    if (!abierta) {
      throw const ErrorDeVideollamada(
        'No pudimos abrir el navegador. Revisa que tengas uno instalado e '
        'intenta de nuevo.',
      );
    }
  }
}
