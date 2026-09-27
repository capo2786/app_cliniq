// test/videoconsulta_test.dart

import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/core/integraciones/costuras.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/citas/data/videollamada_service.dart';
import 'package:app_cliniq/features/citas/dominio/videoconsulta.dart';
import 'package:app_cliniq/features/citas/presentacion/widgets/tarjeta_cita.dart';
import 'package:app_cliniq/features/citas/presentacion/widgets/videoconsulta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';

/// La videoconsulta: cuándo abre la sala, cómo se pide y cómo se abre.
void main() {
  // Una cita de telemedicina de 10:00 a 10:20, en hora de la clínica.
  Cita cita({
    TipoCita tipo = TipoCita.telemedicina,
    EstadoCita estado = EstadoCita.programada,
  }) => Cita(
    id: 'c1',
    inicio: DateTime(2026, 9, 28, 10),
    fin: DateTime(2026, 9, 28, 10, 20),
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

    test('la abre en el navegador, fuera de la aplicación', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) => salaJson(),
      });
      final abiertas = <Uri>[];

      await VideollamadaEnNavegador(
        VideollamadaService(api.dio),
        abrir: (direccion) async {
          abiertas.add(direccion);
          return true;
        },
      ).unirse('c1');

      expect(abiertas, [Uri.parse('https://meet.x.com/cliniq-abc?jwt=t')]);
    });

    test('409: el mensaje del servidor, tal cual', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) =>
            throw errorHttp(409, 'La sala se abre 15 minutos antes de la cita'),
      });
      final abiertas = <Uri>[];

      final video = VideollamadaEnNavegador(
        VideollamadaService(api.dio),
        abrir: (d) async {
          abiertas.add(d);
          return true;
        },
      );

      await expectLater(
        video.unirse('c1'),
        throwsA(
          isA<ErrorDeVideollamada>().having(
            (e) => e.mensaje,
            'mensaje',
            'La sala se abre 15 minutos antes de la cita',
          ),
        ),
      );
      expect(abiertas, isEmpty);
    });

    test('503 sin mensaje: se explica que no está disponible', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) => throw errorHttp(503),
      });

      await expectLater(
        VideollamadaEnNavegador(
          VideollamadaService(api.dio),
          abrir: (_) async => true,
        ).unirse('c1'),
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

    test('una dirección que no es https no se abre', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) =>
            salaJson(url: 'http://meet.x.com/sala'),
      });

      await expectLater(
        VideollamadaEnNavegador(
          VideollamadaService(api.dio),
          abrir: (_) async => true,
        ).unirse('c1'),
        throwsA(isA<ErrorDeVideollamada>()),
      );
    });

    test('sin navegador que la abra, se dice', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) => salaJson(),
      });

      await expectLater(
        VideollamadaEnNavegador(
          VideollamadaService(api.dio),
          abrir: (_) async => false,
        ).unirse('c1'),
        throwsA(
          isA<ErrorDeVideollamada>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('navegador'),
          ),
        ),
      );
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
      expect(servicio.unidas, isEmpty);
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

      expect(servicio.unidas, ['c1']);
      expect(
        find.text('La videoconsulta no está disponible en este momento.'),
        findsOneWidget,
      );
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

      expect(servicio.unidas, ['c1']);
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
  });
}

class _VideoFalso implements ServicioVideollamada {
  final ErrorDeVideollamada? error;
  final List<String> unidas = [];

  _VideoFalso({this.error});

  @override
  bool get disponible => true;

  @override
  Future<void> unirse(String citaId) async {
    unidas.add(citaId);
    final e = error;
    if (e != null) throw e;
  }
}
