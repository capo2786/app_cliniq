// lib/core/integraciones/costuras.dart

/// Las costuras de lo que depende de un tercero: avisos push, videollamada y
/// pagos.
///
/// Cada uno tiene aquí su interfaz y una implementación «apagada», y
/// `Servicios` decide cuál se usa: enchufar el de verdad es cambiar una línea
/// en `lib/core/servicios.dart`, sin tocar las pantallas. La videollamada ya
/// está enchufada (`VideollamadaEnLaApp`, en
/// `features/citas/data/videollamada_service.dart`: el SDK de Jitsi dentro
/// de la aplicación); los avisos push y los pagos siguen apagados.
library;

/// Avisos al teléfono enviados por la clínica (Firebase Cloud Messaging).
abstract class ServicioPush {
  /// Apunta este teléfono para recibir avisos de esta cuenta.
  Future<void> registrarEsteTelefono();

  /// Deja de recibir avisos: al cerrar sesión, para que en un teléfono
  /// compartido no le lleguen a la siguiente persona.
  Future<void> olvidarEsteTelefono();
}

/// Sin avisos push: la aplicación se usa entera igual y los recordatorios
/// locales siguen sonando.
class PushApagado implements ServicioPush {
  const PushApagado();

  @override
  Future<void> registrarEsteTelefono() async {}

  @override
  Future<void> olvidarEsteTelefono() async {}
}

/// Dónde se abrió la sala de una videoconsulta.
enum SalaAbierta {
  /// Dentro de la aplicación, con el SDK de video.
  enLaAplicacion,

  /// En el navegador integrado: el respaldo si el SDK no está o falló. La
  /// pantalla lo avisa.
  enElNavegador,
}

/// Entrar a la videollamada de una cita de telemedicina.
abstract class ServicioVideollamada {
  /// Si se puede entrar desde la aplicación. Apagado, la tarjeta de la cita
  /// explica que el enlace llega por correo.
  bool get disponible;

  /// Entra a la sala de la cita, con [nombreVisible] (el de quien entra) y
  /// [asunto] (el de la sala: lleva el nombre de la clínica). Dice dónde se
  /// abrió; si no se puede, lanza una excepción cuyo texto es lo que hay
  /// que decirle a la persona.
  Future<SalaAbierta> unirse(
    String citaId, {
    String nombreVisible = '',
    String asunto = '',
  });
}

class VideollamadaNoDisponible implements ServicioVideollamada {
  const VideollamadaNoDisponible();

  @override
  bool get disponible => false;

  /// Nunca se llama: sin videollamada, la tarjeta no ofrece entrar.
  @override
  Future<SalaAbierta> unirse(
    String citaId, {
    String nombreVisible = '',
    String asunto = '',
  }) => Future.error(UnsupportedError('La videollamada no está disponible'));
}

/// Pagar una cita desde la aplicación.
abstract class ServicioPagos {
  bool get disponible;

  Future<void> pagar(String citaId);
}

class PagosNoDisponibles implements ServicioPagos {
  const PagosNoDisponibles();

  @override
  bool get disponible => false;

  @override
  Future<void> pagar(String citaId) async {}
}
