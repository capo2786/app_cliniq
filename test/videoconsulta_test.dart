// test/videoconsulta_test.dart

import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/citas/data/citas_service.dart';
import 'package:app_cliniq/features/citas/presentacion/videoconsulta_page.dart';
import 'package:app_cliniq/features/citas/providers/citas_bloc.dart';
import 'package:app_cliniq/features/citas/providers/citas_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/citas/data/permisos_de_video.dart';
import 'package:app_cliniq/features/citas/data/videollamada_service.dart';
import 'package:app_cliniq/features/citas/dominio/videoconsulta.dart';
import 'package:app_cliniq/features/citas/presentacion/widgets/sala_de_videoconsulta.dart';
import 'package:app_cliniq/features/citas/presentacion/widgets/tarjeta_cita.dart';
import 'package:app_cliniq/features/citas/presentacion/widgets/videoconsulta.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';

/// La videoconsulta: cuándo abre la sala, cómo se pide y cómo se abre: en
/// una ventana sobre la cita, con la cabecera de Cliniq y la sala debajo.
void main() {
  setUpAll(() => ZonaClinica.aplicar('America/Guayaquil'));

  /// Deja correr las animaciones de abrir y cerrar (la ventana, la
  /// pregunta) sin esperar a que pare la rueda de «Conectando…», que no
  /// para sola.
  Future<void> asentar(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  // Una cita de telemedicina de 10:00 a 10:20, en hora de la clínica.
  Cita cita({
    TipoCita tipo = TipoCita.telemedicina,
    EstadoCita estado = EstadoCita.programada,
    DateTime? inicio,
    DateTime? fin,
  }) => Cita(
    id: 'c1',
    inicio: inicio ?? DateTime(2026, 9, 28, 10),
    fin: fin ?? DateTime(2026, 9, 28, 10, 20),
    tipo: tipo,
    estado: estado,
    doctorId: 'doc',
    medico: 'Ana Pérez',
  );

  Map<String, dynamic> salaJson({
    String url = 'https://meet.x.com/cliniq-abc?jwt=t',
  }) => {
    'dominio': 'meet.x.com',
    'sala': 'cliniq-abc',
    'jwt': 't',
    'url': url,
    'abreEn': '2026-09-28T14:45:00.000Z',
    'cierraEn': '2026-09-28T16:20:00.000Z',
    'esModerador': false,
  };

  group('La ventana de la sala', () {
    // La de la configuración de prueba: abre 15 minutos antes del inicio y
    // cierra 60 después del fin (`telemedicina.minutosAntes/minutosDespues`).
    final ventana = VentanaDeSala.de(configDePrueba().telemedicina);

    test('abre los minutos de antes que dice la clínica', () {
      expect(ventana.minutosAntes, 15);
      expect(
        estadoDeSala(cita(), DateTime(2026, 9, 28, 9, 44, 59), ventana),
        EstadoSala.porAbrir,
      );
      expect(
        estadoDeSala(cita(), DateTime(2026, 9, 28, 9, 45), ventana),
        EstadoSala.abierta,
      );
    });

    test('sigue durante la cita y hasta los minutos de después del fin', () {
      expect(ventana.minutosDespues, 60);
      expect(
        estadoDeSala(cita(), DateTime(2026, 9, 28, 10, 10), ventana),
        EstadoSala.abierta,
      );
      expect(
        estadoDeSala(cita(), DateTime(2026, 9, 28, 11, 20), ventana),
        EstadoSala.abierta,
      );
      expect(
        estadoDeSala(cita(), DateTime(2026, 9, 28, 11, 20, 1), ventana),
        EstadoSala.cerrada,
      );
    });

    test('otra configuración, otra ventana', () {
      final amplia = VentanaDeSala.de(
        configDePrueba(
          telemedicina: {'minutosAntes': 120, 'minutosDespues': 240},
        ).telemedicina,
      );

      expect(
        estadoDeSala(cita(), DateTime(2026, 9, 28, 8), amplia),
        EstadoSala.abierta,
      );
      expect(
        estadoDeSala(cita(), DateTime(2026, 9, 28, 8), ventana),
        EstadoSala.porAbrir,
      );
      expect(
        estadoDeSala(cita(), DateTime(2026, 9, 28, 14, 20), amplia),
        EstadoSala.abierta,
      );
    });

    test('también para una cita ya atendida, mientras dure la ventana', () {
      expect(
        estadoDeSala(
          cita(estado: EstadoCita.atendida),
          DateTime(2026, 9, 28, 10, 50),
          ventana,
        ),
        EstadoSala.abierta,
      );
    });

    test('no aplica a una cancelada ni a otra modalidad', () {
      final hora = DateTime(2026, 9, 28, 10);

      expect(
        estadoDeSala(cita(estado: EstadoCita.cancelada), hora, ventana),
        EstadoSala.noAplica,
      );
      expect(
        estadoDeSala(cita(tipo: TipoCita.presencial), hora, ventana),
        EstadoSala.noAplica,
      );
      expect(
        estadoDeSala(cita(tipo: TipoCita.asincrona), hora, ventana),
        EstadoSala.noAplica,
      );
    });

    test('a qué hora abre, con los minutos de la clínica, y otro día con la '
        'fecha', () {
      expect(
        cuandoAbreLaSala(cita(), DateTime(2026, 9, 28, 7), ventana),
        'La sala abre a las 09:45, 15 minutos antes de la cita.',
      );
      expect(
        cuandoAbreLaSala(cita(), DateTime(2026, 9, 27, 20), ventana),
        contains('mañana a las 09:45'),
      );
      expect(
        cuandoAbreLaSala(cita(), DateTime(2026, 9, 25, 20), ventana),
        contains('el lunes 28 de septiembre a las 09:45'),
      );
    });
  });

  group('La tarjeta de la lista', () {
    Future<void> montar(
      WidgetTester tester,
      DateTime ahora, {
      Map<String, dynamic>? telemedicina,
    }) async {
      await tester.pumpWidget(
        conDatosDeLaClinica(
          config: configDePrueba(telemedicina: telemedicina),
          MaterialApp(
            theme: temaCliniq(),
            home: Scaffold(
              body: TarjetaCita(cita: cita(), ahora: ahora),
            ),
          ),
        ),
      );
    }

    testWidgets('«Sala abierta» sigue la ventana de la configuración', (
      tester,
    ) async {
      await montar(tester, DateTime(2026, 9, 28, 9, 44));
      expect(find.text('Sala abierta'), findsNothing);

      await montar(tester, DateTime(2026, 9, 28, 9, 45));
      expect(find.text('Sala abierta'), findsOneWidget);

      await montar(tester, DateTime(2026, 9, 28, 11, 20));
      expect(find.text('Sala abierta'), findsOneWidget);

      await montar(tester, DateTime(2026, 9, 28, 11, 21));
      expect(find.text('Sala abierta'), findsNothing);
    });

    testWidgets('con otra configuración, la otra ventana', (tester) async {
      await montar(
        tester,
        DateTime(2026, 9, 28, 9, 40),
        telemedicina: {'minutosAntes': 30},
      );
      expect(find.text('Sala abierta'), findsOneWidget);
    });

    testWidgets('el nombre, el color y el estado salen de los catálogos', (
      tester,
    ) async {
      await montar(tester, DateTime(2026, 9, 28, 7));

      expect(find.text('Telemedicina'), findsOneWidget);
      expect(find.text('Programada'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.textContaining('Dr(a).'), findsNothing);
    });
  });

  group('Pedir la sala', () {
    VideollamadaEnLaApp video(DioGrabador api) => VideollamadaEnLaApp(
      VideollamadaService(api.dio),
      sala: _SalaFalsa(),
      permisos: _PermisosFalsos(),
    );

    test('GET /portal/citas/:id/videollamada y lee la sala', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) => salaJson(),
      });

      final sala = await VideollamadaService(api.dio).pedir('c1');

      expect(api.claves, ['GET /portal/citas/c1/videollamada']);
      expect(sala.url, 'https://meet.x.com/cliniq-abc?jwt=t');
      expect(sala.sala, 'cliniq-abc');
      expect(sala.esModerador, isFalse);
      // Instantes reales, no hora congelada.
      expect(sala.abreEn, DateTime.utc(2026, 9, 28, 14, 45));
    });

    test('da lo que hace falta para abrirla: dominio, sala, token y hasta '
        'cuándo', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) => salaJson(),
      });

      expect(
        await video(api).pedirSala('c1'),
        DatosDeSala(
          dominio: 'meet.x.com',
          sala: 'cliniq-abc',
          token: 't',
          cierraEn: DateTime.utc(2026, 9, 28, 16, 20),
        ),
      );
    });

    test(
      'sin dominio, el de la dirección de la sala; el dominio se limpia',
      () {
        final sala = Videollamada.desdeJson({
          ...salaJson(url: 'https://video.andina.ec/cliniq-abc?jwt=t'),
          'dominio': '',
        });
        expect(DatosDeSala.de(sala)?.dominio, 'video.andina.ec');

        expect(dominioLimpio(' https://meet.andina.ec/ '), 'meet.andina.ec');
        expect(
          DatosDeSala.de(Videollamada.desdeJson({...salaJson(), 'jwt': ''})),
          isNull,
          reason: 'sin token no se entra',
        );
      },
    );

    test('una sala incompleta se explica, sin abrir nada', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) => {...salaJson(), 'jwt': ''},
      });

      await expectLater(
        video(api).pedirSala('c1'),
        throwsA(
          isA<ErrorDeVideollamada>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('no llegó completa'),
          ),
        ),
      );
    });

    test('el asunto lleva el nombre de la clínica', () {
      expect(
        asuntoDeLaSala('Clínica Andina'),
        'Videoconsulta · Clínica Andina',
      );
      expect(asuntoDeLaSala('  '), 'Videoconsulta');
    });

    test('409: el mensaje del servidor, tal cual', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) =>
            throw errorHttp(409, 'La sala se abre 15 minutos antes de la cita'),
      });

      await expectLater(
        video(api).pedirSala('c1'),
        throwsA(
          isA<ErrorDeVideollamada>().having(
            (e) => e.mensaje,
            'mensaje',
            'La sala se abre 15 minutos antes de la cita',
          ),
        ),
      );
    });

    test('503 sin mensaje: se explica que no está disponible', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) => throw errorHttp(503),
      });

      await expectLater(
        video(api).pedirSala('c1'),
        throwsA(
          isA<ErrorDeVideollamada>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('no está disponible'),
          ),
        ),
      );
    });

    test('409 sin mensaje: no se inventa cuántos minutos', () {
      final mensaje = mensajeDeVideollamada(errorHttp(409));
      expect(mensaje, contains('La sala no está abierta ahora.'));
      expect(mensaje, isNot(contains('15')));
    });

    test('503 con mensaje del servidor: ese', () {
      expect(
        mensajeDeVideollamada(
          errorHttp(503, 'La videoconsulta no está configurada.'),
        ),
        'La videoconsulta no está configurada.',
      );
      expect(mensajeDeVideollamada(errorDeRed()), contains('Sin conexión'));
    });

    test('solo en Android e iOS', () {
      final api = DioGrabador();
      expect(video(api).disponible, isTrue, reason: 'las pruebas son Android');

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(video(api).disponible, isFalse);
    });
  });

  group('La cabecera', () {
    test('con quién y a qué hora termina, en la hora de la clínica', () {
      expect(
        tituloDeLaVideoconsulta('Ana Pérez'),
        'Videoconsulta con Ana Pérez',
      );
      expect(tituloDeLaVideoconsulta('  '), 'Videoconsulta');
      expect(tituloDeLaVideoconsulta(null), 'Videoconsulta');

      final ventana = VentanaDeSala.de(configDePrueba().telemedicina);

      // Con la cita: su fin, que ya es hora de la clínica.
      expect(
        finDeLaVideoconsulta(cita: cita(), ventana: ventana),
        DateTime(2026, 9, 28, 10, 20),
      );
      // Sin ella: el cierre de la sala del servidor (16:20 UTC) menos los 60
      // minutos de después, en Quito.
      expect(
        finDeLaVideoconsulta(
          cierraEn: DateTime.utc(2026, 9, 28, 16, 20),
          ventana: ventana,
        ),
        DateTime(2026, 9, 28, 10, 20),
      );
      expect(finDeLaVideoconsulta(ventana: ventana), isNull);
      expect(terminaALas(DateTime(2026, 9, 28, 10, 20)), 'Termina a las 10:20');
    });
  });

  group('El botón', () {
    Future<void> montar(
      WidgetTester tester, {
      required DateTime ahora,
      required ServicioVideollamada servicio,
    }) async {
      await tester.pumpWidget(
        conDatosDeLaClinica(
          MaterialApp(
            theme: temaCliniq(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: BotonVideoconsulta(
                  cita: cita(),
                  servicio: servicio,
                  reloj: RelojClinica.fijo(ahora),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('antes de la ventana se ve apagado y dice a qué hora abre', (
      tester,
    ) async {
      final servicio = _VideoFalso();
      await montar(
        tester,
        ahora: DateTime(2026, 9, 28, 9, 30),
        servicio: servicio,
      );

      expect(find.text('Entrar a la videoconsulta'), findsOneWidget);
      expect(find.textContaining('a las 09:45'), findsOneWidget);
      expect(find.textContaining('cámara y el micrófono'), findsOneWidget);

      await tester.tap(find.byKey(const Key('boton-videoconsulta')));
      await tester.pump();
      expect(servicio.pedidas, isEmpty);
    });

    testWidgets('con la sala abierta entra; si el servidor dice que no, '
        'se enseña su mensaje con el contacto de la clínica', (tester) async {
      final servicio = _VideoFalso(
        error: const ErrorDeVideollamada(
          'La videoconsulta no está disponible en este momento.',
        ),
      );
      await montar(
        tester,
        ahora: DateTime(2026, 9, 28, 9, 50),
        servicio: servicio,
      );

      expect(find.textContaining('La sala abre'), findsNothing);
      expect(find.textContaining('cámara y el micrófono'), findsOneWidget);

      await tester.tap(find.byKey(const Key('boton-videoconsulta')));
      await tester.pump();
      await tester.pump();

      expect(servicio.pedidas, ['c1']);
      expect(
        find.text('La videoconsulta no está disponible en este momento.'),
        findsOneWidget,
      );
      expect(find.byType(VentanaDeVideoconsulta), findsNothing);
      // El teléfono y el correo de la configuración, para tocarlos.
      expect(find.text('02 255 0000'), findsOneWidget);
      expect(find.text('contacto@andina.ec'), findsOneWidget);
    });

    testWidgets('a la hora exacta en que abre ya se puede tocar; si el '
        'servidor igual dice que no, su mensaje manda', (tester) async {
      final servicio = _VideoFalso(
        error: const ErrorDeVideollamada(
          'La sala se abre 15 minutos antes de la cita.',
        ),
      );
      await montar(
        tester,
        ahora: DateTime(2026, 9, 28, 9, 45),
        servicio: servicio,
      );

      await tester.tap(find.byKey(const Key('boton-videoconsulta')));
      await tester.pump();
      await tester.pump();

      expect(servicio.pedidas, ['c1']);
      expect(
        find.text('La sala se abre 15 minutos antes de la cita.'),
        findsOneWidget,
      );
    });

    testWidgets('pasada la ventana ya no se ve', (tester) async {
      await montar(
        tester,
        ahora: DateTime(2026, 9, 28, 11, 21),
        servicio: _VideoFalso(),
      );

      expect(find.text('Entrar a la videoconsulta'), findsNothing);
    });

    testWidgets('sin videoconsulta en esta plataforma, el enlace llega por '
        'correo', (tester) async {
      await montar(
        tester,
        ahora: DateTime(2026, 9, 28, 9, 50),
        servicio: _VideoFalso(disponible: false),
      );

      expect(find.text('Entrar a la videoconsulta'), findsNothing);
      expect(find.textContaining('te llega por correo'), findsOneWidget);
    });
  });

  group('La ventana de la videoconsulta', () {
    setUp(sondeoConRed);

    /// La cita de la pantalla, debajo, y su botón.
    Future<void> montar(
      WidgetTester tester,
      _VideoFalso servicio, {
      Cita? conCita,
    }) async {
      await tester.pumpWidget(
        conDatosDeLaClinica(
          MaterialApp(
            theme: temaCliniq(),
            home: Scaffold(
              appBar: AppBar(title: const Text('Detalle de la cita')),
              body: SingleChildScrollView(
                child: EntrarASala(
                  citaId: 'c1',
                  cita: conCita,
                  servicio: servicio,
                ),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> entrar(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('boton-videoconsulta')));
      await asentar(tester);
    }

    testWidgets('se abre encima de la cita, que sigue debajo, con la '
        'cabecera de Cliniq y la sala; colgar pregunta y vuelve a la cita', (
      tester,
    ) async {
      final servicio = _VideoFalso();
      await montar(tester, servicio, conCita: cita());
      await entrar(tester);

      // La ventana, encima; la pantalla de la cita, debajo, en el árbol.
      expect(find.byType(VentanaDeVideoconsulta), findsOneWidget);
      expect(find.text('Detalle de la cita'), findsOneWidget);
      expect(find.byType(EntrarASala), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);

      expect(find.text('Videoconsulta con Ana Pérez'), findsOneWidget);
      expect(find.text('Termina a las 10:20'), findsOneWidget);
      expect(servicio.permisos.pedidos, 1);
      expect(servicio.sala.abiertas, [
        (
          const DatosDeSala(
            dominio: 'meet.x.com',
            sala: 'cliniq-abc',
            token: 't',
          ),
          'Videoconsulta · Clínica Andina',
        ),
      ]);

      // Colgar desde la cabecera: pregunta; «Cancelar» sigue en la sala.
      await tester.tap(find.byKey(const Key('colgar-videoconsulta')));
      await asentar(tester);
      expect(find.text('¿Salir de la videoconsulta?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await asentar(tester);
      expect(find.byType(VentanaDeVideoconsulta), findsOneWidget);

      // «Salir» vuelve a la misma pantalla.
      await tester.tap(find.byKey(const Key('colgar-videoconsulta')));
      await asentar(tester);
      await tester.tap(find.text('Salir'));
      await asentar(tester);

      expect(find.byType(VentanaDeVideoconsulta), findsNothing);
      expect(find.text('Detalle de la cita'), findsOneWidget);
      expect(find.byKey(const Key('boton-videoconsulta')), findsOneWidget);
    });

    testWidgets('colgar desde Jitsi cierra sin preguntar', (tester) async {
      final servicio = _VideoFalso();
      await montar(tester, servicio);
      await entrar(tester);

      servicio.sala.oyente!.alTerminar();
      await asentar(tester);

      expect(find.byType(VentanaDeVideoconsulta), findsNothing);
      expect(find.text('¿Salir de la videoconsulta?'), findsNothing);
      expect(find.text('Detalle de la cita'), findsOneWidget);
    });

    testWidgets('si Jitsi cuelga con la pregunta abierta, se cierran las dos', (
      tester,
    ) async {
      final servicio = _VideoFalso();
      await montar(tester, servicio);
      await entrar(tester);

      await tester.tap(find.byKey(const Key('colgar-videoconsulta')));
      await asentar(tester);
      expect(find.text('¿Salir de la videoconsulta?'), findsOneWidget);

      servicio.sala.oyente!.alTerminar();
      await asentar(tester);

      expect(find.text('¿Salir de la videoconsulta?'), findsNothing);
      expect(find.byType(VentanaDeVideoconsulta), findsNothing);
      expect(find.text('Detalle de la cita'), findsOneWidget);
    });

    testWidgets('el botón atrás de Android pregunta antes de salir', (
      tester,
    ) async {
      final servicio = _VideoFalso();
      await montar(tester, servicio);
      await entrar(tester);

      await tester.binding.handlePopRoute();
      await asentar(tester);
      expect(find.text('¿Salir de la videoconsulta?'), findsOneWidget);
      expect(find.byType(VentanaDeVideoconsulta), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await asentar(tester);
      expect(find.byType(VentanaDeVideoconsulta), findsOneWidget);

      await tester.binding.handlePopRoute();
      await asentar(tester);
      await tester.tap(find.text('Salir'));
      await asentar(tester);

      expect(find.byType(VentanaDeVideoconsulta), findsNothing);
      expect(find.text('Detalle de la cita'), findsOneWidget);
    });

    testWidgets('un toque fuera de la ventana no la cierra', (tester) async {
      await montar(tester, _VideoFalso());
      await entrar(tester);

      await tester.tapAt(const Offset(20, 5));
      await asentar(tester);

      expect(find.byType(VentanaDeVideoconsulta), findsOneWidget);
    });

    testWidgets('«Conectando con la sala…» hasta que Jitsi dice que entró', (
      tester,
    ) async {
      final servicio = _VideoFalso();
      await montar(tester, servicio);
      await entrar(tester);

      expect(find.text('Conectando con la sala…'), findsOneWidget);

      servicio.sala.oyente!.alCargar();
      await tester.pump();
      expect(find.text('Conectando con la sala…'), findsOneWidget);

      servicio.sala.oyente!.alEntrar();
      await tester.pump();
      expect(find.text('Conectando con la sala…'), findsNothing);
    });

    testWidgets('si Jitsi no dice nada, con la página ya cargada se deja ver '
        'lo que diga la página', (tester) async {
      final servicio = _VideoFalso();
      await montar(tester, servicio);
      await entrar(tester);

      servicio.sala.oyente!.alCargar();
      await tester.pump(const Duration(seconds: 7));
      expect(find.text('Conectando con la sala…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Conectando con la sala…'), findsNothing);
    });

    testWidgets('sin cámara o micrófono lo explica y vuelve a pedirlos; con '
        'ellos, abre la sala', (tester) async {
      final permisos = _PermisosFalsos([
        ResultadoDePermisos.denegados,
        ResultadoDePermisos.concedidos,
      ]);
      final servicio = _VideoFalso(permisos: permisos);
      await montar(tester, servicio);
      await entrar(tester);

      expect(
        find.text('Falta el permiso de la cámara o el micrófono'),
        findsOneWidget,
      );
      expect(find.textContaining('así el médico te ve'), findsOneWidget);
      expect(find.byKey(const Key('ajustes-videoconsulta')), findsNothing);
      expect(servicio.sala.abiertas, isEmpty);

      await tester.tap(find.byKey(const Key('reintentar-videoconsulta')));
      await asentar(tester);

      expect(permisos.pedidos, 2);
      expect(servicio.sala.abiertas, hasLength(1));
      expect(find.text('Conectando con la sala…'), findsOneWidget);
    });

    testWidgets('si el teléfono ya no deja preguntar, ofrece los ajustes; '
        'cerrar no pregunta', (tester) async {
      final permisos = _PermisosFalsos([ResultadoDePermisos.bloqueados]);
      final servicio = _VideoFalso(permisos: permisos);
      await montar(tester, servicio);
      await entrar(tester);

      expect(find.textContaining('ajustes del teléfono'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ajustes-videoconsulta')));
      await tester.pump();
      expect(permisos.ajustesAbiertos, 1);
      expect(servicio.sala.abiertas, isEmpty);

      await tester.tap(find.byKey(const Key('colgar-videoconsulta')));
      await asentar(tester);

      expect(find.text('¿Salir de la videoconsulta?'), findsNothing);
      expect(find.byType(VentanaDeVideoconsulta), findsNothing);
    });

    testWidgets('si la sala no carga, lo dice aquí mismo y «Reintentar» la '
        'vuelve a abrir', (tester) async {
      final servicio = _VideoFalso();
      await montar(tester, servicio);
      await entrar(tester);

      servicio.sala.oyente!.alFallar('No pudimos abrir la sala de video.');
      await asentar(tester);

      expect(find.text('No se abrió la videoconsulta'), findsOneWidget);
      expect(find.text('No pudimos abrir la sala de video.'), findsOneWidget);
      expect(find.byType(VentanaDeVideoconsulta), findsOneWidget);

      await tester.tap(find.byKey(const Key('reintentar-videoconsulta')));
      await asentar(tester);

      expect(servicio.sala.abiertas, hasLength(2));
      expect(find.text('No se abrió la videoconsulta'), findsNothing);
      expect(find.text('Conectando con la sala…'), findsOneWidget);
    });

    testWidgets('sin la cita, la hora de fin sale del cierre de la sala', (
      tester,
    ) async {
      final servicio = _VideoFalso(
        datos: DatosDeSala(
          dominio: 'meet.x.com',
          sala: 'cliniq-abc',
          token: 't',
          cierraEn: DateTime.utc(2026, 9, 28, 16, 20),
        ),
      );
      await montar(tester, servicio);
      await entrar(tester);

      expect(find.text('Videoconsulta'), findsOneWidget);
      expect(find.text('Termina a las 10:20'), findsOneWidget);
    });

    testWidgets('con el teclado abierto, la cabecera se queda y la sala se '
        'encoge', (tester) async {
      final servicio = _VideoFalso();
      await montar(tester, servicio);
      await entrar(tester);

      final antes = tester.getSize(find.byKey(_SalaFalsa.clave)).height;
      final cabecera = tester.getTopLeft(find.byType(CabeceraDeVideoconsulta));

      tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
      addTearDown(tester.view.resetViewInsets);
      await asentar(tester);

      expect(find.byType(CabeceraDeVideoconsulta), findsOneWidget);
      expect(tester.getTopLeft(find.byType(CabeceraDeVideoconsulta)), cabecera);
      expect(
        tester.getSize(find.byKey(_SalaFalsa.clave)).height,
        lessThan(antes - 250),
      );
    });
  });

  group('La pantalla de la videoconsulta', () {
    setUp(sondeoConRed);

    Future<CitasBloc> montar(
      WidgetTester tester, {
      required List<Cita> citas,
      required ServicioVideollamada servicio,
      CargaCitas carga = CargaCitas.lista,
    }) async {
      final bloc = CitasBloc(
        citas: CitasService(DioGrabador().dio, CacheEnMemoria()),
        portal: PortalFalso(),
        recordatorios: ProgramadorFalso(),
        config: configDePrueba,
        catalogos: catalogosDePrueba,
      )..emit(CitasState(citas: citas, carga: carga));
      addTearDown(bloc.close);

      await tester.pumpWidget(
        conDatosDeLaClinica(
          BlocProvider.value(
            value: bloc,
            child: MaterialApp(
              theme: temaCliniq(),
              home: VideoconsultaPage(citaId: 'c1', servicio: servicio),
            ),
          ),
        ),
      );
      await asentar(tester);
      return bloc;
    }

    testWidgets('desde un aviso o un enlace, con la sala abierta, la '
        'videoconsulta se abre sola encima de la cita; al colgar se vuelve '
        'a ella', (tester) async {
      final servicio = _VideoFalso();
      final hoy = RelojClinica().ahora();
      final ahora = cita(
        inicio: hoy.subtract(const Duration(minutes: 5)),
        fin: hoy.add(const Duration(minutes: 15)),
      );
      await montar(tester, citas: [ahora], servicio: servicio);

      expect(servicio.pedidas, ['c1']);
      expect(find.byType(VentanaDeVideoconsulta), findsOneWidget);
      expect(find.byType(VideoconsultaPage), findsOneWidget);
      expect(find.byType(TarjetaCita), findsOneWidget);
      expect(find.text('Videoconsulta con Ana Pérez'), findsOneWidget);

      servicio.sala.oyente!.alTerminar();
      await asentar(tester);

      expect(find.byType(VentanaDeVideoconsulta), findsNothing);
      expect(find.byType(TarjetaCita), findsOneWidget);
      expect(find.byType(BotonVideoconsulta), findsOneWidget);
      // Se entra sola una vez: volver a entrar es tocar el botón.
      expect(servicio.pedidas, ['c1']);
    });

    testWidgets('con la sala todavía por abrir, la tarjeta y el botón con su '
        'ventana, sin entrar', (tester) async {
      final servicio = _VideoFalso();
      final manana = RelojClinica().ahora().add(const Duration(days: 1));
      await montar(
        tester,
        citas: [
          cita(inicio: manana, fin: manana.add(const Duration(minutes: 20))),
        ],
        servicio: servicio,
      );

      expect(find.byType(TarjetaCita), findsOneWidget);
      expect(find.byType(BotonVideoconsulta), findsOneWidget);
      expect(find.textContaining('La sala abre'), findsOneWidget);
      expect(servicio.pedidas, isEmpty);
      expect(find.byType(VentanaDeVideoconsulta), findsNothing);
    });

    testWidgets('sin la cita, se entra igual y el servidor decide', (
      tester,
    ) async {
      final servicio = _VideoFalso(
        error: const ErrorDeVideollamada('No se encontró la cita.'),
      );
      await montar(tester, citas: const [], servicio: servicio);

      expect(find.byType(TarjetaCita), findsNothing);
      expect(servicio.pedidas, ['c1']);
      expect(find.text('No se encontró la cita.'), findsOneWidget);
      expect(find.byType(VentanaDeVideoconsulta), findsNothing);

      await tester.tap(find.byKey(const Key('boton-videoconsulta')));
      await tester.pump();
      expect(servicio.pedidas, ['c1', 'c1']);
    });

    testWidgets('si la lista llega después, no se vuelve a entrar sola', (
      tester,
    ) async {
      final servicio = _VideoFalso();
      final hoy = RelojClinica().ahora();
      final bloc = await montar(tester, citas: const [], servicio: servicio);
      expect(servicio.pedidas, ['c1']);

      servicio.sala.oyente!.alTerminar();
      await asentar(tester);

      bloc.emit(
        CitasState(
          citas: [
            cita(
              inicio: hoy.subtract(const Duration(minutes: 5)),
              fin: hoy.add(const Duration(minutes: 15)),
            ),
          ],
          carga: CargaCitas.lista,
        ),
      );
      await asentar(tester);

      expect(find.byType(TarjetaCita), findsOneWidget);
      expect(servicio.pedidas, ['c1']);
      expect(find.byType(VentanaDeVideoconsulta), findsNothing);
    });
  });
}

/// La videoconsulta, sin red ni plataforma: la sala que da el servidor, los
/// permisos y la sala embebida son dobles.
class _VideoFalso implements ServicioVideollamada {
  final ErrorDeVideollamada? error;
  final DatosDeSala datos;
  final List<String> pedidas = [];

  @override
  final bool disponible;

  @override
  final _PermisosFalsos permisos;

  @override
  final _SalaFalsa sala = _SalaFalsa();

  _VideoFalso({
    this.error,
    this.disponible = true,
    this.datos = const DatosDeSala(
      dominio: 'meet.x.com',
      sala: 'cliniq-abc',
      token: 't',
    ),
    _PermisosFalsos? permisos,
  }) : permisos = permisos ?? _PermisosFalsos();

  @override
  Future<DatosDeSala> pedirSala(String citaId) async {
    pedidas.add(citaId);
    final e = error;
    if (e != null) throw e;
    return datos;
  }
}

/// La cámara y el micrófono: contesta en orden lo que se le programó (y
/// después, lo último).
class _PermisosFalsos implements PermisosDeVideo {
  final List<ResultadoDePermisos> respuestas;
  int pedidos = 0;
  int ajustesAbiertos = 0;

  _PermisosFalsos([this.respuestas = const [ResultadoDePermisos.concedidos]]);

  @override
  Future<ResultadoDePermisos> pedir() async {
    final respuesta = respuestas[pedidos.clamp(0, respuestas.length - 1)];
    pedidos++;
    return respuesta;
  }

  @override
  Future<bool> abrirAjustes() async {
    ajustesAbiertos++;
    return true;
  }
}

/// La sala embebida, sin WebView: anota qué salas se abrieron (con qué
/// asunto) y deja a la prueba hablar por la página.
class _SalaFalsa implements SalaDeVideo {
  static const Key clave = Key('sala-falsa');

  final List<(DatosDeSala, String)> abiertas = [];
  OyenteDeSala? oyente;

  @override
  Widget construir(
    DatosDeSala datos, {
    required String asunto,
    required OyenteDeSala oyente,
  }) {
    abiertas.add((datos, asunto));
    this.oyente = oyente;
    return const SizedBox.expand(key: clave);
  }
}
