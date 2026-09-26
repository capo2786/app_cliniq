// test/huecos_test.dart

import 'package:app_cliniq/features/agendar/data/models/medico_portal.dart';
import 'package:app_cliniq/features/agendar/dominio/horarios.dart';
import 'package:app_cliniq/features/agendar/dominio/huecos.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:flutter_test/flutter_test.dart';

/// El puerto del cálculo de horarios del panel web.
///
/// Estas pruebas fijan las mismas reglas que `agenda.utils.ts` y
/// `horarios.model.ts`: turnos, bloqueos, duración por modalidad, margen a
/// ambos lados de cada cita, paso de 15 minutos, límite diario, el primer día
/// con atención y los grupos de mañana, tarde y noche.
void main() {
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

  // Lunes 28 de septiembre de 2026.
  final lunes = DateTime(2026, 9, 28);

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

    test('rangosDelDia: solo los válidos del día de la semana, en orden', () {
      final m = medico(
        horarios: const [
          HorarioDia(
            dia: 'Lunes',
            activo: true,
            rangos: [
              HorarioRango(inicio: '14:00', fin: '16:00'),
              HorarioRango(inicio: '10:00', fin: '09:00'),
              HorarioRango(inicio: '08:00', fin: '09:00'),
            ],
          ),
        ],
      );

      expect(rangosDelDia(m.horariosAtencion, lunes), const [
        HorarioRango(inicio: '08:00', fin: '09:00'),
        HorarioRango(inicio: '14:00', fin: '16:00'),
      ]);
      expect(rangosDelDia(m.horariosAtencion, DateTime(2026, 9, 29)), isEmpty);
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

      expect(duracionDe(propio, TipoCita.presencial), 45);
      expect(duracionDe(propio, TipoCita.telemedicina), 20);
      expect(duracionDe(null, TipoCita.asincrona), 15);
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

  group('calcularHuecos', () {
    final antes = DateTime(2026, 9, 27, 20);

    test('paso de 15 minutos y solo si la cita cabe entera en el turno', () {
      final huecos = calcularHuecos(
        fecha: lunes,
        rangos: const [HorarioRango(inicio: '08:00', fin: '09:00')],
        duracion: 30,
        citas: const [],
        ahora: antes,
      );

      expect(huecos.map((h) => h.hora), ['08:00', '08:15', '08:30']);
      expect(huecos.last.fin, DateTime(2026, 9, 28, 9));
    });

    test('lo que ya pasó no se ofrece', () {
      final huecos = calcularHuecos(
        fecha: lunes,
        rangos: const [HorarioRango(inicio: '08:00', fin: '10:00')],
        duracion: 30,
        citas: const [],
        ahora: DateTime(2026, 9, 28, 8, 40),
      );

      expect(huecos.first.hora, '08:45');
    });

    test('el margen se suma a ambos lados de cada cita', () {
      final cita = IntervaloOcupado(
        id: 'c1',
        inicio: DateTime(2026, 9, 28, 9),
        fin: DateTime(2026, 9, 28, 9, 30),
      );

      final huecos = calcularHuecos(
        fecha: lunes,
        rangos: const [HorarioRango(inicio: '08:00', fin: '11:00')],
        duracion: 30,
        margen: 10,
        citas: [cita],
        ahora: antes,
      );

      Hueco a(String hora) => huecos.firstWhere((h) => h.hora == hora);

      // 08:15–08:45 termina antes de 08:50: libre.
      expect(a('08:15').ocupado, isFalse);
      // 08:30–09:00 pisa el margen previo (08:50).
      expect(a('08:30').ocupado, isTrue);
      expect(a('09:00').ocupado, isTrue);
      // 09:30 empieza antes de 09:40 (fin + margen).
      expect(a('09:30').ocupado, isTrue);
      // 09:45 ya está fuera del margen.
      expect(a('09:45').ocupado, isFalse);
    });

    test('sin margen, una cita que termina justo cuando empieza otra no '
        'choca', () {
      final huecos = calcularHuecos(
        fecha: lunes,
        rangos: const [HorarioRango(inicio: '09:00', fin: '10:00')],
        duracion: 30,
        citas: [
          IntervaloOcupado(
            id: 'c1',
            inicio: DateTime(2026, 9, 28, 9),
            fin: DateTime(2026, 9, 28, 9, 30),
          ),
        ],
        ahora: antes,
      );

      expect(huecos.firstWhere((h) => h.hora == '09:30').ocupado, isFalse);
    });

    test('la cita que se reprograma no ocupa su propio horario', () {
      final original = IntervaloOcupado(
        id: 'mia',
        inicio: DateTime(2026, 9, 28, 9),
        fin: DateTime(2026, 9, 28, 9, 30),
      );

      final huecos = calcularHuecos(
        fecha: lunes,
        rangos: const [HorarioRango(inicio: '09:00', fin: '10:00')],
        duracion: 30,
        citas: [original],
        excluirId: 'mia',
        ahora: antes,
      );

      expect(huecos.every((h) => !h.ocupado), isTrue);
    });

    test('las citas que ya no ocupan (canceladas) y las de otro día no '
        'cuentan', () {
      final huecos = calcularHuecos(
        fecha: lunes,
        rangos: const [HorarioRango(inicio: '09:00', fin: '10:00')],
        duracion: 30,
        citas: [
          IntervaloOcupado(
            id: 'c1',
            inicio: DateTime(2026, 9, 28, 9),
            fin: DateTime(2026, 9, 28, 9, 30),
            ocupaHorario: false,
          ),
          IntervaloOcupado(
            id: 'c2',
            inicio: DateTime(2026, 9, 29, 9),
            fin: DateTime(2026, 9, 29, 9, 30),
          ),
        ],
        ahora: antes,
      );

      expect(huecos.every((h) => !h.ocupado), isTrue);
    });

    test('mañana hasta las 12:00, tarde hasta las 19:00, noche después', () {
      final huecos = calcularHuecos(
        fecha: lunes,
        rangos: const [
          HorarioRango(inicio: '11:30', fin: '12:15'),
          HorarioRango(inicio: '18:45', fin: '19:30'),
        ],
        duracion: 15,
        citas: const [],
        ahora: antes,
      );

      Periodo p(String hora) =>
          huecos.firstWhere((h) => h.hora == hora).periodo;

      expect(p('11:45'), Periodo.manana);
      expect(p('12:00'), Periodo.tarde);
      expect(p('18:45'), Periodo.tarde);
      expect(p('19:00'), Periodo.noche);

      final grupos = agruparPorPeriodo(huecos);
      expect(grupos.keys, Periodo.values);
      expect(grupos[Periodo.noche]!.map((h) => h.hora), ['19:00', '19:15']);
    });

    test('turnos que se pisan no repiten horarios y salen en orden', () {
      final huecos = calcularHuecos(
        fecha: lunes,
        rangos: const [
          HorarioRango(inicio: '09:00', fin: '10:00'),
          HorarioRango(inicio: '09:30', fin: '10:30'),
        ],
        duracion: 30,
        citas: const [],
        ahora: antes,
      );

      final horas = huecos.map((h) => h.hora).toList();
      expect(horas, ['09:00', '09:15', '09:30', '09:45', '10:00']);
    });
  });

  group('Límite diario y siguiente día con atención', () {
    IntervaloOcupado cita(DateTime dia, int hora) => IntervaloOcupado(
      id: 'c$hora-${dia.day}',
      inicio: DateTime(dia.year, dia.month, dia.day, hora),
      fin: DateTime(dia.year, dia.month, dia.day, hora, 30),
    );

    test('el límite cuenta solo las citas activas de ese día', () {
      final m = medico(config: const ConfigAgenda(limiteDiario: 2));

      expect(limiteAlcanzado(m, [cita(lunes, 8)], lunes), isFalse);
      expect(
        limiteAlcanzado(m, [cita(lunes, 8), cita(lunes, 9)], lunes),
        isTrue,
      );
      expect(
        limiteAlcanzado(
          m,
          [cita(lunes, 8), cita(lunes, 9)],
          lunes,
          excluirId: 'c9-28',
        ),
        isFalse,
      );
      expect(
        limiteAlcanzado(medico(), [cita(lunes, 8)], lunes),
        isFalse,
        reason: 'sin límite configurado',
      );
    });

    test('salta fines de semana y días bloqueados', () {
      final m = medico(
        bloqueos: const [
          BloqueoAgenda(desde: '2026-10-05', hasta: '2026-10-05'),
        ],
      );

      // Desde el viernes 2 de octubre: sábado y domingo no atiende, el
      // lunes 5 está bloqueado → martes 6.
      expect(
        siguienteDiaConAtencion(m, DateTime(2026, 10, 2, 15)),
        DateTime(2026, 10, 6),
      );
    });

    test('salta los días que ya llegaron al límite si se pasan las citas', () {
      final m = medico(config: const ConfigAgenda(limiteDiario: 1));
      final martes = DateTime(2026, 9, 29);

      expect(
        siguienteDiaConAtencion(m, lunes, citas: [cita(martes, 8)]),
        DateTime(2026, 9, 30),
      );
    });

    test('sin días de atención en 60 días devuelve null', () {
      expect(
        siguienteDiaConAtencion(medico(horarios: const []), lunes),
        isNull,
      );
    });
  });

  group('Primer día con atención (agendar.ts)', () {
    test('hoy, si todavía cabe una cita con la anticipación', () {
      final m = medico();

      expect(primerDiaConAtencion(m, 30, DateTime(2026, 9, 28, 17, 0)), lunes);
      expect(quedaHoy(m, 30, DateTime(2026, 9, 28, 17, 0)), isTrue);
    });

    test('mañana, si hoy ya no cabe ninguna', () {
      final m = medico();

      // 17:20 + 15 de anticipación = 17:35; la última cita de 30 min
      // empieza a las 17:30: ya no cabe.
      expect(quedaHoy(m, 30, DateTime(2026, 9, 28, 17, 20)), isFalse);
      expect(
        primerDiaConAtencion(m, 30, DateTime(2026, 9, 28, 17, 20)),
        DateTime(2026, 9, 29),
      );
    });

    test('un día bloqueado no cuenta como hoy', () {
      final m = medico(
        bloqueos: const [
          BloqueoAgenda(desde: '2026-09-28', hasta: '2026-09-28'),
        ],
      );

      expect(quedaHoy(m, 30, DateTime(2026, 9, 28, 8)), isFalse);
    });

    test('la etiqueta de la tarjeta del médico', () {
      final m = medico();

      expect(proximaFecha(m, 30, DateTime(2026, 9, 28, 9)), 'Hoy');
      expect(proximaFecha(m, 30, DateTime(2026, 9, 26, 9)), 'Lun 28 sep');
      expect(
        proximaFecha(medico(horarios: const []), 30, lunes),
        'Sin fechas próximas',
      );
    });

    test('la tira de días solo trae días con atención', () {
      final dias = diasConAtencion(
        medico(),
        DateTime(2026, 10, 2),
        cantidad: 3,
      );

      expect(dias, [
        DateTime(2026, 10, 2),
        DateTime(2026, 10, 5),
        DateTime(2026, 10, 6),
      ]);
    });
  });
}

extension on HorarioDia {
  HorarioDia copiarDia(String dia) =>
      HorarioDia(dia: dia, activo: activo, rangos: rangos);
}
