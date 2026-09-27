// test/huecos_test.dart

import 'package:app_cliniq/features/agendar/data/models/medico_portal.dart';
import 'package:app_cliniq/features/agendar/data/models/turnos.dart';
import 'package:app_cliniq/features/agendar/dominio/horarios.dart';
import 'package:app_cliniq/features/agendar/dominio/huecos.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';

/// La presentación de los turnos que calcula la API, y la jornada del
/// médico.
///
/// Los huecos ya no se calculan en la aplicación: la API los manda
/// (`/portal/turnos/:doctorId`). Aquí se prueba lo que queda: agrupar por
/// día y por mañana, tarde y noche con los cortes de la clínica, no seguir
/// ofreciendo lo que dejó de cumplir la anticipación ni lo que el servidor
/// rechazó, y decir cuándo es un turno con palabras naturales. La
/// configuración de prueba (`r`) tiene la tarde desde las 12:00, la noche
/// desde las 19:00 y 15 minutos de anticipación.
void main() {
  final r = reglasDePrueba();

  const lunesAViernes = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

  MedicoPortal medico({
    List<HorarioDia>? horarios,
    ConfigAgenda? config,
    List<BloqueoAgenda> bloqueos = const [],
  }) {
    return MedicoPortal(
      uid: 'doc',
      nombre: 'Ana Pérez',
      horariosAtencion:
          horarios ??
          [
            for (final dia in lunesAViernes)
              const HorarioDia(
                dia: '',
                activo: true,
                rangos: [
                  HorarioRango(inicio: '08:00', fin: '12:00'),
                  HorarioRango(inicio: '14:00', fin: '18:00'),
                ],
              ).copiarDia(dia),
          ],
      configAgenda: config,
      bloqueos: bloqueos,
    );
  }

  Turno turno(int mes, int dia, int hora, int minuto, [int duracion = 30]) {
    final inicio = DateTime(2026, mes, dia, hora, minuto);
    return Turno(
      inicio: inicio,
      fin: inicio.add(Duration(minutes: duracion)),
    );
  }

  // Lunes 28 de septiembre de 2026, a las 10:00.
  final ahora = DateTime(2026, 9, 28, 10);

  group('Horarios del médico', () {
    test('normalizar completa los siete días y apaga los que no tienen '
        'turnos', () {
      final normalizados = normalizarHorarios([
        const HorarioDia(dia: 'Martes', activo: true, rangos: []),
        const HorarioDia(
          dia: 'Lunes',
          activo: true,
          rangos: [HorarioRango(inicio: '09:00', fin: '10:00')],
        ),
      ]);

      expect(normalizados.map((d) => d.dia), diasSemana);
      expect(normalizados[0].activo, isTrue);
      expect(normalizados[1].activo, isFalse, reason: 'activo pero sin turnos');
      expect(normalizados[6].activo, isFalse);
    });

    test('bloqueoEn cubre los extremos, inclusive', () {
      final m = medico(
        bloqueos: const [
          BloqueoAgenda(
            desde: '2026-10-01',
            hasta: '2026-10-02',
            motivo: 'Congreso',
          ),
        ],
      );

      expect(bloqueoEn(m, DateTime(2026, 9, 30)), isNull);
      expect(bloqueoEn(m, DateTime(2026, 10, 1))?.motivo, 'Congreso');
      expect(bloqueoEn(m, DateTime(2026, 10, 2, 17)), isNotNull);
      expect(bloqueoEn(m, DateTime(2026, 10, 3)), isNull);
    });

    test('duración propia del médico o la de la clínica', () {
      final propio = medico(
        config: const ConfigAgenda(duraciones: {'PRESENCIAL': 45}),
      );

      expect(duracionDe(propio, TipoCita.presencial, r), 45);
      expect(duracionDe(propio, TipoCita.telemedicina, r), 20);
      expect(duracionDe(null, TipoCita.asincrona, r), 15);
    });

    test('margen nunca negativo', () {
      expect(
        margenDe(medico(config: const ConfigAgenda(margenMinutos: 10))),
        10,
      );
      expect(
        margenDe(medico(config: const ConfigAgenda(margenMinutos: -5))),
        0,
      );
      expect(margenDe(null), 0);
    });

    test('resumen de la jornada', () {
      expect(
        resumenHorario(medico().horariosAtencion),
        'Lu Ma Mi Ju Vi · 08:00–12:00, 14:00–18:00',
      );
      expect(resumenHorario(const []), 'Sin horario configurado');
    });
  });

  group('Fichas de los turnos de la API', () {
    final turnos = [
      turno(9, 29, 8, 0),
      turno(9, 28, 11, 45),
      turno(9, 28, 12, 0),
      turno(9, 28, 19, 0, 20),
      turno(9, 30, 18, 59),
    ];

    test('una ficha por turno, con su hora, su fin y su periodo', () {
      final h = Hueco.deTurno(turno(9, 28, 9, 30, 45), r);

      expect(h.hora, '09:30');
      expect(h.inicio, DateTime(2026, 9, 28, 9, 30));
      expect(h.fin, DateTime(2026, 9, 28, 10, 15));
      expect(h.periodo, Periodo.manana);
      expect(h.mismoHorario(Hueco.deTurno(turno(9, 28, 9, 30, 45), r)), isTrue);
      expect(
        h.mismoHorario(Hueco.deTurno(turno(9, 29, 9, 30, 45), r)),
        isFalse,
      );
    });

    test('los días que tienen turnos, en orden y sin repetir', () {
      expect(diasConTurnos(turnos), [
        DateTime(2026, 9, 28),
        DateTime(2026, 9, 29),
        DateTime(2026, 9, 30),
      ]);
      expect(diasConTurnos(const []), isEmpty);
    });

    test('las fichas de un día, en orden, agrupadas en mañana, tarde y '
        'noche con los cortes de la clínica', () {
      final lunes = huecosDelDia(turnos, DateTime(2026, 9, 28), r);
      expect(lunes.map((h) => h.hora), ['11:45', '12:00', '19:00']);

      final grupos = agruparPorPeriodo(lunes);
      expect(grupos.keys, Periodo.values, reason: 'siempre los tres, en orden');
      expect(grupos[Periodo.manana]!.map((h) => h.hora), ['11:45']);
      expect(grupos[Periodo.tarde]!.map((h) => h.hora), ['12:00']);
      expect(grupos[Periodo.noche]!.map((h) => h.hora), ['19:00']);

      expect(
        huecosDelDia(turnos, DateTime(2026, 9, 30), r).single.periodo,
        Periodo.tarde,
        reason: '18:59 todavía es de la tarde',
      );
      expect(huecosDelDia(turnos, DateTime(2026, 10, 1), r), isEmpty);
    });

    test('horaInicioTarde y horaInicioNoche mueven los cortes', () {
      final reglas = reglasDePrueba(
        agenda: {'horaInicioTarde': '13:00', 'horaInicioNoche': '18:00'},
      );

      expect(periodoDe(12 * 60 + 59, reglas), Periodo.manana);
      expect(periodoDe(13 * 60, reglas), Periodo.tarde);
      expect(periodoDe(17 * 60 + 59, reglas), Periodo.tarde);
      expect(periodoDe(18 * 60, reglas), Periodo.noche);
      expect(periodoDe(12 * 60, r), Periodo.tarde);
    });
  });

  group('Turnos que todavía se pueden ofrecer', () {
    final turnos = [
      turno(9, 28, 10, 10),
      turno(9, 28, 10, 15),
      turno(9, 28, 10, 30),
      turno(9, 29, 8, 0),
    ];

    test('no los que ya no cumplen la anticipación de la clínica', () {
      final limite = ahoraConAnticipacion(ahora, r);
      expect(limite, DateTime(2026, 9, 28, 10, 15));

      expect(
        turnosVigentes(turnos, limite: limite).map((t) => t.inicio.minute),
        [30, 0],
        reason: 'el de las 10:15 empieza justo en el límite: ya no vale',
      );

      final conUnaHora = reglasDePrueba(
        agenda: {'minutosAnticipacionReserva': 60},
      );
      expect(
        turnosVigentes(turnos, limite: ahoraConAnticipacion(ahora, conUnaHora)),
        [turno(9, 29, 8, 0)],
      );
    });

    test('no los que el servidor rechazó por estar tomados', () {
      expect(
        turnosVigentes(
          turnos,
          limite: ahora,
          descartados: {DateTime(2026, 9, 28, 10, 30)},
        ),
        [turno(9, 28, 10, 10), turno(9, 28, 10, 15), turno(9, 29, 8, 0)],
      );
    });
  });

  group('Palabras naturales', () {
    test('hoy, mañana, el día de esta semana y, más allá, con el mes', () {
      expect(diaNatural(DateTime(2026, 9, 28, 18), ahora), 'hoy');
      expect(diaNatural(DateTime(2026, 9, 29, 8), ahora), 'mañana');
      expect(diaNatural(DateTime(2026, 9, 30), ahora), 'mié 30');
      expect(diaNatural(DateTime(2026, 10, 4), ahora), 'dom 4');
      expect(diaNatural(DateTime(2026, 10, 5), ahora), 'lun 5 oct');
      expect(diaNatural(DateTime(2026, 11, 12), ahora), 'jue 12 nov');
    });

    test('el turno con su hora', () {
      expect(
        turnoNatural(DateTime(2026, 9, 28, 15, 30), ahora),
        'hoy a las 15:30',
      );
      expect(
        turnoNatural(DateTime(2026, 9, 29, 9), ahora),
        'mañana a las 09:00',
      );
      expect(
        turnoNatural(DateTime(2026, 10, 2, 8, 5), ahora),
        'vie 2 a las 08:05',
      );
    });

    test('cuántos médicos, y cuándo es el próximo turno', () {
      expect(cantidadDeMedicos(1), '1 médico');
      expect(cantidadDeMedicos(3), '3 médicos');
      expect(
        resumenDisponibilidad(3, DateTime(2026, 9, 28, 15, 30), ahora),
        '3 médicos · próximo turno hoy a las 15:30',
      );
      expect(resumenDisponibilidad(1, null, ahora), '1 médico');
    });
  });

  test('las duraciones por defecto son las de la configuración', () {
    final reglas = reglasDePrueba(
      agenda: {
        'duracionPresencial': 40,
        'duracionTelemedicina': 25,
        'duracionAsincrona': 10,
      },
    );

    expect(duracionDe(null, TipoCita.presencial, reglas), 40);
    expect(duracionDe(null, TipoCita.telemedicina, reglas), 25);
    expect(duracionDe(null, TipoCita.asincrona, reglas), 10);
    // La del médico sigue mandando si la configuró.
    expect(
      duracionDe(
        medico(config: const ConfigAgenda(duraciones: {'PRESENCIAL': 45})),
        TipoCita.presencial,
        reglas,
      ),
      45,
    );
  });
}

extension on HorarioDia {
  HorarioDia copiarDia(String dia) =>
      HorarioDia(dia: dia, activo: activo, rangos: rangos);
}
