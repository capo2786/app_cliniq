// test/fecha_local_test.dart

import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las fechas de la API son hora local de la clínica «congelada» como UTC.
///
/// Es el error más fácil de cometer y el más caro: una cita de las 09:00
/// leída como un instante UTC aparece a las 04:00 en un teléfono de Quito.
/// Estas pruebas fijan que la zona se descarta y nunca se convierte.
void main() {
  group('Leer fechas de la API', () {
    test('la Z se descarta: las 09:00Z son las 09:00 locales', () {
      final fecha = aFechaLocal('2026-09-28T09:00:00.000Z');

      expect(fecha.isUtc, isFalse);
      expect(fecha.year, 2026);
      expect(fecha.month, 9);
      expect(fecha.day, 28);
      expect(fecha.hour, 9);
      expect(fecha.minute, 0);
    });

    test('la forma estricta, sin zona, se lee igual', () {
      expect(aFechaLocal('2026-09-28T09:00:00'), DateTime(2026, 9, 28, 9));
    });

    test('un desfase explícito también se ignora, nunca se convierte', () {
      expect(
        aFechaLocal('2026-09-28T09:00:00-05:00'),
        DateTime(2026, 9, 28, 9),
      );
      expect(
        aFechaLocal('2026-09-28T09:00:00+02:00'),
        DateTime(2026, 9, 28, 9),
      );
    });

    test('una fecha sola queda a medianoche', () {
      expect(aFechaLocal('2026-09-28'), DateTime(2026, 9, 28));
    });

    test('las fechas imposibles no se desbordan al mes siguiente', () {
      expect(leerFechaLocal('2026-02-30T09:00:00Z'), isNull);
      expect(leerFechaLocal('2026-13-01'), isNull);
      expect(leerFechaLocal('2026-09-28T25:00:00'), isNull);
    });

    test('lo que no es una fecha devuelve null o lanza', () {
      expect(leerFechaLocal(null), isNull);
      expect(leerFechaLocal(42), isNull);
      expect(leerFechaLocal('mañana'), isNull);
      expect(() => aFechaLocal('mañana'), throwsFormatException);
    });
  });

  group('Escribir fechas para la API', () {
    test('sin zona y con segundos: YYYY-MM-DDTHH:mm:ss', () {
      expect(aTextoLocal(DateTime(2026, 9, 28, 9, 5)), '2026-09-28T09:05:00');
    });

    test('ida y vuelta sin moverse ni un minuto', () {
      const original = '2026-12-31T23:45:00';
      expect(aTextoLocal(aFechaLocal(original)), original);
      expect(aTextoLocal(aFechaLocal('$original.000Z')), original);
    });

    test('el día del calendario', () {
      expect(fechaIso(DateTime(2026, 1, 5, 18)), '2026-01-05');
      expect(deFechaIso('2026-01-05'), DateTime(2026, 1, 5));
      expect(deFechaIso('2026-02-29'), isNull);
      expect(deFechaIso('05/01/2026'), isNull);
    });

    test('sumar días va por el calendario', () {
      expect(sumarDias(DateTime(2026, 12, 31, 15), 1), DateTime(2027, 1, 1));
      expect(
        mismoDia(DateTime(2026, 9, 28, 1), DateTime(2026, 9, 28, 23)),
        isTrue,
      );
    });
  });

  group('La hora de la clínica', () {
    test('Ecuador continental es UTC−5, esté donde esté el teléfono', () {
      final reloj = RelojClinica(() => DateTime.utc(2026, 9, 28, 14, 30));

      expect(reloj.ahora(), DateTime(2026, 9, 28, 9, 30));
      expect(reloj.hoy(), DateTime(2026, 9, 28));
    });

    test('pasada la medianoche UTC todavía es el día anterior en Quito', () {
      final reloj = RelojClinica(() => DateTime.utc(2026, 9, 29, 2));

      expect(reloj.ahora(), DateTime(2026, 9, 28, 21));
    });

    test('un reloj fijo devuelve exactamente la hora local pedida', () {
      final reloj = RelojClinica.fijo(DateTime(2026, 9, 28, 8, 15));

      expect(reloj.ahora(), DateTime(2026, 9, 28, 8, 15));
    });
  });
}
