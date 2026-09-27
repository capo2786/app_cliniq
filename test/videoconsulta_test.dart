// test/videoconsulta_test.dart

import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/core/integraciones/costuras.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/core/storage/almacen_claves.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/storage/credenciales_service.dart';
import 'package:app_cliniq/features/auth/data/almacen_de_sesion.dart';
import 'package:app_cliniq/features/auth/providers/auth_bloc.dart';
import 'package:app_cliniq/features/auth/providers/auth_state.dart';
import 'package:app_cliniq/features/citas/data/citas_service.dart';
import 'package:app_cliniq/features/citas/presentacion/videoconsulta_page.dart';
import 'package:app_cliniq/features/citas/providers/citas_bloc.dart';
import 'package:app_cliniq/features/citas/providers/citas_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

    test('entra con el SDK, dentro de la aplicación: servidor, sala, '
        'token, nombre y asunto', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) => salaJson(),
      });
      final sala = _SalaFalsa();
      final navegador = _NavegadorFalso();

      final donde =
          await VideollamadaEnLaApp(
            VideollamadaService(api.dio),
            sala: sala,
            abrirEnNavegador: navegador.abrir,
          ).unirse(
            'c1',
            nombreVisible: 'Ana María Pérez',
            asunto: 'Videoconsulta · Clínica Andina',
          );

      expect(donde, SalaAbierta.enLaAplicacion);
      expect(sala.entradas, [
        const DatosDeSala(
          servidor: 'https://meet.x.com',
          sala: 'cliniq-abc',
          token: 't',
          nombreVisible: 'Ana María Pérez',
          asunto: 'Videoconsulta · Clínica Andina',
        ),
      ]);
      expect(navegador.abiertas, isEmpty);
    });

    test(
      'sin dominio, el de la dirección de la sala; el dominio se limpia',
      () {
        final sala = Videollamada.desdeJson({
          ...salaJson(url: 'https://video.andina.ec/cliniq-abc?jwt=t'),
          'dominio': '',
        });
        expect(DatosDeSala.de(sala)?.servidor, 'https://video.andina.ec');

        expect(dominioLimpio(' https://meet.andina.ec/ '), 'meet.andina.ec');
        expect(
          DatosDeSala.de(Videollamada.desdeJson({...salaJson(), 'jwt': ''})),
          isNull,
          reason: 'sin token no se entra con el SDK',
        );
      },
    );

    test('el asunto lleva el nombre de la clínica', () {
      expect(
        asuntoDeLaSala('Clínica Andina'),
        'Videoconsulta · Clínica Andina',
      );
      expect(asuntoDeLaSala('  '), 'Videoconsulta');
    });

    test('sin SDK (la web), el navegador integrado, con aviso', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) => salaJson(),
      });
      final sala = _SalaFalsa(disponible: false);
      final navegador = _NavegadorFalso();

      final donde = await VideollamadaEnLaApp(
        VideollamadaService(api.dio),
        sala: sala,
        abrirEnNavegador: navegador.abrir,
      ).unirse('c1');

      expect(donde, SalaAbierta.enElNavegador);
      expect(sala.entradas, isEmpty);
      expect(navegador.abiertas, [
        Uri.parse('https://meet.x.com/cliniq-abc?jwt=t'),
      ]);
    });

    test('si el SDK falla, recién ahí el navegador integrado', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) => salaJson(),
      });

      for (final sala in [
        _SalaFalsa(abre: false),
        _SalaFalsa(error: StateError('sin plataforma')),
      ]) {
        final navegador = _NavegadorFalso();

        final donde = await VideollamadaEnLaApp(
          VideollamadaService(api.dio),
          sala: sala,
          abrirEnNavegador: navegador.abrir,
        ).unirse('c1');

        expect(sala.entradas, hasLength(1));
        expect(donde, SalaAbierta.enElNavegador);
        expect(navegador.abiertas, hasLength(1));
      }
    });

    test('409: el mensaje del servidor, tal cual, sin abrir nada', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) =>
            throw errorHttp(409, 'La sala se abre 15 minutos antes de la cita'),
      });
      final sala = _SalaFalsa();
      final navegador = _NavegadorFalso();

      final video = VideollamadaEnLaApp(
        VideollamadaService(api.dio),
        sala: sala,
        abrirEnNavegador: navegador.abrir,
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
      expect(sala.entradas, isEmpty);
      expect(navegador.abiertas, isEmpty);
    });

    test('503 sin mensaje: se explica que no está disponible', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) => throw errorHttp(503),
      });

      await expectLater(
        VideollamadaEnLaApp(
          VideollamadaService(api.dio),
          sala: _SalaFalsa(),
          abrirEnNavegador: _NavegadorFalso().abrir,
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

    test('en el respaldo, una dirección que no es https no se abre', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) =>
            salaJson(url: 'http://meet.x.com/sala'),
      });
      final navegador = _NavegadorFalso();

      await expectLater(
        VideollamadaEnLaApp(
          VideollamadaService(api.dio),
          sala: _SalaFalsa(disponible: false),
          abrirEnNavegador: navegador.abrir,
        ).unirse('c1'),
        throwsA(isA<ErrorDeVideollamada>()),
      );
      expect(navegador.abiertas, isEmpty);
    });

    test('si tampoco abre el navegador integrado, se dice', () async {
      final api = DioGrabador({
        'GET /portal/citas/c1/videollamada': (_) => salaJson(),
      });

      await expectLater(
        VideollamadaEnLaApp(
          VideollamadaService(api.dio),
          sala: _SalaFalsa(disponible: false),
          abrirEnNavegador: _NavegadorFalso(abre: false).abrir,
        ).unirse('c1'),
        throwsA(
          isA<ErrorDeVideollamada>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('No pudimos abrir la videoconsulta'),
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

  group('Entrar a la sala', () {
    setUp(sondeoConRed);

    Future<void> montar(WidgetTester tester, Widget hijo) async {
      final llavero = AlmacenClavesEnMemoria();
      final auth = AuthBloc(
        servicio: AuthServiceFalso(),
        almacen: AlmacenDeSesion(llavero),
        credenciales: CredencialesService(llavero),
        fijarToken: (_) {},
        restaurarAlCrear: false,
      )..emit(AuthAutenticado(usuarioDePrueba()));
      addTearDown(auth.close);

      await tester.pumpWidget(
        conDatosDeLaClinica(
          BlocProvider.value(
            value: auth,
            child: MaterialApp(
              theme: temaCliniq(),
              home: Scaffold(body: SingleChildScrollView(child: hijo)),
            ),
          ),
        ),
      );
    }

    testWidgets('entra con el nombre de la sesión y el asunto de la clínica', (
      tester,
    ) async {
      final servicio = _VideoFalso();
      await montar(tester, EntrarASala(citaId: 'c1', servicio: servicio));

      await tester.tap(find.byKey(const Key('boton-videoconsulta')));
      await tester.pump();

      expect(servicio.nombresYAsuntos, [
        ('Ana María Pérez', 'Videoconsulta · Clínica Andina'),
      ]);
      expect(find.text(avisoVideoEnElNavegador), findsNothing);
    });

    testWidgets('si se abrió en el navegador integrado, lo avisa', (
      tester,
    ) async {
      await montar(
        tester,
        EntrarASala(
          citaId: 'c1',
          servicio: _VideoFalso(donde: SalaAbierta.enElNavegador),
        ),
      );

      await tester.tap(find.byKey(const Key('boton-videoconsulta')));
      await tester.pump();

      expect(find.text(avisoVideoEnElNavegador), findsOneWidget);
    });
  });

  group('La pantalla de la videoconsulta', () {
    setUp(sondeoConRed);

    Future<void> montar(
      WidgetTester tester, {
      required List<Cita> citas,
      required ServicioVideollamada servicio,
    }) async {
      final bloc = CitasBloc(
        citas: CitasService(DioGrabador().dio, CacheEnMemoria()),
        portal: PortalFalso(),
        recordatorios: ProgramadorFalso(),
        config: configDePrueba,
        catalogos: catalogosDePrueba,
      )..emit(CitasState(citas: citas, carga: CargaCitas.lista));
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
      await tester.pumpAndSettle();
    }

    testWidgets('con la cita, su tarjeta y el botón con su ventana', (
      tester,
    ) async {
      await montar(tester, citas: [cita()], servicio: _VideoFalso());

      expect(find.byType(TarjetaCita), findsOneWidget);
      expect(find.byType(BotonVideoconsulta), findsOneWidget);
    });

    testWidgets('sin la cita, se entra igual y el servidor decide', (
      tester,
    ) async {
      final servicio = _VideoFalso(
        error: const ErrorDeVideollamada('No se encontró la cita.'),
      );
      await montar(tester, citas: const [], servicio: servicio);

      expect(find.byType(TarjetaCita), findsNothing);
      await tester.tap(find.byKey(const Key('boton-videoconsulta')));
      await tester.pump();

      expect(servicio.unidas, ['c1']);
      expect(find.text('No se encontró la cita.'), findsOneWidget);
    });
  });
}

class _VideoFalso implements ServicioVideollamada {
  final ErrorDeVideollamada? error;
  final SalaAbierta donde;
  final List<String> unidas = [];
  final List<(String, String)> nombresYAsuntos = [];

  _VideoFalso({this.error, this.donde = SalaAbierta.enLaAplicacion});

  @override
  bool get disponible => true;

  @override
  Future<SalaAbierta> unirse(
    String citaId, {
    String nombreVisible = '',
    String asunto = '',
  }) async {
    unidas.add(citaId);
    nombresYAsuntos.add((nombreVisible, asunto));
    final e = error;
    if (e != null) throw e;
    return donde;
  }
}

/// El SDK de video, sin plataforma: anota a qué salas se entró.
class _SalaFalsa implements SalaDeVideo {
  @override
  final bool disponible;

  final bool abre;
  final Object? error;
  final List<DatosDeSala> entradas = [];

  _SalaFalsa({this.disponible = true, this.abre = true, this.error});

  @override
  Future<bool> entrar(DatosDeSala datos) async {
    entradas.add(datos);
    final e = error;
    if (e != null) throw e;
    return abre;
  }
}

/// El navegador integrado: anota lo que se abrió.
class _NavegadorFalso {
  final bool abre;
  final List<Uri> abiertas = [];

  _NavegadorFalso({this.abre = true});

  Future<bool> abrir(Uri direccion) async {
    abiertas.add(direccion);
    return abre;
  }
}
