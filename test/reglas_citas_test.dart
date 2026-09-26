// test/reglas_citas_test.dart

import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/citas/dominio/reglas_citas.dart';
import 'package:flutter_test/flutter_test.dart';

/// La regla de las 12 horas y cómo se reparten las citas entre próximas e
/// historial.
void main() {
  Cita cita({
    String id = 'c1',
    required DateTime inicio,
    EstadoCita estado = EstadoCita.programada,
    TipoCita tipo = TipoCita.presencial,
  }) {
    return Cita(
      id: id,
      inicio: inicio,
      fin: inicio.add(const Duration(minutes: 30)),
      tipo: tipo,
      estado: estado,
      doctorId: 'doc',
    );
  }

  final ahora = DateTime(2026, 9, 28, 9);

  group('La regla de las 12 horas', () {
    test('con 12 horas justas todavía se puede cambiar', () {
      final c = cita(inicio: DateTime(2026, 9, 28, 21));

      expect(aTiempoDeCambiar(c, ahora), isTrue);
      expect(puedeCambiar(c, ahora), isTrue);
      expect(motivoSinCambios(c, ahora), isNull);
    });

    test('con un minuto menos, ya no, y se explica por qué', () {
      final c = cita(inicio: DateTime(2026, 9, 28, 20, 59));

      expect(aTiempoDeCambiar(c, ahora), isFalse);
      expect(puedeCambiar(c, ahora), isFalse);
      expect(motivoSinCambios(c, ahora), explicacionCambioTardio);
    });

    test('una cita atendida o cancelada no se cambia, a ninguna hora', () {
      final atendida = cita(
        inicio: DateTime(2026, 10, 5, 9),
        estado: EstadoCita.atendida,
      );
      final cancelada = cita(
        inicio: DateTime(2026, 10, 5, 9),
        estado: EstadoCita.cancelada,
      );

      expect(puedeCambiar(atendida, ahora), isFalse);
      expect(puedeCambiar(cancelada, ahora), isFalse);
      expect(
        motivoSinCambios(cancelada, ahora),
        isNull,
        reason: 'no hay nada que explicar: ya no está pendiente',
      );
    });

    test('una reagendada con tiempo sí se puede volver a cambiar', () {
      final c = cita(
        inicio: DateTime(2026, 10, 1, 9),
        estado: EstadoCita.reagendada,
      );

      expect(puedeCambiar(c, ahora), isTrue);
    });
  });

  group('Próximas e historial', () {
    final pasada = cita(id: 'pasada', inicio: DateTime(2026, 9, 20, 9));
    final enCurso = cita(id: 'en-curso', inicio: DateTime(2026, 9, 28, 8, 45));
    final manana = cita(id: 'manana', inicio: DateTime(2026, 9, 29, 9));
    final lejana = cita(id: 'lejana', inicio: DateTime(2026, 10, 20, 9));
    final cancelada = cita(
      id: 'cancelada',
      inicio: DateTime(2026, 10, 1, 9),
      estado: EstadoCita.cancelada,
    );

    final todas = [lejana, cancelada, pasada, manana, enCurso];

    test(
      'próximas: pendientes sin terminar, de la más cercana a la lejana',
      () {
        expect(proximasCitas(todas, ahora).map((c) => c.id), [
          'en-curso',
          'manana',
          'lejana',
        ]);
        expect(proximaCita(todas, ahora)?.id, 'en-curso');
      },
    );

    test('historial: lo demás, de la más reciente a la más antigua', () {
      expect(historialDeCitas(todas, ahora).map((c) => c.id), [
        'cancelada',
        'pasada',
      ]);
    });

    test('sin citas pendientes no hay próxima', () {
      expect(proximaCita([pasada, cancelada], ahora), isNull);
    });
  });

  group('Cuenta regresiva', () {
    test('días, horas y minutos', () {
      expect(
        cuentaRegresiva(cita(inicio: DateTime(2026, 10, 1, 9)), ahora),
        'Faltan 3 días',
      );
      expect(
        cuentaRegresiva(cita(inicio: DateTime(2026, 9, 29, 12)), ahora),
        'Falta 1 día y 3 h',
      );
      expect(
        cuentaRegresiva(cita(inicio: DateTime(2026, 9, 28, 12, 20)), ahora),
        'Faltan 3 h 20 min',
      );
      expect(
        cuentaRegresiva(cita(inicio: DateTime(2026, 9, 28, 9, 15)), ahora),
        'Empieza en 15 min',
      );
      expect(
        cuentaRegresiva(cita(inicio: DateTime(2026, 9, 28, 8, 50)), ahora),
        'En curso',
      );
    });
  });

  group('Cómo prepararse', () {
    test('un consejo propio por modalidad', () {
      expect(
        consejosPara(TipoCita.presencial).join(' '),
        allOf(contains('10 minutos'), contains('cédula')),
      );
      expect(
        consejosPara(TipoCita.telemedicina).join(' '),
        allOf(contains('5 minutos'), contains('privado')),
      );
      expect(consejosPara(TipoCita.asincrona).join(' '), contains('exámenes'));
    });
  });
}
