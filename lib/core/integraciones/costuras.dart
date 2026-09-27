// lib/core/integraciones/costuras.dart

/// Las costuras de lo que depende de un tercero y todavía falta: avisos push
/// y pagos.
///
/// Cada uno tiene aquí su interfaz y una implementación «apagada», y
/// `Servicios` decide cuál se usa: enchufar el de verdad es cambiar una línea
/// en `lib/core/servicios.dart`, sin tocar las pantallas. La videollamada ya
/// no es una costura: está hecha, dentro de la aplicación, y su interfaz vive
/// con ella (`ServicioVideollamada`, en
/// `features/citas/data/videollamada_service.dart`).
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
