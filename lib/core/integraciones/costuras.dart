// lib/core/integraciones/costuras.dart

/// Las costuras de lo que depende de un tercero: avisos push, videollamada y
/// pagos.
///
/// Cada uno tiene aquí su interfaz y una implementación «apagada», y
/// `Servicios` decide cuál se usa: enchufar el de verdad es cambiar una línea
/// en `lib/core/servicios.dart`, sin tocar las pantallas. La videollamada ya
/// está enchufada (`VideollamadaEnNavegador`, en
/// `features/citas/data/videollamada_service.dart`); los avisos push y los
/// pagos siguen apagados.
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

/// Entrar a la videollamada de una cita de telemedicina.
abstract class ServicioVideollamada {
  /// Si se puede entrar desde la aplicación. Apagado, la tarjeta de la cita
  /// explica que el enlace llega por correo.
  bool get disponible;

  /// Entra a la sala de la cita. Si no se puede, lanza una excepción cuyo
  /// texto es lo que hay que decirle a la persona.
  Future<void> unirse(String citaId);
}

class VideollamadaNoDisponible implements ServicioVideollamada {
  const VideollamadaNoDisponible();

  @override
  bool get disponible => false;

  @override
  Future<void> unirse(String citaId) async {}
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
