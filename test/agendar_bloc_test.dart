// test/agendar_bloc_test.dart

import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/features/agendar/data/models/medico_portal.dart';
import 'package:app_cliniq/features/agendar/dominio/horarios.dart';
import 'package:app_cliniq/features/agendar/dominio/huecos.dart';
import 'package:app_cliniq/features/agendar/providers/agendar_bloc.dart';
import 'package:app_cliniq/features/agendar/providers/agendar_event.dart';
import 'package:app_cliniq/features/agendar/providers/agendar_state.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/dependientes/data/models/dependiente.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dobles.dart';

/// El agendamiento paso a paso, con un portal falso.
///
/// El reloj está fijo en el sábado 26 de septiembre de 2026 a las 10:00: el
/// médico no atiende fines de semana, así que el primer día con atención es
/// el lunes 28.
void main() {
  final reloj = RelojClinica.fijo(DateTime(2026, 9, 26, 10));
  final lunes = DateTime(2026, 9, 28);

  const semana = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

  final pediatra = MedicoPortal(
    uid: 'ped',
    nombre: 'Ana Pérez',
    especialidad: 'Pediatría',
    ciudad: 'Quito',
    modalidades: const [TipoCita.presencial, TipoCita.telemedicina],
    horariosAtencion: [
      for (final dia in semana)
        HorarioDia(
          dia: dia,
          activo: true,
          rangos: const [HorarioRango(inicio: '08:00', fin: '12:00')],
        ),
    ],
  );

  final cardiologo = MedicoPortal(
    uid: 'car',
    nombre: 'Luis Mora',
    especialidad: 'Cardiología',
    ciudad: 'Guayaquil',
    modalidades: const [TipoCita.asincrona],
    horariosAtencion: [
      for (final dia in semana)
        HorarioDia(
          dia: dia,
          activo: true,
          rangos: const [HorarioRango(inicio: '14:00', fin: '18:00')],
        ),
    ],
  );

  const tomas = Dependiente(
    uid: 'dep1',
    nombre: 'Tomás Pérez',
    parentesco: 'Hijo/a',
    fechaNacimiento: '2018-04-02',
  );

  late PortalFalso portal;

  setUp(() {
    portal = PortalFalso(
      medicosDisponibles: [pediatra, cardiologo],
      ocupadosDe: (doctor, dia) => [
        if (mismoDia(dia, lunes))
          IntervaloOcupado(
            id: 'o1',
            inicio: DateTime(2026, 9, 28, 9),
            fin: DateTime(2026, 9, 28, 9, 30),
          ),
      ],
    );
  });

  AgendarBloc crear() => AgendarBloc(
    portal: portal,
    dependientes: DependientesFalso(const [tomas]),
    catalogos: CatalogosFalso(),
    uid: 'u1',
    nombreTitular: 'Ana María Pérez',
    reloj: reloj,
  );

  /// Espera a que el estado cumpla la condición.
  Future<AgendarState> hasta(
    AgendarBloc bloc,
    bool Function(AgendarState) condicion,
  ) {
    if (condicion(bloc.state)) return Future.value(bloc.state);

    return bloc.stream
        .firstWhere(condicion)
        .timeout(const Duration(seconds: 2));
  }

  blocTest<AgendarBloc, AgendarState>(
    'al abrir carga médicos, especialidades y dependientes, y empieza por '
    '«para quién»',
    build: crear,
    act: (bloc) => bloc.add(const AgendarIniciado()),
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      final s = bloc.state;
      expect(s.cargando, isFalse);
      expect(s.paso, PasoAgendar.paciente);
      expect(s.medicos, hasLength(2));
      expect(s.dependientes, [tomas]);
      expect(s.especialidadesConMedicos, ['Pediatría', 'Cardiología']);
      expect(s.ciudades, ['Guayaquil', 'Quito']);
    },
  );

  blocTest<AgendarBloc, AgendarState>(
    'al elegir médico arranca en el primer día con atención y pide lo '
    'ocupado de ese día',
    build: crear,
    act: (bloc) async {
      bloc.add(const AgendarIniciado());
      await hasta(bloc, (s) => !s.cargando);
      bloc.add(const AgendarMedicoElegido('ped'));
    },
    wait: const Duration(milliseconds: 20),
    verify: (bloc) {
      final s = bloc.state;
      expect(s.paso, PasoAgendar.modalidad);
      expect(s.medico, pediatra);
      expect(s.fecha, lunes);
      expect(s.tipo, TipoCita.presencial);
      expect(s.ocupados, hasLength(1));
      expect(portal.consultasDeOcupados, 1);
    },
  );

  test('el recorrido completo, para un dependiente, hasta confirmar', () async {
    final bloc = crear()..add(const AgendarIniciado());
    await hasta(bloc, (s) => !s.cargando);

    // Paso 1: para Tomás.
    bloc
      ..add(const AgendarParaElegido('dep1'))
      ..add(const AgendarContinuado());
    await hasta(bloc, (s) => s.paso == PasoAgendar.filtros);
    expect(bloc.state.pacienteNombre, 'Tomás Pérez');

    // Paso 2: filtros. Pediatría deja un solo médico.
    bloc.add(const AgendarFiltrosCambiados(especialidad: 'pediatria'));
    await hasta(bloc, (s) => s.filtroEspecialidad.isNotEmpty);
    expect(bloc.state.medicosFiltrados, [
      pediatra,
    ], reason: 'se compara sin tildes ni mayúsculas');
    bloc.add(const AgendarContinuado());
    await hasta(bloc, (s) => s.paso == PasoAgendar.medico);

    // Paso 3 y 4: médico y modalidad (solo las que ofrece).
    bloc.add(const AgendarMedicoElegido('ped'));
    await hasta(
      bloc,
      (s) => s.paso == PasoAgendar.modalidad && !s.cargandoOcupados,
    );
    expect(bloc.state.modalidadesMedico, [
      TipoCita.presencial,
      TipoCita.telemedicina,
    ]);

    bloc.add(const AgendarModalidadElegida(TipoCita.asincrona));
    await Future<void>.delayed(Duration.zero);
    expect(
      bloc.state.tipo,
      TipoCita.presencial,
      reason: 'una modalidad que el médico no ofrece se ignora',
    );

    bloc.add(const AgendarModalidadElegida(TipoCita.telemedicina));
    await hasta(
      bloc,
      (s) => s.paso == PasoAgendar.horario && !s.cargandoOcupados,
    );

    // Paso 5: la hora. Telemedicina dura 20 minutos; 09:00 está ocupada.
    final s = bloc.state;
    expect(s.duracion, 20);
    expect(s.estadoDia, EstadoDia.ok);
    expect(s.diasDisponibles.first, lunes);
    expect(s.huecos.firstWhere((h) => h.hora == '09:00').ocupado, isTrue);
    expect(s.grupos[Periodo.manana], isNotEmpty);

    // Sin hora elegida no se puede seguir.
    bloc.add(const AgendarContinuado());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.paso, PasoAgendar.horario);

    bloc
      ..add(AgendarHuecoElegido(s.huecos.firstWhere((h) => h.hora == '08:00')))
      ..add(const AgendarContinuado());
    await hasta(bloc, (s) => s.paso == PasoAgendar.motivo);

    // Paso 6: el motivo es obligatorio.
    bloc.add(const AgendarContinuado());
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.paso, PasoAgendar.motivo);

    bloc
      ..add(const AgendarMotivoCambiado('Dolor de oído desde ayer'))
      ..add(const AgendarContinuado());
    await hasta(bloc, (s) => s.paso == PasoAgendar.resumen);
    expect(bloc.state.listo, isTrue);

    // Paso 7: confirmar.
    bloc.add(const AgendarConfirmado());
    final final_ = await hasta(bloc, (s) => s.paso == PasoAgendar.listo);

    final enviada = portal.agendadas.single;
    expect(enviada.aJson(), {
      'doctorId': 'ped',
      'start': '2026-09-28T08:00:00',
      'end': '2026-09-28T08:20:00',
      'type': 'TELEMEDICINA',
      'reason': 'Dolor de oído desde ayer',
      'pacienteId': 'dep1',
    });
    expect(final_.agendada?.medico, 'Ana Pérez');
    expect(final_.agendada?.paraDependiente, isTrue);
    expect(final_.agendada?.pacienteNombre, 'Tomás Pérez');

    await bloc.close();
  });

  test('si el horario se ocupó mientras tanto, se refresca y se vuelve a '
      'elegir', () async {
    var tomado = false;
    portal
      ..errorAlAgendar = errorHttp(409, 'Ese horario ya no está disponible.')
      ..ocupadosDe = (doctor, dia) => [
        if (tomado)
          IntervaloOcupado(
            id: 'o2',
            inicio: DateTime(2026, 9, 28, 8),
            fin: DateTime(2026, 9, 28, 8, 30),
          ),
      ];

    final bloc = crear()..add(const AgendarIniciado());
    await hasta(bloc, (s) => !s.cargando);

    bloc.add(const AgendarMedicoElegido('ped'));
    await hasta(bloc, (s) => s.medicoId == 'ped' && !s.cargandoOcupados);
    bloc.add(const AgendarModalidadElegida(TipoCita.presencial));
    await hasta(
      bloc,
      (s) => s.paso == PasoAgendar.horario && !s.cargandoOcupados,
    );

    bloc
      ..add(AgendarHuecoElegido(bloc.state.huecos.first))
      ..add(const AgendarContinuado())
      ..add(const AgendarMotivoCambiado('Control'))
      ..add(const AgendarContinuado());
    await hasta(bloc, (s) => s.paso == PasoAgendar.resumen);

    final consultasAntes = portal.consultasDeOcupados;
    tomado = true;
    bloc.add(const AgendarConfirmado());

    final despues = await hasta(bloc, (s) => s.aviso != null);

    expect(
      portal.consultasDeOcupados,
      consultasAntes + 1,
      reason: 'después del error se vuelve a pedir lo ocupado',
    );
    expect(despues.paso, PasoAgendar.horario);
    expect(despues.aviso, avisoHorarioTomado);
    expect(despues.hueco, isNull);
    expect(despues.errorGuardar, 'Ese horario ya no está disponible.');
    expect(despues.huecos.firstWhere((h) => h.hora == '08:00').ocupado, isTrue);

    await bloc.close();
  });

  test('reprogramar entra directo a la hora, con el mismo médico y '
      'modalidad, y su propio horario queda libre', () async {
    final original = Cita(
      id: 'c9',
      inicio: DateTime(2026, 9, 28, 9),
      fin: DateTime(2026, 9, 28, 9, 30),
      tipo: TipoCita.presencial,
      estado: EstadoCita.programada,
      doctorId: 'ped',
      medico: 'Ana Pérez',
      pacienteNombre: 'Ana María Pérez',
    );

    final bloc = crear()..add(AgendarIniciado(reprogramar: original));
    final s = await hasta(
      bloc,
      (s) => !s.cargando && !s.cargandoOcupados && s.ocupados.isNotEmpty,
    );

    expect(s.paso, PasoAgendar.horario);
    expect(s.primerPaso, PasoAgendar.horario);
    expect(s.medicoId, 'ped');
    expect(s.tipo, TipoCita.presencial);
    expect(s.fecha, lunes);
    expect(
      s.huecos.firstWhere((h) => h.hora == '09:00').ocupado,
      isFalse,
      reason: 'lo ocupado por la propia cita no cuenta',
    );
    expect(
      AgendarBloc.pasoAnterior(s),
      isNull,
      reason: 'atrás desde aquí es salir',
    );

    // El médico no se puede cambiar al reprogramar.
    bloc.add(const AgendarMedicoElegido('car'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.medicoId, 'ped');

    bloc
      ..add(AgendarHuecoElegido(s.huecos.firstWhere((h) => h.hora == '10:00')))
      ..add(const AgendarContinuado());
    await hasta(bloc, (s) => s.paso == PasoAgendar.resumen);
    expect(
      bloc.state.listo,
      isTrue,
      reason: 'al reprogramar no se pide motivo',
    );

    bloc.add(const AgendarConfirmado());
    final listo = await hasta(bloc, (s) => s.paso == PasoAgendar.listo);

    expect(portal.reprogramadas, ['c9']);
    expect(listo.agendada?.inicio, DateTime(2026, 9, 28, 10));
    expect(listo.agendada?.medico, 'Ana Pérez');

    await bloc.close();
  });

  test(
    'el filtro de modalidad elige esa modalidad al tomar el médico',
    () async {
      final bloc = crear()..add(const AgendarIniciado());
      await hasta(bloc, (s) => !s.cargando);

      bloc.add(const AgendarFiltrosCambiados(modalidad: TipoCita.telemedicina));
      await hasta(bloc, (s) => s.filtroModalidad != null);
      expect(bloc.state.medicosFiltrados, [pediatra]);

      bloc.add(const AgendarMedicoElegido('ped'));
      await hasta(bloc, (s) => s.medicoId == 'ped');
      expect(bloc.state.tipo, TipoCita.telemedicina);

      bloc.add(const AgendarFiltrosCambiados(quitarModalidad: true));
      await hasta(bloc, (s) => s.filtroModalidad == null);
      expect(bloc.state.medicosFiltrados, hasLength(2));

      await bloc.close();
    },
  );
}
