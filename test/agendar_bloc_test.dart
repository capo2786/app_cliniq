// test/agendar_bloc_test.dart

import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/features/agendar/data/models/medico_portal.dart';
import 'package:app_cliniq/features/agendar/data/models/turnos.dart';
import 'package:app_cliniq/features/agendar/dominio/horarios.dart';
import 'package:app_cliniq/features/agendar/dominio/huecos.dart';
import 'package:app_cliniq/features/agendar/providers/agendar_bloc.dart';
import 'package:app_cliniq/features/agendar/providers/agendar_event.dart';
import 'package:app_cliniq/features/agendar/providers/agendar_state.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/dependientes/data/models/dependiente.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dobles.dart';

/// El agendamiento paso a paso, con un portal falso que hace de API.
///
/// La API es la que calcula los turnos libres: el portal falso devuelve los
/// que la prueba le pone, y lo que se comprueba es qué pide el bloc, cuándo,
/// y cómo enseña lo que llega. El reloj está fijo en el lunes 28 de
/// septiembre de 2026 a las 10:00 de la clínica.
void main() {
  final reloj = RelojClinica.fijo(DateTime(2026, 9, 28, 10));

  Turno turno(int dia, int hora, int minuto, [int duracion = 30]) {
    final inicio = DateTime(2026, 9, dia, hora, minuto);
    return Turno(
      inicio: inicio,
      fin: inicio.add(Duration(minutes: duracion)),
    );
  }

  ProximoTurno proximo(Turno t, TipoCita modalidad, [String? doctorId]) =>
      ProximoTurno(
        inicio: t.inicio,
        fin: t.fin,
        modalidad: modalidad,
        doctorId: doctorId,
      );

  final hoy1530 = turno(28, 15, 30);
  final hoy1930 = turno(28, 19, 30);
  final martes0800 = turno(29, 8, 0);
  final martes1300 = turno(29, 13, 0);

  final pediatra = MedicoPortal(
    uid: 'ped',
    nombre: 'Ana Pérez',
    especialidad: 'Pediatría',
    ciudad: 'Quito',
    modalidades: const [TipoCita.presencial, TipoCita.telemedicina],
    proximo: proximo(hoy1530, TipoCita.presencial),
  );

  final pediatra2 = MedicoPortal(
    uid: 'ped2',
    nombre: 'Marta Núñez',
    especialidad: 'Pediatría',
    ciudad: 'Quito',
    modalidades: const [TipoCita.presencial],
    proximo: proximo(martes0800, TipoCita.presencial),
  );

  final cardiologo = MedicoPortal(
    uid: 'car',
    nombre: 'Luis Mora',
    especialidad: 'Cardiología',
    ciudad: 'Guayaquil',
    modalidades: const [TipoCita.asincrona],
    proximo: proximo(turno(29, 9, 0, 15), TipoCita.asincrona),
  );

  final especialidades = [
    EspecialidadDisponible(
      nombre: 'Pediatría',
      medicos: 2,
      proximo: proximo(hoy1530, TipoCita.presencial, 'ped'),
    ),
    EspecialidadDisponible(
      nombre: 'Cardiología',
      medicos: 1,
      proximo: proximo(turno(29, 9, 0, 15), TipoCita.asincrona, 'car'),
    ),
  ];

  /// Lo que la API devuelve de `/portal/turnos/:doctorId`.
  List<Turno> turnosDeLaApi(String doctor, TipoCita modalidad) => switch ((
    doctor,
    modalidad,
  )) {
    ('ped', TipoCita.presencial) => [hoy1530, hoy1930, martes0800, martes1300],
    ('ped', TipoCita.telemedicina) => [
      turno(29, 9, 0, 20),
      turno(30, 10, 0, 20),
    ],
    ('ped2', TipoCita.presencial) => [martes0800],
    ('car', TipoCita.asincrona) => [turno(29, 9, 0, 15)],
    _ => const [],
  };

  const tomas = Dependiente(
    uid: 'dep1',
    nombre: 'Tomás Pérez',
    parentesco: 'Hijo/a',
    fechaNacimiento: '2018-04-02',
  );

  late PortalFalso portal;

  setUp(() {
    portal = PortalFalso(
      medicosDisponibles: [pediatra, pediatra2, cardiologo],
      especialidadesDisponibles: especialidades,
      turnosDe: turnosDeLaApi,
    );
  });

  AgendarBloc crear({Map<String, dynamic>? agenda}) => AgendarBloc(
    portal: portal,
    dependientes: DependientesFalso(const [tomas]),
    uid: 'u1',
    nombreTitular: 'Ana María Pérez',
    reglas: reglasDePrueba(agenda: agenda),
    ciudades: catalogosDePrueba().ciudades,
    reloj: reloj,
  );

  /// Espera a que el estado cumpla la condición (sin plazos fijos: el
  /// estado llega en cuanto el bloc lo emite).
  Future<AgendarState> hasta(
    AgendarBloc bloc,
    bool Function(AgendarState) condicion,
  ) {
    if (condicion(bloc.state)) return Future.value(bloc.state);

    return bloc.stream.firstWhere(condicion);
  }

  /// Se suscribe antes de mandar el evento y espera a que una recarga
  /// empiece y termine: `cargando` dice qué indicador mirar.
  Future<AgendarState> trasRecargar(
    AgendarBloc bloc,
    bool Function(AgendarState) cargando,
  ) {
    var empezo = false;

    return bloc.stream.firstWhere((s) {
      if (cargando(s)) empezo = true;
      return empezo && !cargando(s);
    });
  }

  bool cargandoProximos(AgendarState s) => s.cargandoProximos;

  /// Con los turnos del médico elegido ya cargados.
  bool conTurnos(AgendarState s) =>
      s.turnosActuales != null && !s.cargandoTurnos;

  Future<AgendarBloc> abierto({Map<String, dynamic>? agenda}) async {
    final bloc = crear(agenda: agenda)..add(const AgendarIniciado());
    await hasta(bloc, (s) => !s.cargando);
    return bloc;
  }

  /// Hasta la rejilla del médico en esa modalidad.
  Future<AgendarBloc> enLaRejilla(
    String medico,
    TipoCita modalidad, {
    Map<String, dynamic>? agenda,
  }) async {
    final bloc = await abierto(agenda: agenda);
    bloc.add(AgendarMedicoElegido(medico));
    await hasta(bloc, (s) => s.medicoId == medico && conTurnos(s));
    bloc.add(AgendarModalidadElegida(modalidad));
    await hasta(
      bloc,
      (s) =>
          s.paso == PasoAgendar.horario && s.tipo == modalidad && conTurnos(s),
    );
    return bloc;
  }

  List<String> horas(AgendarState s) => [for (final h in s.huecos) h.hora];

  group('Especialidades y médicos', () {
    blocTest<AgendarBloc, AgendarState>(
      'al abrir pide los próximos turnos una vez, con los dependientes, y '
      'empieza por «para quién»',
      build: crear,
      act: (bloc) async {
        bloc.add(const AgendarIniciado());
        await hasta(bloc, (s) => !s.cargando);
      },
      verify: (bloc) {
        final s = bloc.state;
        expect(s.paso, PasoAgendar.paciente);
        expect(s.dependientes, [tomas]);
        expect(s.medicos, [pediatra, pediatra2, cardiologo]);
        expect(s.especialidades.map((e) => e.nombre), [
          'Pediatría',
          'Cardiología',
        ], reason: 'en el orden en que las manda la API');
        // En el orden del catálogo CIUDAD.
        expect(s.ciudades, ['Quito', 'Guayaquil']);
        expect(portal.consultasDeProximos, hasLength(1));
        expect(portal.consultasDeProximos.single.modalidad, isNull);
        expect(portal.consultasDeTurnos, isEmpty);
      },
    );

    test('elegir una especialidad pasa a sus médicos, y el primer turno '
        'disponible es el que manda la API para ella', () async {
      final bloc = await abierto();

      bloc.add(const AgendarEspecialidadElegida('Pediatría'));
      final s = await hasta(bloc, (s) => s.paso == PasoAgendar.medico);

      expect(s.especialidadElegida?.medicos, 2);
      expect(s.medicosDeLaEspecialidad, [pediatra, pediatra2]);
      expect(s.primerTurno?.medico, pediatra);
      expect(s.primerTurno?.turno.inicio, hoy1530.inicio);
      expect(s.primerTurno?.turno.modalidad, TipoCita.presencial);
      expect(
        portal.consultasDeProximos,
        hasLength(1),
        reason: 'la especialidad se filtra con lo que ya llegó',
      );

      // Todas: el más cercano de cualquier médico.
      bloc.add(const AgendarPasoCambiado(PasoAgendar.filtros));
      await hasta(bloc, (s) => s.paso == PasoAgendar.filtros);
      bloc.add(const AgendarEspecialidadElegida(''));
      final todas = await hasta(
        bloc,
        (s) => s.paso == PasoAgendar.medico && s.filtroEspecialidad.isEmpty,
      );
      expect(todas.medicosDeLaEspecialidad, hasLength(3));
      expect(todas.primerTurno?.medico, pediatra);
      expect(todas.primerTurno?.turno.doctorId, 'ped');

      await bloc.close();
    });

    test('el buscador filtra por nombre, sin tildes ni mayúsculas', () async {
      final bloc = await abierto();
      bloc.add(const AgendarEspecialidadElegida(''));

      bloc.add(const AgendarBusquedaCambiada('nunez'));
      var s = await hasta(bloc, (s) => s.busqueda == 'nunez');
      expect(s.medicosFiltrados, [pediatra2]);

      bloc.add(const AgendarBusquedaCambiada('  PÉREZ ana '));
      s = await hasta(bloc, (s) => s.busqueda.contains('ana'));
      expect(s.medicosFiltrados, [pediatra], reason: 'cada palabra cuenta');

      bloc.add(const AgendarBusquedaCambiada('Gómez'));
      s = await hasta(bloc, (s) => s.busqueda == 'Gómez');
      expect(s.medicosFiltrados, isEmpty);
      expect(s.medicosDeLaEspecialidad, hasLength(3));

      // Otra especialidad empieza sin búsqueda.
      bloc.add(const AgendarEspecialidadElegida('Cardiología'));
      s = await hasta(bloc, (s) => s.filtroEspecialidad == 'Cardiología');
      expect(s.busqueda, isEmpty);
      expect(s.medicosFiltrados, [cardiologo]);

      await bloc.close();
    });

    test(
      'cambiar la ciudad o la modalidad vuelve a pedir los próximos turnos '
      'con ese filtro, y la modalidad del filtro se elige al tomar el médico',
      () async {
        final bloc = await abierto();

        var recarga = trasRecargar(bloc, cargandoProximos);
        bloc.add(
          const AgendarFiltrosCambiados(modalidad: TipoCita.telemedicina),
        );
        await recarga;
        expect(
          portal.consultasDeProximos.last.modalidad,
          TipoCita.telemedicina,
        );
        expect(bloc.state.medicosDeLaEspecialidad, [pediatra]);

        recarga = trasRecargar(bloc, cargandoProximos);
        bloc.add(const AgendarFiltrosCambiados(ciudad: 'Quito'));
        await recarga;
        expect(portal.consultasDeProximos.last.ciudad, 'Quito');
        expect(
          portal.consultasDeProximos.last.modalidad,
          TipoCita.telemedicina,
        );
        expect(bloc.state.ciudades, [
          'Quito',
          'Guayaquil',
        ], reason: 'con una ciudad elegida se conservan las opciones');

        // El mismo filtro otra vez no vuelve a pedir nada.
        final consultas = portal.consultasDeProximos.length;
        bloc
          ..add(const AgendarFiltrosCambiados(ciudad: 'Quito'))
          ..add(const AgendarMedicoElegido('ped'));
        await hasta(bloc, (s) => s.medicoId == 'ped' && conTurnos(s));
        expect(portal.consultasDeProximos, hasLength(consultas));
        expect(bloc.state.tipo, TipoCita.telemedicina);
        expect(portal.consultasDeTurnos, ['ped/TELEMEDICINA']);

        recarga = trasRecargar(bloc, cargandoProximos);
        bloc.add(const AgendarFiltrosCambiados(quitarModalidad: true));
        await recarga;
        expect(portal.consultasDeProximos.last.modalidad, isNull);
        expect(portal.consultasDeProximos, hasLength(consultas + 1));

        await bloc.close();
      },
    );

    test('si no cargan los próximos turnos al abrir, se dice y no se enseña '
        'ningún médico', () async {
      portal.errorEnProximos = errorDeRed();

      final bloc = crear()..add(const AgendarIniciado());
      final s = await hasta(bloc, (s) => !s.cargando);

      expect(s.error, 'Sin conexión con el servidor. Revisa tu Internet.');
      expect(s.medicos, isEmpty);
      expect(s.especialidades, isEmpty);

      await bloc.close();
    });

    test('si falla una recarga de próximos turnos, la lista queda vacía con '
        'el error, y reintentar la trae', () async {
      final bloc = await abierto();

      portal.errorEnProximos = errorHttp(500);
      bloc.add(const AgendarFiltrosCambiados(ciudad: 'Quito'));
      var s = await hasta(bloc, (s) => s.errorProximos != null);
      expect(
        s.errorProximos,
        'El servidor tuvo un problema. Intenta en unos minutos.',
      );
      expect(
        s.medicos,
        isEmpty,
        reason: 'nada de datos viejos con otro filtro',
      );

      portal.errorEnProximos = null;
      final recarga = trasRecargar(bloc, cargandoProximos);
      bloc.add(const AgendarProximosReintentados());
      s = await recarga;
      expect(s.medicos, hasLength(3));
      expect(s.errorProximos, isNull);

      await bloc.close();
    });
  });

  group('Rejilla de horarios', () {
    test('al elegir médico propone la modalidad de su próximo turno y pide '
        'sus turnos a la API, una vez', () async {
      final bloc = await abierto();

      bloc.add(const AgendarMedicoElegido('ped'));
      final s = await hasta(bloc, (s) => s.medicoId == 'ped' && conTurnos(s));

      expect(s.paso, PasoAgendar.modalidad);
      expect(s.tipo, TipoCita.presencial);
      expect(portal.consultasDeTurnos, ['ped/PRESENCIAL']);
      expect(
        s.fecha,
        DateTime(2026, 9, 28),
        reason: 'el primer día con turnos',
      );
      expect(s.diasDisponibles, [DateTime(2026, 9, 28), DateTime(2026, 9, 29)]);
      expect(s.estadoDia, EstadoDia.ok);
      expect(horas(s), ['15:30', '19:30']);
      expect(s.grupos[Periodo.manana], isEmpty);
      expect(s.grupos[Periodo.tarde]!.map((h) => h.hora), ['15:30']);
      expect(s.grupos[Periodo.noche]!.map((h) => h.hora), ['19:30']);

      await bloc.close();
    });

    test('la rejilla enseña los turnos tal como llegan, con la duración de '
        'la API y los cortes de la clínica', () async {
      portal
        ..duracionTurnos = 45
        ..turnosDe = (_, _) => [turno(28, 11, 50, 45), turno(28, 12, 10, 45)];

      var bloc = await enLaRejilla('ped', TipoCita.presencial);
      var s = bloc.state;

      // Ni la rejilla de 15 minutos ni el cruce entre ellos: la API manda.
      expect(horas(s), ['11:50', '12:10']);
      expect(s.duracion, 45, reason: 'la de la API, no la de la clínica');
      expect(s.grupos[Periodo.manana]!.single.hora, '11:50');
      expect(s.grupos[Periodo.tarde]!.single.hora, '12:10');
      await bloc.close();

      // Con la tarde desde las 11:00, los dos son de la tarde.
      bloc = await enLaRejilla(
        'ped',
        TipoCita.presencial,
        agenda: {'horaInicioTarde': '11:00'},
      );
      s = bloc.state;
      expect(s.grupos[Periodo.manana], isEmpty);
      expect(s.grupos[Periodo.tarde], hasLength(2));
      await bloc.close();
    });

    test('un turno que ya no cumple la anticipación de la clínica no se '
        'ofrece', () async {
      // Ahora son las 10:00 y la anticipación es de 15 minutos.
      portal.turnosDe = (_, _) => [turno(28, 10, 5), turno(28, 10, 30)];

      final bloc = await enLaRejilla('ped', TipoCita.presencial);
      expect(horas(bloc.state), ['10:30']);

      await bloc.close();
    });

    test('cambiar de modalidad vuelve a pedir los turnos y pasa al primer '
        'día que tenga', () async {
      final bloc = await enLaRejilla('ped', TipoCita.telemedicina);
      final s = bloc.state;

      expect(portal.consultasDeTurnos, ['ped/PRESENCIAL', 'ped/TELEMEDICINA']);
      expect(s.fecha, DateTime(2026, 9, 29), reason: 'hoy no tiene turnos');
      expect(s.duracion, 20);
      expect(horas(s), ['09:00']);

      // Un día sin turnos se dice como tal.
      bloc.add(AgendarFechaElegida(DateTime(2026, 10, 1)));
      final vacio = await hasta(bloc, (s) => s.fecha == DateTime(2026, 10, 1));
      expect(vacio.estadoDia, EstadoDia.diaSinTurnos);
      expect(vacio.huecos, isEmpty);

      await bloc.close();
    });

    test(
      'un médico sin turnos libres en el horizonte se dice como tal',
      () async {
        portal.turnosDe = (_, _) => const [];

        final bloc = await enLaRejilla('ped', TipoCita.presencial);
        expect(bloc.state.estadoDia, EstadoDia.sinTurnos);
        expect(bloc.state.fecha, isNull);
        expect(bloc.state.diasDisponibles, isEmpty);

        await bloc.close();
      },
    );

    test('sin red, los turnos no se inventan: error y reintentar', () async {
      portal.errorEnTurnos = errorDeRed();

      final bloc = await abierto();
      bloc.add(const AgendarMedicoElegido('ped'));
      var s = await hasta(bloc, (s) => s.errorTurnos != null);

      expect(s.estadoDia, EstadoDia.error);
      expect(
        s.errorTurnos,
        'Sin conexión con el servidor. Revisa tu Internet.',
      );
      expect(s.huecos, isEmpty);

      portal.errorEnTurnos = null;
      bloc.add(const AgendarTurnosReintentados());
      s = await hasta(bloc, conTurnos);
      expect(s.estadoDia, EstadoDia.ok);
      expect(portal.consultasDeTurnos, ['ped/PRESENCIAL', 'ped/PRESENCIAL']);

      await bloc.close();
    });
  });

  group('Agendar', () {
    test(
      'el recorrido completo, para un dependiente, hasta confirmar',
      () async {
        final bloc = await abierto();

        // Paso 1: para Tomás.
        bloc
          ..add(const AgendarParaElegido('dep1'))
          ..add(const AgendarContinuado());
        await hasta(bloc, (s) => s.paso == PasoAgendar.filtros);
        expect(bloc.state.pacienteNombre, 'Tomás Pérez');

        // Paso 2: la especialidad lleva a sus médicos.
        bloc.add(const AgendarEspecialidadElegida('Pediatría'));
        await hasta(bloc, (s) => s.paso == PasoAgendar.medico);

        // Paso 3 y 4: médico y modalidad (solo las que ofrece).
        bloc.add(const AgendarMedicoElegido('ped'));
        await hasta(
          bloc,
          (s) => s.paso == PasoAgendar.modalidad && conTurnos(s),
        );
        expect(bloc.state.modalidadesMedico, [
          TipoCita.presencial,
          TipoCita.telemedicina,
        ]);

        bloc
          ..add(const AgendarModalidadElegida(TipoCita.asincrona))
          ..add(const AgendarModalidadElegida(TipoCita.telemedicina));
        await hasta(
          bloc,
          (s) =>
              s.paso == PasoAgendar.horario &&
              s.tipo == TipoCita.telemedicina &&
              conTurnos(s),
        );
        expect(portal.consultasDeTurnos, [
          'ped/PRESENCIAL',
          'ped/TELEMEDICINA',
        ], reason: 'una modalidad que el médico no ofrece se ignora');

        // Paso 5: la hora. Sin hora elegida no se puede seguir, y una hora que
        // no está entre los turnos no se puede elegir.
        final s = bloc.state;
        expect(s.estadoDia, EstadoDia.ok);
        expect(AgendarBloc.pasoCompleto(s), isFalse);

        bloc
          ..add(
            AgendarHuecoElegido(Hueco.deTurno(turno(29, 9, 5, 20), s.reglas)),
          )
          ..add(AgendarHuecoElegido(s.huecos.single))
          ..add(const AgendarContinuado());
        await hasta(bloc, (s) => s.paso == PasoAgendar.motivo);
        expect(bloc.state.hueco?.hora, '09:00');

        // Paso 6: el motivo es obligatorio.
        expect(AgendarBloc.pasoCompleto(bloc.state), isFalse);
        bloc
          ..add(const AgendarMotivoCambiado('Dolor de oído desde ayer'))
          ..add(const AgendarContinuado());
        await hasta(bloc, (s) => s.paso == PasoAgendar.resumen);
        expect(bloc.state.listo, isTrue);

        // Paso 7: confirmar.
        bloc.add(const AgendarConfirmado());
        final listo = await hasta(bloc, (s) => s.paso == PasoAgendar.listo);

        expect(portal.agendadas.single.aJson(), {
          'doctorId': 'ped',
          'start': '2026-09-29T09:00:00',
          'end': '2026-09-29T09:20:00',
          'type': 'TELEMEDICINA',
          'reason': 'Dolor de oído desde ayer',
          'pacienteId': 'dep1',
        });
        expect(listo.agendada?.medico, 'Ana Pérez');
        expect(listo.agendada?.paraDependiente, isTrue);
        expect(listo.agendada?.pacienteNombre, 'Tomás Pérez');

        await bloc.close();
      },
    );

    test('«El primer turno disponible» deja elegidos médico, modalidad y '
        'turno, y pasa al motivo', () async {
      final bloc = await abierto();
      bloc.add(const AgendarEspecialidadElegida('Pediatría'));
      final enMedicos = await hasta(bloc, (s) => s.paso == PasoAgendar.medico);

      bloc.add(AgendarPrimerTurnoElegido(enMedicos.primerTurno!.turno));
      final s = await hasta(bloc, (s) => s.paso == PasoAgendar.motivo);

      expect(s.medico, pediatra);
      expect(s.tipo, TipoCita.presencial);
      expect(s.fecha, DateTime(2026, 9, 28));
      expect(s.huecoValido?.inicio, hoy1530.inicio);
      expect(portal.consultasDeTurnos, [
        'ped/PRESENCIAL',
      ], reason: 'el turno se confirma contra la API antes de seguir');
      expect(portal.citasExcluidas, [
        null,
      ], reason: 'al agendar no hay cita que excluir');
      expect(AgendarBloc.pasoAnterior(s), PasoAgendar.horario);

      bloc
        ..add(const AgendarMotivoCambiado('Control'))
        ..add(const AgendarContinuado());
      await hasta(bloc, (s) => s.paso == PasoAgendar.resumen);
      bloc.add(const AgendarConfirmado());
      await hasta(bloc, (s) => s.paso == PasoAgendar.listo);

      expect(portal.agendadas.single.aJson()['start'], '2026-09-28T15:30:00');
      expect(portal.agendadas.single.aJson()['type'], 'PRESENCIAL');

      await bloc.close();
    });

    test('si el primer turno se ocupó entretanto, se va a la rejilla '
        'actualizada, sin él', () async {
      final bloc = await abierto();
      bloc.add(const AgendarEspecialidadElegida('Pediatría'));
      final enMedicos = await hasta(bloc, (s) => s.paso == PasoAgendar.medico);

      // La API ya no lo trae.
      portal.turnosDe = (doctor, modalidad) => [
        for (final t in turnosDeLaApi(doctor, modalidad))
          if (t != hoy1530) t,
      ];

      bloc.add(AgendarPrimerTurnoElegido(enMedicos.primerTurno!.turno));
      final s = await hasta(bloc, (s) => s.paso == PasoAgendar.horario);

      expect(s.aviso, avisoHorarioTomado);
      expect(s.hueco, isNull);
      expect(s.medicoId, 'ped');
      expect(horas(s), ['19:30']);

      await bloc.close();
    });

    test('409 al agendar: el mensaje del servidor, los turnos y los próximos '
        'turnos recargados, las elecciones conservadas y de vuelta a la hora '
        'sin ese turno', () async {
      const mensaje = 'Ese horario acaba de ocuparse. Elige otro, por favor.';
      portal.errorAlAgendar = errorHttp(409, mensaje);

      final bloc = await abierto();
      bloc
        ..add(const AgendarParaElegido('dep1'))
        ..add(const AgendarContinuado())
        ..add(const AgendarEspecialidadElegida('Pediatría'))
        ..add(const AgendarMedicoElegido('ped'));
      await hasta(bloc, (s) => s.medicoId == 'ped' && conTurnos(s));
      bloc.add(const AgendarModalidadElegida(TipoCita.presencial));
      await hasta(bloc, (s) => s.paso == PasoAgendar.horario);

      final elegido = bloc.state.huecos.firstWhere((h) => h.hora == '15:30');
      bloc
        ..add(AgendarHuecoElegido(elegido))
        ..add(const AgendarContinuado())
        ..add(const AgendarMotivoCambiado('Fiebre desde anoche'))
        ..add(const AgendarContinuado());
      await hasta(bloc, (s) => s.paso == PasoAgendar.resumen);

      final turnosAntes = portal.consultasDeTurnos.length;
      final proximosAntes = portal.consultasDeProximos.length;

      // Otro paciente lo tomó: los próximos turnos ya no lo traen. La
      // rejilla de la API lo sigue trayendo (por ejemplo, porque el choque
      // es con otra cita del propio paciente) y aun así no se ofrece.
      portal.medicosDisponibles = [
        MedicoPortal(
          uid: 'ped',
          nombre: 'Ana Pérez',
          especialidad: 'Pediatría',
          modalidades: const [TipoCita.presencial, TipoCita.telemedicina],
          proximo: proximo(hoy1930, TipoCita.presencial),
        ),
        pediatra2,
        cardiologo,
      ];

      bloc.add(const AgendarConfirmado());
      final s = await hasta(bloc, (s) => s.aviso != null);

      expect(s.paso, PasoAgendar.horario);
      expect(s.aviso, mensaje, reason: 'el mensaje del servidor');
      expect(s.errorGuardar, mensaje);
      expect(s.guardando, isFalse);
      expect(portal.consultasDeTurnos, hasLength(turnosAntes + 1));
      expect(portal.consultasDeProximos, hasLength(proximosAntes + 1));
      expect(s.medicos.first.proximo?.inicio, hoy1930.inicio);

      // Se conserva todo lo demás.
      expect(s.para, 'dep1');
      expect(s.filtroEspecialidad, 'Pediatría');
      expect(s.medicoId, 'ped');
      expect(s.tipo, TipoCita.presencial);
      expect(s.motivo, 'Fiebre desde anoche');
      expect(s.fecha, DateTime(2026, 9, 28));

      // Sin el turno tomado.
      expect(s.hueco, isNull);
      expect(horas(s), ['19:30']);

      // Con otro turno, se agenda sin volver a escribir nada.
      portal.errorAlAgendar = null;
      bloc
        ..add(AgendarHuecoElegido(s.huecos.single))
        ..add(const AgendarContinuado());
      await hasta(bloc, (s) => s.paso == PasoAgendar.motivo);
      bloc.add(const AgendarContinuado());
      await hasta(bloc, (s) => s.paso == PasoAgendar.resumen);
      expect(bloc.state.errorGuardar, isNull);
      bloc.add(const AgendarConfirmado());
      await hasta(bloc, (s) => s.paso == PasoAgendar.listo);

      expect(portal.agendadas.single.aJson(), {
        'doctorId': 'ped',
        'start': '2026-09-28T19:30:00',
        'end': '2026-09-28T20:00:00',
        'type': 'PRESENCIAL',
        'reason': 'Fiebre desde anoche',
        'pacienteId': 'dep1',
      });

      await bloc.close();
    });

    test('sin red al confirmar se queda en el resumen con el mensaje, sin '
        'recargar nada', () async {
      portal.errorAlAgendar = errorDeRed();

      final bloc = await enLaRejilla('ped', TipoCita.presencial);
      bloc
        ..add(AgendarHuecoElegido(bloc.state.huecos.first))
        ..add(const AgendarContinuado())
        ..add(const AgendarMotivoCambiado('Control'))
        ..add(const AgendarContinuado());
      await hasta(bloc, (s) => s.paso == PasoAgendar.resumen);
      final consultas = portal.consultasDeTurnos.length;

      bloc.add(const AgendarConfirmado());
      final s = await hasta(bloc, (s) => s.errorGuardar != null);

      expect(s.paso, PasoAgendar.resumen);
      expect(
        s.errorGuardar,
        'Sin conexión con el servidor. Revisa tu Internet.',
      );
      expect(s.huecoValido?.hora, '15:30');
      expect(portal.consultasDeTurnos, hasLength(consultas));

      await bloc.close();
    });

    test('agendar otra cita vuelve a pedir los próximos turnos', () async {
      final bloc = await enLaRejilla('ped', TipoCita.presencial);
      bloc
        ..add(AgendarHuecoElegido(bloc.state.huecos.first))
        ..add(const AgendarContinuado())
        ..add(const AgendarMotivoCambiado('Control'))
        ..add(const AgendarContinuado());
      await hasta(bloc, (s) => s.paso == PasoAgendar.resumen);
      bloc.add(const AgendarConfirmado());
      await hasta(bloc, (s) => s.paso == PasoAgendar.listo);
      final consultas = portal.consultasDeProximos.length;

      final recarga = trasRecargar(bloc, cargandoProximos);
      bloc.add(const AgendarOtraCita());
      final s = await recarga;

      expect(portal.consultasDeProximos, hasLength(consultas + 1));
      expect(s.medico, isNull);
      expect(s.motivo, isEmpty);

      await bloc.close();
    });
  });

  group('Reprogramar', () {
    final original = Cita(
      id: 'c9',
      inicio: DateTime(2026, 9, 29, 9),
      fin: DateTime(2026, 9, 29, 9, 30),
      tipo: TipoCita.presencial,
      estado: EstadoCita.programada,
      doctorId: 'ped',
      medico: 'Ana Pérez',
      especialidad: 'Pediatría',
      pacienteNombre: 'Ana María Pérez',
    );

    Future<AgendarBloc> reprogramando() async {
      final bloc = crear()..add(AgendarIniciado(reprogramar: original));
      await hasta(bloc, (s) => !s.cargando && conTurnos(s));
      return bloc;
    }

    test('entra directo a la hora, con el mismo médico y modalidad y los '
        'turnos de la API sin contar la propia cita', () async {
      // Con `excluirCita`, la API ofrece el horario de la propia cita.
      portal.liberadosAlExcluir = (cita) =>
          cita == 'c9' ? [turno(29, 9, 0)] : const [];

      final bloc = await reprogramando();
      final s = bloc.state;

      expect(s.paso, PasoAgendar.horario);
      expect(s.primerPaso, PasoAgendar.horario);
      expect(s.medicoId, 'ped');
      expect(s.medico?.nombre, 'Ana Pérez');
      expect(s.tipo, TipoCita.presencial);
      expect(s.fecha, DateTime(2026, 9, 29), reason: 'el día de la cita');
      expect(portal.consultasDeTurnos, ['ped/PRESENCIAL']);
      expect(portal.citasExcluidas, ['c9'], reason: 'se pide sin la cita');
      expect(horas(s), ['08:00', '09:00', '13:00']);
      expect(
        portal.consultasDeProximos,
        isEmpty,
        reason: 'al reprogramar no se elige médico',
      );
      expect(AgendarBloc.pasoAnterior(s), isNull, reason: 'atrás es salir');

      // El médico no se puede cambiar al reprogramar.
      bloc.add(const AgendarMedicoElegido('car'));
      bloc.add(AgendarHuecoElegido(s.huecos.last));
      await hasta(bloc, (s) => s.hueco != null);
      expect(bloc.state.medicoId, 'ped');

      bloc.add(const AgendarContinuado());
      await hasta(bloc, (s) => s.paso == PasoAgendar.resumen);
      expect(bloc.state.listo, isTrue, reason: 'no se pide motivo');

      bloc.add(const AgendarConfirmado());
      final listo = await hasta(bloc, (s) => s.paso == PasoAgendar.listo);

      expect(portal.reprogramadas, ['c9']);
      expect(listo.agendada?.inicio, DateTime(2026, 9, 29, 13));
      expect(listo.agendada?.medico, 'Ana Pérez');

      await bloc.close();
    });

    test('si el día de la cita ya no tiene turnos, empieza en el primero que '
        'tenga', () async {
      portal.turnosDe = (_, _) => [turno(30, 11, 0)];

      final bloc = await reprogramando();
      expect(bloc.state.fecha, DateTime(2026, 9, 30));
      expect(horas(bloc.state), ['11:00']);

      await bloc.close();
    });

    test(
      '409 al reprogramar: el mensaje del servidor y de vuelta a la hora con '
      'los turnos recargados y sin el tomado',
      () async {
        const mensaje = 'Horario no disponible: elige otro, por favor.';
        portal.errorAlReprogramar = errorHttp(409, mensaje);

        final bloc = await reprogramando();
        bloc
          ..add(AgendarHuecoElegido(bloc.state.huecos.first))
          ..add(const AgendarContinuado());
        await hasta(bloc, (s) => s.paso == PasoAgendar.resumen);

        bloc.add(const AgendarConfirmado());
        final s = await hasta(bloc, (s) => s.aviso != null);

        expect(s.paso, PasoAgendar.horario);
        expect(s.aviso, mensaje);
        expect(portal.consultasDeTurnos, hasLength(2));
        expect(portal.citasExcluidas, [
          'c9',
          'c9',
        ], reason: 'la recarga también excluye la cita que se mueve');
        expect(s.original, original);
        expect(s.medicoId, 'ped');
        expect(s.tipo, TipoCita.presencial);
        expect(s.hueco, isNull);
        expect(horas(s), ['13:00'], reason: 'sin el 08:00 que se rechazó');
        expect(portal.reprogramadas, isEmpty);

        await bloc.close();
      },
    );

    test('con un médico que ya no atiende por el portal, el mensaje del '
        'servidor y nada que reintentar', () async {
      portal.errorEnTurnos = errorHttp(
        404,
        'El médico no está disponible en el portal.',
      );

      final bloc = crear()..add(AgendarIniciado(reprogramar: original));
      final s = await hasta(bloc, (s) => s.error != null);

      expect(
        s.error,
        'El médico no está disponible en el portal. Puedes cancelarla y '
        'agendar con otro médico.',
      );

      await bloc.close();
    });
  });

  test('la duración que se enseña antes de pedir los turnos es la del médico '
      'o la de la clínica', () async {
    final conDuracion = MedicoPortal(
      uid: 'x',
      nombre: 'X',
      configAgenda: const ConfigAgenda(duraciones: {'PRESENCIAL': 40}),
    );

    expect(duracionDe(conDuracion, TipoCita.presencial, reglasDePrueba()), 40);
    expect(
      duracionDe(conDuracion, TipoCita.telemedicina, reglasDePrueba()),
      20,
    );
  });
}
