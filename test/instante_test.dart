// test/instante_test.dart

import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/core/fechas/instante.dart';
import 'package:app_cliniq/core/formato/instantes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_cliniq/core/fechas/zona_clinica.dart';

/// Los instantes reales (consultas, mensajes, archivos) se leen respetando la
/// zona y se enseñan en la hora de la clínica: al revés que las citas.
void main() {
  // La zona de la clínica llega de su configuración (`clinica.zonaHoraria`).
  setUpAll(() => ZonaClinica.aplicar('America/Guayaquil'));

  group('leerInstante', () {
    test('con Z es un instante en UTC', () {
      final instante = leerInstante('2026-09-28T14:00:00.000Z');

      expect(instante, DateTime.utc(2026, 9, 28, 14));
      expect(instante!.isUtc, isTrue);
    });

    test('con desfase se convierte a UTC', () {
      expect(
        leerInstante('2026-09-28T09:00:00-05:00'),
        DateTime.utc(2026, 9, 28, 14),
      );
    });

    test('sin zona se toma como UTC, no como la hora del teléfono', () {
      expect(
        leerInstante('2026-09-28T14:00:00'),
        DateTime.utc(2026, 9, 28, 14),
      );
    });

    test('lo que no es un instante es null', () {
      expect(leerInstante(null), isNull);
      expect(leerInstante(''), isNull);
      expect(leerInstante('mañana'), isNull);
      expect(leerInstante(42), isNull);
    });

    test('ida y vuelta para la copia guardada', () {
      final instante = DateTime.utc(2026, 9, 28, 14, 5);
      expect(leerInstante(aTextoInstante(instante)), instante);
      expect(aTextoInstante(null), isNull);
    });
  });

  group('en la hora de la clínica', () {
    test('las 14:00 UTC son las 09:00 en Guayaquil', () {
      final local = enHoraDeLaClinica(DateTime.utc(2026, 9, 28, 14));

      expect(local, DateTime(2026, 9, 28, 9));
      expect(local.isUtc, isFalse);
    });

    test('pasada la medianoche UTC todavía es el día anterior', () {
      expect(
        enHoraDeLaClinica(DateTime.utc(2026, 9, 29, 3, 30)),
        DateTime(2026, 9, 28, 22, 30),
      );
    });

    test('el reloj fijo da el instante que corresponde a su hora local', () {
      final reloj = RelojClinica.fijo(DateTime(2026, 9, 28, 9));

      expect(reloj.instante(), DateTime.utc(2026, 9, 28, 14));
      expect(enHoraDeLaClinica(reloj.instante()), reloj.ahora());
    });
  });

  group('Cómo se dicen', () {
    // Las 09:00 del 28 de septiembre en Guayaquil.
    final ahora = DateTime.utc(2026, 9, 28, 14);

    test('hace cuánto: minutos, horas, ayer, días y, más atrás, la fecha', () {
      expect(haceCuanto(ahora, ahora), 'hace un momento');
      expect(
        haceCuanto(ahora.subtract(const Duration(minutes: 5)), ahora),
        'hace 5 min',
      );
      expect(
        haceCuanto(ahora.subtract(const Duration(hours: 3)), ahora),
        'hace 3 h',
      );
      // Las 23:00 de ayer en la clínica son las 04:00 UTC de hoy: es «ayer»
      // aunque en UTC sea el mismo día.
      expect(haceCuanto(DateTime.utc(2026, 9, 28, 4), ahora), 'ayer');
      expect(haceCuanto(DateTime.utc(2026, 9, 24, 14), ahora), 'hace 4 días');
      expect(haceCuanto(DateTime.utc(2026, 9, 1, 14), ahora), '1 sep 2026');
    });

    test('momentos y sellos en la hora de la clínica', () {
      expect(momentoLegible(ahora), 'Lunes 28 de septiembre, 09:00');
      expect(selloLegible(ahora), '28/09/2026 · 09:00');
    });
  });
}
