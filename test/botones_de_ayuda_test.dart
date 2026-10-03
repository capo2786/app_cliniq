// test/botones_de_ayuda_test.dart

import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/ayuda/data/ayuda_contextual_service.dart';
import 'package:app_cliniq/features/ayuda/data/ayuda_service.dart';
import 'package:app_cliniq/features/ayuda/data/models/ayuda_de_accion.dart';
import 'package:app_cliniq/features/ayuda/presentacion/centro_ayuda_page.dart';
import 'package:app_cliniq/features/ayuda/presentacion/widgets/boton_ayuda.dart';
import 'package:app_cliniq/features/ayuda/providers/ayuda_contextual_cubit.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/citas/presentacion/widgets/detalle_cita.dart';
import 'package:app_cliniq/features/mi_salud/data/mi_salud_service.dart';
import 'package:app_cliniq/features/mi_salud/presentacion/certificado_page.dart';
import 'package:app_cliniq/features/mi_salud/presentacion/mi_salud_page.dart';
import 'package:app_cliniq/features/mi_salud/presentacion/orden_page.dart';
import 'package:app_cliniq/features/mi_salud/presentacion/receta_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/ayuda.dart';
import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/mi_salud.dart';
import 'dobles/pantalla.dart';
import 'dobles/tablero.dart';

/// Las claves de los botones de ayuda de la aplicación, exactas, como las
/// siembra el servidor para el rol PACIENTE (contrato de ayuda).
const List<String> clavesDeLaApp = [
  'app.inicio',
  'app.agendar',
  'app.agendar.primerTurno',
  'app.agendar.modalidad',
  'app.misCitas',
  'app.misCitas.reprogramar',
  'app.misCitas.cancelar',
  'app.videoconsulta',
  'app.consultas',
  'app.consultas.nueva',
  'app.miSalud',
  'app.miSalud.receta',
  'app.miSalud.orden',
  'app.miSalud.certificado',
  'app.dependientes',
  'app.perfil',
  'app.arco',
  'app.soporte',
  'app.avisos',
  'app.ayuda',
];

/// Cada pantalla lleva el «?» de su clave, con el texto que mande el
/// servidor; el tablero carga los textos una vez por sesión.
void main() {
  setUpAll(() => ZonaClinica.aplicar('America/Guayaquil'));
  setUp(sondeoConRed);

  final textos = {
    for (final clave in clavesDeLaApp)
      clave: AyudaDeAccion(titulo: 'Ayuda de $clave', texto: 'Qué hace.'),
  };

  Finder boton(String clave) => find.byKey(Key('ayuda-$clave'));

  testWidgets('el tablero pide los textos una vez y el inicio lleva su «?»', (
    tester,
  ) async {
    final api = DioGrabador({
      'GET /menus/mi-menu': (_) => menuJson(),
      'GET /ayuda/contextual': (_) => {
        'app.inicio': {'titulo': 'Tu inicio', 'texto': 'Lo de hoy.'},
      },
    });

    await montarTablero(tester, dio: api.dio, cache: CacheEnMemoria());
    await tester.pumpAndSettle();

    expect(boton('app.inicio'), findsOneWidget);
    expect(find.byTooltip('Ayuda: Tu inicio'), findsOneWidget);

    // Al volver a la aplicación se pone al día lo demás, pero los textos
    // ya están: no se vuelven a pedir.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(api.claves.where((c) => c == 'GET /ayuda/contextual'), hasLength(1));
  });

  testWidgets('sin textos del servidor, el inicio no lleva «?»', (
    tester,
  ) async {
    final api = DioGrabador({'GET /menus/mi-menu': (_) => menuJson()});

    await montarTablero(tester, dio: api.dio, cache: CacheEnMemoria());
    await tester.pumpAndSettle();

    expect(api.claves, contains('GET /ayuda/contextual'));
    expect(find.byIcon(Icons.help_outline_rounded), findsNothing);
  });

  group('Mi salud', () {
    late CacheLocal cache;
    late DioGrabador api;

    setUp(() {
      cache = CacheEnMemoria();
      api = DioGrabador({
        'GET /portal/mi-salud': (_) => miSaludJson(),
        'GET /portal/recetas/r1': (_) => recetaJson(),
        'GET /portal/ordenes/o1': (_) => ordenJson(),
        'GET /portal/certificados/c1': (_) => certificadoJson(),
      });
    });

    MiSaludService servicio() => MiSaludService(api.dio, cache);

    testWidgets('la pantalla y cada documento, con su clave', (tester) async {
      Future<void> montar(Widget pagina) async {
        await montarPantalla(tester, pagina, ayuda: textos);
        await tester.pumpAndSettle();
      }

      await montar(
        MiSaludPage(servicio: servicio(), dependientes: DependientesFalso()),
      );
      expect(boton('app.miSalud'), findsOneWidget);

      await montar(RecetaPage(id: 'r1', servicio: servicio()));
      expect(boton('app.miSalud.receta'), findsOneWidget);

      await montar(OrdenPage(id: 'o1', servicio: servicio()));
      expect(boton('app.miSalud.orden'), findsOneWidget);

      await montar(CertificadoPage(id: 'c1', servicio: servicio()));
      expect(boton('app.miSalud.certificado'), findsOneWidget);

      // Tocarlo abre la hoja con el texto de esa clave.
      await tester.tap(boton('app.miSalud.certificado'));
      await tester.pumpAndSettle();
      expect(find.byType(HojaDeAyuda), findsOneWidget);
      expect(find.text('Ayuda de app.miSalud.certificado'), findsOneWidget);
    });
  });

  testWidgets('el centro de ayuda lleva el suyo', (tester) async {
    final api = DioGrabador({'GET /ayuda': (_) => articulosJson()});

    await montarPantalla(
      tester,
      CentroAyudaPage(servicio: AyudaService(api.dio, CacheEnMemoria())),
      ayuda: textos,
    );
    await tester.pumpAndSettle();

    expect(boton('app.ayuda'), findsOneWidget);
  });

  testWidgets('el detalle de la cita: reprogramar, cancelar y la '
      'videoconsulta, junto a cada acción', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final cubit = AyudaContextualCubit(
      AyudaContextualService(Dio(), CacheEnMemoria()),
      inicial: AyudaContextualState(uid: 'u1', mapa: textos),
    );
    addTearDown(cubit.close);

    // Una de telemedicina que empieza en un rato: la sala está por abrir y
    // todavía se puede cambiar.
    final inicio = RelojClinica().ahora().add(const Duration(hours: 20));
    final cita = Cita(
      id: 'c1',
      inicio: DateTime(
        inicio.year,
        inicio.month,
        inicio.day,
        inicio.hour,
        inicio.minute,
      ),
      fin: DateTime(
        inicio.year,
        inicio.month,
        inicio.day,
        inicio.hour,
        inicio.minute,
      ).add(const Duration(minutes: 30)),
      tipo: TipoCita.telemedicina,
      estado: EstadoCita.programada,
      doctorId: 'doc',
      medico: 'Luis Mora',
      especialidad: 'Pediatría',
    );

    await tester.pumpWidget(
      conDatosDeLaClinica(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: temaCliniq(),
            home: Scaffold(
              body: Builder(
                builder: (context) =>
                    DetalleCita(cita: cita, contextoPadre: context),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.scrollUntilVisible(
      boton('app.videoconsulta'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(boton('app.videoconsulta'), findsOneWidget);

    await tester.scrollUntilVisible(
      boton('app.misCitas.cancelar'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(boton('app.misCitas.reprogramar'), findsOneWidget);
    expect(boton('app.misCitas.cancelar'), findsOneWidget);
  });
}
