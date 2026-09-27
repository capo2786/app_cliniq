// test/reglas_citas_test.dart

import 'package:app_cliniq/core/catalogos/catalogo_service.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/citas/dominio/reglas_citas.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';

/// Las horas mínimas para cambiar una cita (de la configuración), cómo se
/// reparten las citas entre próximas e historial y los consejos del
/// catálogo.
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

  // Las horas que dice la configuración de prueba.
  final horas12 = configDePrueba().agenda.horasMinimasCambio;

  group('Las horas mínimas para cambiar una cita', () {
    test('con 12 horas justas todavía se puede cambiar', () {
      final c = cita(inicio: DateTime(2026, 9, 28, 21));

      expect(horas12, 12);
      expect(aTiempoDeCambiar(c, ahora, horas12), isTrue);
      expect(puedeCambiar(c, ahora, horas12), isTrue);
      expect(motivoSinCambios(c, ahora, horas12), isNull);
    });

    test('con un minuto menos, ya no, y se explica por qué', () {
      final c = cita(inicio: DateTime(2026, 9, 28, 20, 59));

      expect(aTiempoDeCambiar(c, ahora, horas12), isFalse);
      expect(puedeCambiar(c, ahora, horas12), isFalse);
      expect(motivoSinCambios(c, ahora, horas12), explicacionCambioTardio(12));
      expect(explicacionCambioTardio(12), contains('menos de 12 horas'));
      expect(
        explicacionCambioTardio(12),
        contains('comunícate con la clínica'),
      );
    });

    test('si la clínica pide 24 horas, 20 horas ya no alcanzan', () {
      final horas = configDePrueba(agenda: {'horasMinimasCambio': 24})
          .agenda
          .horasMinimasCambio;
      final c = cita(inicio: DateTime(2026, 9, 29, 5));

      expect(puedeCambiar(c, ahora, 12), isTrue);
      expect(puedeCambiar(c, ahora, horas), isFalse);
      expect(motivoSinCambios(c, ahora, horas), contains('menos de 24 horas'));
    });

    test('con 1 hora el texto va en singular', () {
      expect(explicacionCambioTardio(1), contains('menos de 1 hora '));
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

      expect(puedeCambiar(atendida, ahora, horas12), isFalse);
      expect(puedeCambiar(cancelada, ahora, horas12), isFalse);
      expect(
        motivoSinCambios(cancelada, ahora, horas12),
        isNull,
        reason: 'no hay nada que explicar: ya no está pendiente',
      );
    });

    test('una reagendada con tiempo sí se puede volver a cambiar', () {
      final c = cita(
        inicio: DateTime(2026, 10, 1, 9),
        estado: EstadoCita.reagendada,
      );

      expect(puedeCambiar(c, ahora, horas12), isTrue);
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
    test('los consejos del catálogo PREPARACION_CITA de cada modalidad', () {
      final catalogos = catalogosDePrueba();

      expect(consejosPara(catalogos, TipoCita.presencial), [
        'Llega 10 minutos antes.',
        'Trae tu cédula y tus exámenes.',
      ]);
      expect(consejosPara(catalogos, TipoCita.telemedicina), [
        'Conéctate 5 minutos antes.',
      ]);
      expect(consejosPara(catalogos, TipoCita.asincrona), [
        'Ten tus exámenes a mano.',
      ]);
    });

    test('sin consejos configurados, ninguno (no hay textos de respaldo)', () {
      final lote = catalogosJson()..[Catalogos.preparacionCita] = [];

      expect(consejosPara(catalogosDePrueba(lote), TipoCita.presencial), []);
    });
  });
}
