// test/recordatorios_test.dart

import 'package:app_cliniq/core/notificaciones/recordatorios_citas.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los recordatorios locales: 24 h y 1 h antes de cada cita pendiente.
void main() {
  Cita cita(
    String id,
    DateTime inicio, {
    EstadoCita estado = EstadoCita.programada,
  }) {
    return Cita(
      id: id,
      inicio: inicio,
      fin: inicio.add(const Duration(minutes: 30)),
      tipo: TipoCita.telemedicina,
      estado: estado,
      doctorId: 'doc',
      medico: 'Ana Pérez',
    );
  }

  final ahora = DateTime(2026, 9, 28, 9);

  test('dos avisos por cita: un día y una hora antes', () {
    final avisos = recordatoriosPara([
      cita('a', DateTime(2026, 9, 30, 10)),
    ], ahora);

    expect(avisos.map((r) => r.momento), [
      DateTime(2026, 9, 29, 10),
      DateTime(2026, 9, 30, 9),
    ]);
    expect(avisos.first.titulo, 'Mañana hay cita');
    expect(avisos.last.cuerpo, contains('Dr(a). Ana Pérez'));
    expect(avisos.last.cuerpo, contains('Conéctate 5 minutos antes'));
  });

  test('el aviso cuya hora ya pasó no se programa', () {
    // Faltan 5 horas: el de 24 h ya pasó, el de 1 h no.
    final avisos = recordatoriosPara([
      cita('a', DateTime(2026, 9, 28, 14)),
    ], ahora);

    expect(avisos, hasLength(1));
    expect(avisos.single.momento, DateTime(2026, 9, 28, 13));
  });

  test('ni citas pasadas ni canceladas', () {
    final avisos = recordatoriosPara([
      cita('pasada', DateTime(2026, 9, 27, 9)),
      cita('cancelada', DateTime(2026, 10, 5, 9), estado: EstadoCita.cancelada),
    ], ahora);

    expect(avisos, isEmpty);
  });

  test('las citas de un dependiente dicen de quién son', () {
    final deHijo = Cita(
      id: 'h',
      inicio: DateTime(2026, 9, 30, 10),
      fin: DateTime(2026, 9, 30, 10, 30),
      tipo: TipoCita.presencial,
      estado: EstadoCita.programada,
      doctorId: 'doc',
      pacienteNombre: 'Tomás',
      paraDependiente: true,
    );

    expect(
      recordatoriosPara([deHijo], ahora).first.titulo,
      'Mañana hay cita de Tomás',
    );
  });

  test('identificadores estables, distintos y dentro de su rango', () {
    final a1 = identificadorDeRecordatorio('abc', AntelacionRecordatorio.unDia);
    final a2 = identificadorDeRecordatorio('abc', AntelacionRecordatorio.unDia);
    final b = identificadorDeRecordatorio(
      'abc',
      AntelacionRecordatorio.unaHora,
    );

    expect(a1, a2);
    expect(a1, isNot(b));
    for (final id in [a1, b]) {
      expect(id, greaterThanOrEqualTo(idBaseRecordatorios));
      expect(id, lessThan(idBaseRecordatorios + anchoRangoRecordatorios));
    }
  });
}
