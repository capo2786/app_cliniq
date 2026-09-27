// test/pasos_agendar_test.dart

import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/agendar/data/models/medico_portal.dart';
import 'package:app_cliniq/features/agendar/data/models/turnos.dart';
import 'package:app_cliniq/features/agendar/presentacion/pasos/paso_filtros.dart';
import 'package:app_cliniq/features/agendar/presentacion/pasos/paso_horario.dart';
import 'package:app_cliniq/features/agendar/presentacion/pasos/paso_medico.dart';
import 'package:app_cliniq/features/agendar/presentacion/pasos/paso_resumen.dart';
import 'package:app_cliniq/features/agendar/providers/agendar_bloc.dart';
import 'package:app_cliniq/features/agendar/providers/agendar_event.dart';
import 'package:app_cliniq/features/agendar/providers/agendar_state.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dobles.dart';

/// Los pasos de especialidad, médico y horario, pintados con un bloc de
/// verdad y un portal falso que hace de API.
///
/// El reloj está fijo en el lunes 28 de septiembre de 2026 a las 10:00 de
/// la clínica: «hoy» es el 28 y «mañana» el 29.
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

  final ana = MedicoPortal(
    uid: 'ped',
    nombre: 'Ana Pérez',
    especialidad: 'Pediatría',
    ciudad: 'Quito',
    modalidades: const [TipoCita.presencial, TipoCita.telemedicina],
    proximo: proximo(hoy1530, TipoCita.presencial),
  );

  final marta = MedicoPortal(
    uid: 'ped2',
    nombre: 'Marta Núñez',
    especialidad: 'Pediatría',
    ciudad: 'Quito',
    modalidades: const [TipoCita.presencial],
    proximo: proximo(turno(29, 8, 0), TipoCita.presencial),
  );

  final luis = MedicoPortal(
    uid: 'car',
    nombre: 'Luis Mora',
    especialidad: 'Cardiología',
    ciudad: 'Guayaquil',
    modalidades: const [TipoCita.asincrona],
    proximo: proximo(turno(29, 9, 0, 15), TipoCita.asincrona),
  );

  late PortalFalso portal;

  setUp(() {
    portal = PortalFalso(
      medicosDisponibles: [ana, marta, luis],
      especialidadesDisponibles: [
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
      ],
      turnosDe: (doctor, modalidad) => doctor == 'ped'
          ? [turno(28, 11, 45), hoy1530, turno(28, 19, 30), turno(29, 8, 0)]
          : const [],
    );
  });

  /// Pinta el paso en que esté el bloc. Los demás pasos, que no se prueban
  /// aquí, se pintan solo con su título.
  Widget pasoDe(AgendarState s) => switch (s.paso) {
    PasoAgendar.filtros => PasoFiltros(state: s),
    PasoAgendar.medico => PasoMedico(state: s),
    PasoAgendar.horario => PasoHorario(state: s),
    PasoAgendar.resumen => PasoResumen(state: s),
    _ => Text('Paso: ${s.paso.titulo}'),
  };

  /// Da vueltas al bucle de eventos hasta que se cumpla la condición: las
  /// respuestas del portal falso llegan sin esperas.
  Future<void> hastaQue(WidgetTester tester, bool Function() condicion) async {
    for (var i = 0; i < 20 && !condicion(); i++) {
      await tester.pump();
    }
    expect(condicion(), isTrue, reason: 'la condición no llegó a cumplirse');
  }

  Future<AgendarBloc> montar(WidgetTester tester, {Cita? reprogramar}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final bloc = AgendarBloc(
      portal: portal,
      dependientes: DependientesFalso(),
      uid: 'u1',
      nombreTitular: 'Ana María Pérez',
      reglas: reglasDePrueba(),
      ciudades: catalogosDePrueba().ciudades,
      puedeDependientes: false,
      reloj: reloj,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      conDatosDeLaClinica(
        MaterialApp(
          theme: temaCliniq(),
          home: BlocProvider.value(
            value: bloc,
            child: Scaffold(
              body: BlocBuilder<AgendarBloc, AgendarState>(
                builder: (context, s) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [pasoDe(s)],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    bloc.add(AgendarIniciado(reprogramar: reprogramar));
    await hastaQue(tester, () => !bloc.state.cargando);
    await tester.pump();

    return bloc;
  }

  Future<void> tocar(WidgetTester tester, Finder objetivo) async {
    await tester.ensureVisible(objetivo);
    await tester.pump();
    await tester.tap(objetivo);
    await tester.pump();
  }

  /// Lleva el bloc a la rejilla de Ana, presencial.
  Future<AgendarBloc> enLaRejilla(WidgetTester tester) async {
    final bloc = await montar(tester);
    bloc
      ..add(const AgendarEspecialidadElegida('Pediatría'))
      ..add(const AgendarMedicoElegido('ped'));
    await hastaQue(tester, () => bloc.state.turnosActuales != null);
    bloc.add(const AgendarModalidadElegida(TipoCita.presencial));
    await hastaQue(tester, () => bloc.state.paso == PasoAgendar.horario);
    await tester.pump();
    return bloc;
  }

  group('Especialidades', () {
    testWidgets('cada una dice cuántos médicos tiene y cuándo es su próximo '
        'turno, con palabras naturales', (tester) async {
      await montar(tester);

      expect(find.text('Todas las especialidades'), findsOneWidget);
      expect(
        find.text('3 médicos · próximo turno hoy a las 15:30'),
        findsOneWidget,
      );
      expect(find.text('Pediatría'), findsOneWidget);
      expect(
        find.text('2 médicos · próximo turno hoy a las 15:30'),
        findsOneWidget,
      );
      expect(find.text('Cardiología'), findsOneWidget);
      expect(
        find.text('1 médico · próximo turno mañana a las 09:00'),
        findsOneWidget,
      );
      // Dos ciudades con médicos: se puede filtrar por ciudad.
      expect(find.text('Cualquier ciudad'), findsOneWidget);
    });

    testWidgets('tocar una especialidad pasa a sus médicos', (tester) async {
      final bloc = await montar(tester);

      await tocar(tester, find.text('Cardiología'));

      expect(bloc.state.paso, PasoAgendar.medico);
      expect(bloc.state.filtroEspecialidad, 'Cardiología');
      expect(find.text('EL PRIMER TURNO DISPONIBLE'), findsOneWidget);
      expect(find.text('Luis Mora · Cardiología'), findsOneWidget);
    });

    testWidgets('sin turnos disponibles lo dice y, con filtros, ofrece '
        'quitarlos', (tester) async {
      portal
        ..medicosDisponibles = const []
        ..especialidadesDisponibles = const [];
      await montar(tester);

      expect(find.text('Sin turnos disponibles'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);

      await tocar(tester, find.text('Telemedicina'));
      await hastaQue(tester, () => portal.consultasDeProximos.length == 2);
      await tester.pump();
      expect(portal.consultasDeProximos.last.modalidad, TipoCita.telemedicina);

      await tocar(tester, find.text('Quitar filtros'));
      await hastaQue(tester, () => portal.consultasDeProximos.length == 3);
      expect(portal.consultasDeProximos.last.modalidad, isNull);
    });

    testWidgets('si no se pudieron pedir, el error con «Reintentar» y '
        'ninguna lista', (tester) async {
      final bloc = await montar(tester);

      portal.errorEnProximos = errorDeRed();
      await tocar(tester, find.text('Telemedicina'));
      await hastaQue(tester, () => bloc.state.errorProximos != null);
      await tester.pump();

      expect(
        find.text('Sin conexión con el servidor. Revisa tu Internet.'),
        findsOneWidget,
      );
      expect(find.text('Pediatría'), findsNothing);

      portal.errorEnProximos = null;
      await tocar(tester, find.text('Reintentar'));
      await hastaQue(tester, () => bloc.state.medicos.isNotEmpty);
      await tester.pump();
      expect(find.text('Pediatría'), findsOneWidget);
    });
  });

  group('Médicos', () {
    testWidgets('arriba el primer turno disponible, y cada médico con su '
        'próximo turno', (tester) async {
      await montar(tester);
      await tocar(tester, find.text('Pediatría'));

      expect(
        find.text('Pediatría · 2 médicos con turnos libres'),
        findsOneWidget,
      );
      expect(find.text('Hoy a las 15:30'), findsOneWidget);
      expect(find.text('Lunes 28 de septiembre'), findsOneWidget);
      expect(find.text('Ana Pérez · Pediatría'), findsOneWidget);
      expect(
        find.text('Próximo turno: hoy a las 15:30 · Presencial'),
        findsOneWidget,
        reason: 'con dos modalidades, dice en cuál',
      );
      expect(find.text('Próximo turno: mañana a las 08:00'), findsOneWidget);
      expect(find.text('Luis Mora'), findsNothing);
    });

    testWidgets('el primer turno disponible, con un toque, deja elegido el '
        'turno y pasa al motivo', (tester) async {
      final bloc = await montar(tester);
      await tocar(tester, find.text('Pediatría'));

      await tocar(tester, find.byKey(const Key('primer-turno')));
      await hastaQue(tester, () => bloc.state.paso == PasoAgendar.motivo);

      expect(bloc.state.medicoId, 'ped');
      expect(bloc.state.huecoValido?.inicio, hoy1530.inicio);
      expect(find.text('Paso: Motivo de la consulta'), findsOneWidget);
    });

    testWidgets('el buscador filtra por nombre, busca con la tecla del '
        'teclado y la cierra', (tester) async {
      final bloc = await montar(tester);
      await tocar(tester, find.text('Todas las especialidades'));

      final campo = find.byKey(const Key('buscar-medico'));
      expect(
        tester.widget<TextField>(campo).textInputAction,
        TextInputAction.search,
      );

      await tester.tap(campo);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(campo, 'nunez');
      await tester.pump();
      expect(find.text('Marta Núñez'), findsOneWidget);
      expect(find.text('Luis Mora'), findsNothing);
      expect(
        find.byKey(const Key('primer-turno')),
        findsNothing,
        reason: 'buscando a alguien, la tarjeta de otro estorba',
      );

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
      );

      await tester.enterText(campo, 'Gómez');
      await tester.pump();
      expect(find.text('Ningún médico se llama así'), findsOneWidget);

      await tocar(tester, find.text('Borrar búsqueda').last);
      expect(bloc.state.busqueda, isEmpty);
      expect(tester.widget<TextField>(campo).controller?.text, isEmpty);
      expect(find.text('Luis Mora'), findsOneWidget);
    });
  });

  group('Horario', () {
    testWidgets('la rejilla agrupa los turnos de la API en mañana, tarde y '
        'noche, y la tira solo trae los días con turnos', (tester) async {
      final bloc = await enLaRejilla(tester);

      expect(find.text('3 horarios libres'), findsOneWidget);
      expect(find.text('MAÑANA'), findsOneWidget);
      expect(find.text('TARDE'), findsOneWidget);
      expect(find.text('NOCHE'), findsOneWidget);
      expect(find.text('11:45'), findsOneWidget);
      expect(find.text('15:30'), findsOneWidget);
      expect(find.text('19:30'), findsOneWidget);
      expect(find.text('Presencial · 30 min'), findsOneWidget);

      // La tira: hoy y mañana, que son los días con turnos.
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('29'), findsOneWidget);
      expect(find.text('30'), findsNothing);

      await tocar(tester, find.text('19:30'));
      expect(bloc.state.hueco?.hora, '19:30');

      await tocar(tester, find.text('29'));
      expect(find.text('1 horario libre'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('TARDE'), findsNothing);
    });

    testWidgets('un día sin turnos y un médico sin turnos se dicen como '
        'tales', (tester) async {
      final bloc = await enLaRejilla(tester);

      bloc.add(AgendarFechaElegida(DateTime(2026, 10, 1)));
      await hastaQue(tester, () => bloc.state.fecha == DateTime(2026, 10, 1));
      await tester.pump();
      expect(find.text('No quedan turnos libres'), findsOneWidget);

      await tocar(tester, find.text('Ver el siguiente día'));
      expect(bloc.state.fecha, DateTime(2026, 9, 28));

      portal.turnosDe = (_, _) => const [];
      bloc.add(const AgendarTurnosReintentados());
      await hastaQue(tester, () => bloc.state.estadoDia == EstadoDia.sinTurnos);
      await tester.pump();
      expect(find.text('Sin turnos libres'), findsOneWidget);
      expect(find.text('Elegir otro médico'), findsOneWidget);
    });

    testWidgets('sin red, dice que no pudo y ofrece reintentar', (
      tester,
    ) async {
      final bloc = await enLaRejilla(tester);

      portal.errorEnTurnos = errorDeRed();
      bloc.add(const AgendarTurnosReintentados());
      await hastaQue(tester, () => bloc.state.errorTurnos != null);
      await tester.pump();
      expect(
        find.text('Sin conexión con el servidor. Revisa tu Internet.'),
        findsOneWidget,
      );
      expect(find.text('15:30'), findsNothing);

      portal.errorEnTurnos = null;
      await tocar(tester, find.text('Reintentar'));
      await hastaQue(tester, () => bloc.state.estadoDia == EstadoDia.ok);
      await tester.pump();
      expect(find.text('15:30'), findsOneWidget);
    });

    testWidgets('tras un 409 enseña el mensaje del servidor y ya no ofrece '
        'ese turno', (tester) async {
      const mensaje = 'Ese horario acaba de ocuparse. Elige otro, por favor.';
      portal.errorAlAgendar = errorHttp(409, mensaje);
      final bloc = await enLaRejilla(tester);

      await tocar(tester, find.text('15:30'));
      bloc
        ..add(const AgendarContinuado())
        ..add(const AgendarMotivoCambiado('Control'))
        ..add(const AgendarContinuado())
        ..add(const AgendarConfirmado());
      await hastaQue(tester, () => bloc.state.aviso != null);
      await tester.pump();

      expect(bloc.state.paso, PasoAgendar.horario);
      expect(find.text(mensaje), findsOneWidget, reason: 'una sola vez');
      expect(find.textContaining('inesperado'), findsNothing);
      expect(find.text('15:30'), findsNothing);
      expect(find.text('11:45'), findsOneWidget);
    });

    testWidgets('otro error que explica el servidor sale una sola vez, en '
        'el resumen', (tester) async {
      const mensaje = 'El motivo de consulta es demasiado corto.';
      portal.errorAlAgendar = errorHttp(400, mensaje);
      final bloc = await enLaRejilla(tester);

      await tocar(tester, find.text('15:30'));
      bloc
        ..add(const AgendarContinuado())
        ..add(const AgendarMotivoCambiado('Dolor'))
        ..add(const AgendarContinuado())
        ..add(const AgendarConfirmado());
      await hastaQue(
        tester,
        () => bloc.state.errorGuardar != null && !bloc.state.cargandoTurnos,
      );
      await tester.pump();

      expect(bloc.state.paso, PasoAgendar.resumen);
      expect(find.text(mensaje), findsOneWidget);
      expect(find.textContaining('inesperado'), findsNothing);
    });

    testWidgets('al reprogramar, con la cita de ahora y sin ofrecer otro '
        'médico cuando no hay turnos', (tester) async {
      portal.turnosDe = (_, _) => const [];
      await montar(
        tester,
        reprogramar: Cita(
          id: 'c9',
          inicio: DateTime(2026, 9, 29, 9),
          fin: DateTime(2026, 9, 29, 9, 30),
          tipo: TipoCita.presencial,
          estado: EstadoCita.programada,
          doctorId: 'ped',
          medico: 'Ana Pérez',
        ),
      );
      await tester.pump();

      expect(
        find.textContaining('Hoy está agendada el Martes 29 de septiembre'),
        findsOneWidget,
      );
      expect(find.text('Sin turnos libres'), findsOneWidget);
      expect(find.text('Elegir otro médico'), findsNothing);
      expect(portal.citasExcluidas, ['c9']);
    });
  });
}
