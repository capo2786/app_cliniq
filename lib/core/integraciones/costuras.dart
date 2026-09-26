// lib/core/integraciones/costuras.dart

/// Las costuras para lo que todavía no está: avisos push, videollamada y
/// pagos.
///
/// Ninguno de los tres entra en esta versión porque dependen de un tercero
/// (Firebase, un proveedor de video, una pasarela de pago). Pero el día que
/// entren no deberían obligar a tocar las pantallas: cada uno tiene aquí su
/// interfaz y una implementación «apagada», y `Servicios` decide cuál se usa.
/// Enchufar el de verdad es cambiar una línea en `lib/core/servicios.dart`.
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
