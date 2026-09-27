// test/dobles/esperas.dart

import 'package:flutter_test/flutter_test.dart';

/// Deja correr lo pendiente hasta que se cumpla [condicion], sin esperar un
/// tiempo fijo.
///
/// Dio arma cada petición con un temporizador de duración cero, que un
/// `pump()` sin duración no dispara: una petición que sale en el último
/// cuadro de una animación (al terminar de deslizar un aviso) no llega a la
/// API de mentira hasta que el reloj avanza. Esto avanza el reloj de a cero,
/// una vuelta por vez, y se detiene en cuanto la condición se cumple.
Future<void> esperarHasta(
  WidgetTester tester,
  bool Function() condicion, {
  int vueltas = 50,
}) async {
  for (var i = 0; i < vueltas && !condicion(); i++) {
    await tester.pump(Duration.zero);
  }

  expect(condicion(), isTrue, reason: 'La condición no se cumplió');
}
