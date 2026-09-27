// test/enlaces_de_correo_test.dart

import 'dart:async';

import 'package:app_cliniq/core/configuracion/config_publica.dart';
import 'package:app_cliniq/core/network/api_client.dart';
import 'package:app_cliniq/core/network/api_interceptor.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/auth/data/auth_service.dart';
import 'package:app_cliniq/features/auth/presentacion/confirmar_correo_page.dart';
import 'package:app_cliniq/features/auth/presentacion/restablecer_page.dart';
import 'package:app_cliniq/features/navegacion/dominio/enlaces_entrantes.dart';
import 'package:app_cliniq/features/navegacion/presentacion/receptor_de_enlaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/adaptador_http.dart';
import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';

/// Los enlaces de los correos (confirmar el correo, crear la contraseña
/// nueva) abren la aplicación y su pantalla nativa, no el panel web.
void main() {
  const panel = 'https://cliniq.gcaicedo-proyectos.com';

  EnlaceEntrante? leer(String enlace, {String panel = panel}) =>
      leerEnlaceEntrante(Uri.parse(enlace), panel: panel);

  group('Qué enlace es', () {
    test('las dos rutas del panel que mandan los correos del API, con su '
        'token', () {
      expect(
        leer('$panel/confirmar-correo?token=a1b2c3'),
        const EnlaceConfirmarCorreo('a1b2c3'),
      );
      expect(
        leer('$panel/restablecer?token=f00d'),
        const EnlaceRestablecer('f00d'),
      );
    });

    test('sin importar la barra final, las mayúsculas del servidor ni otros '
        'datos de la consulta', () {
      expect(
        leer('https://CLINIQ.gcaicedo-proyectos.com/confirmar-correo/?token=x'),
        const EnlaceConfirmarCorreo('x'),
      );
      expect(
        leer('$panel/restablecer?utm=correo&token=y#arriba'),
        const EnlaceRestablecer('y'),
      );
    });

    test('sin token, la pantalla dice que llegó incompleto', () {
      expect(leer('$panel/confirmar-correo'), const EnlaceConfirmarCorreo(''));
      expect(leer('$panel/restablecer?token='), const EnlaceRestablecer(''));
    });

    test('no son suyos: otro servidor, http, otro puerto u otra ruta', () {
      expect(leer('https://otro.com/confirmar-correo?token=a'), isNull);
      expect(
        leer('http://cliniq.gcaicedo-proyectos.com/restablecer?token=a'),
        isNull,
      );
      expect(
        leer('https://cliniq.gcaicedo-proyectos.com:8443/restablecer?token=a'),
        isNull,
      );
      expect(leer('$panel/registro'), isNull);
      expect(leer('$panel/legal/terminos'), isNull);
      expect(leer('$panel/restablecer/otra-cosa?token=a'), isNull);
    });

    test('un panel con ruta base: los enlaces la llevan delante', () {
      const conBase = 'https://clinica.ec/panel';

      expect(
        leer('https://clinica.ec/panel/restablecer?token=z', panel: conBase),
        const EnlaceRestablecer('z'),
      );
      expect(
        leer('https://clinica.ec/restablecer?token=z', panel: conBase),
        isNull,
      );
    });
  });

  group('Lo que se manda al API', () {
    test(
      'confirmar el correo y restablecer la contraseña son públicas',
      () async {
        final api = DioGrabador({
          'POST /auth/registro/confirmar': (_) => {
            'message': 'Tu correo fue confirmado. Ya puedes iniciar sesión.',
          },
          'POST /auth/password/restablecer': (_) => {'message': 'ok'},
        });
        final servicio = AuthService(api.dio);

        expect(
          await servicio.confirmarCorreo('tok-1'),
          'Tu correo fue confirmado. Ya puedes iniciar sesión.',
        );
        await servicio.restablecerContrasena(
          token: 'tok-2',
          nueva: 'Nueva-123',
        );

        final confirmar = api.ultimo('POST /auth/registro/confirmar');
        expect(confirmar.data, {'token': 'tok-1'});
        expect(confirmar.extra[rutaPublica], isTrue);

        final restablecer = api.ultimo('POST /auth/password/restablecer');
        expect(restablecer.data, {
          'token': 'tok-2',
          'newPassword': 'Nueva-123',
        });
        expect(restablecer.extra[rutaPublica], isTrue);
      },
    );
  });

  group('El receptor de enlaces', () {
    late StreamController<Uri> enlaces;
    late AdaptadorHttpFalso api;

    setUp(() {
      sondeoConRed();
      enlaces = StreamController<Uri>();
      api = AdaptadorHttpFalso({
        'POST /auth/registro/confirmar': (_) => (
          estado: 200,
          cuerpo: {
            'message': 'Tu correo fue confirmado. Ya puedes iniciar sesión.',
          },
        ),
      });
      ApiClient().dio.httpClientAdapter = api;
    });

    tearDown(() => enlaces.close());

    Future<void> montar(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        conDatosDeLaClinica(
          MaterialApp(
            theme: temaCliniq(),
            home: ReceptorDeEnlaces(
              enlaces: enlaces.stream,
              child: const Scaffold(body: Text('Acceso')),
            ),
          ),
        ),
      );
    }

    testWidgets('«Confirmar mi correo» abre su pantalla, confirma y deja '
        'ingresar', (tester) async {
      await montar(tester);

      enlaces.add(Uri.parse('$panel/confirmar-correo?token=abc'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmarCorreoPage), findsOneWidget);
      expect(api.pedidas, ['POST /auth/registro/confirmar']);
      expect(find.text('¡Listo! Tu cuenta está activa'), findsOneWidget);
      expect(
        find.text('Tu correo fue confirmado. Ya puedes iniciar sesión.'),
        findsOneWidget,
      );

      // El mismo enlace otra vez, con su pantalla abierta: no se repite.
      enlaces.add(Uri.parse('$panel/confirmar-correo?token=abc'));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmarCorreoPage), findsOneWidget);
      expect(api.pedidas, hasLength(1));

      await tester.tap(find.byKey(const Key('boton-ingresar')));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmarCorreoPage), findsNothing);
      expect(find.text('Acceso'), findsOneWidget);
    });

    testWidgets('«Restablecer contraseña» abre la pantalla de la contraseña '
        'nueva', (tester) async {
      await montar(tester);

      enlaces.add(Uri.parse('$panel/restablecer?token=f00d'));
      await tester.pumpAndSettle();

      expect(find.byType(RestablecerPage), findsOneWidget);
      expect(find.text('Crea una contraseña nueva'), findsOneWidget);
    });

    testWidgets('un enlace que no es de los correos no abre nada', (
      tester,
    ) async {
      await montar(tester);

      enlaces
        ..add(Uri.parse('$panel/registro'))
        ..add(Uri.parse('https://otro.com/restablecer?token=a'));
      await tester.pumpAndSettle();

      expect(find.text('Acceso'), findsOneWidget);
      expect(find.byType(RestablecerPage), findsNothing);
      expect(api.pedidas, isEmpty);
    });
  });

  group('Confirmar el correo', () {
    late AuthServiceFalso servicio;

    setUp(() {
      sondeoConRed();
      servicio = AuthServiceFalso();
    });

    Future<void> montar(WidgetTester tester, String token) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        conDatosDeLaClinica(
          MaterialApp(
            theme: temaCliniq(),
            home: ConfirmarCorreoPage(token: token, servicio: servicio),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('un enlace vencido: el motivo del servidor una vez, y pedir '
        'otro sin registrarse de nuevo', (tester) async {
      servicio.alConfirmar = (_) async => throw errorHttp(
        400,
        'El enlace no es válido o ya venció. Pide uno nuevo.',
      );
      await montar(tester, 'viejo');

      expect(servicio.llamadas, ['confirmar:viejo']);
      expect(find.text('El enlace no es válido o ya venció'), findsOneWidget);
      expect(
        find.text('El enlace no es válido o ya venció. Pide uno nuevo.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('boton-enviar-enlace-nuevo')));
      await tester.pumpAndSettle();
      expect(find.text('Escribe tu correo.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('campo-correo-reenvio')),
        'Ana@Correo.com',
      );
      await tester.tap(find.byKey(const Key('boton-enviar-enlace-nuevo')));
      await tester.pumpAndSettle();

      expect(servicio.llamadas.last, 'reenviar:Ana@Correo.com');
      expect(
        find.textContaining('Si hay una cuenta pendiente con ana@correo.com'),
        findsOneWidget,
      );
    });

    testWidgets('sin token: dice que el enlace llegó incompleto y no llama al '
        'servidor', (tester) async {
      await montar(tester, '');

      expect(find.text('El enlace está incompleto'), findsOneWidget);
      expect(servicio.llamadas, isEmpty);
    });

    testWidgets('sin red: lo dice y el mismo enlace se reintenta', (
      tester,
    ) async {
      var intentos = 0;
      servicio.alConfirmar = (_) async {
        intentos++;
        if (intentos == 1) throw errorDeRed();
        return 'Tu correo fue confirmado. Ya puedes iniciar sesión.';
      };
      await montar(tester, 'abc');

      expect(find.text('No pudimos confirmar tu correo'), findsOneWidget);
      expect(
        find.text('Sin conexión con el servidor. Revisa tu Internet.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('boton-reintentar-confirmacion')));
      await tester.pumpAndSettle();

      expect(find.text('¡Listo! Tu cuenta está activa'), findsOneWidget);
    });
  });

  group('La contraseña nueva', () {
    late AuthServiceFalso servicio;

    setUp(() {
      sondeoConRed();
      servicio = AuthServiceFalso();
    });

    Future<void> montar(
      WidgetTester tester,
      String token, {
      ConfigPublica? config,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        conDatosDeLaClinica(
          config: config,
          MaterialApp(
            theme: temaCliniq(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          RestablecerPage(token: token, servicio: servicio),
                    ),
                  ),
                  child: const Text('Acceso'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Acceso'));
      await tester.pumpAndSettle();
    }

    Future<void> escribir(
      WidgetTester tester,
      String nueva,
      String confirmar,
    ) async {
      await tester.enterText(
        find.byKey(const Key('restablecer-contrasena')),
        nueva,
      );
      await tester.enterText(
        find.byKey(const Key('restablecer-confirmar')),
        confirmar,
      );
      await tester.tap(find.byKey(const Key('boton-guardar-contrasena')));
      await tester.pumpAndSettle();
    }

    testWidgets('las reglas de la clínica antes de enviar: el mínimo y que '
        'coincidan', (tester) async {
      await montar(
        tester,
        'tok',
        config: configDePrueba(seguridad: {'passwordMinimo': 12}),
      );

      expect(find.textContaining('Usa al menos 12 caracteres'), findsOneWidget);

      await escribir(tester, 'Corta-1', 'Otra-1');

      expect(find.text('Debe tener al menos 12 caracteres.'), findsOneWidget);
      expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      expect(servicio.llamadas, isEmpty);
    });

    testWidgets('guardada: POST /auth/password/restablecer con el token y '
        '«Ingresar» vuelve al acceso', (tester) async {
      await montar(tester, 'f00d');

      await escribir(tester, 'Nueva-clave-1', 'Nueva-clave-1');

      expect(servicio.llamadas, ['restablecer:f00d:Nueva-clave-1']);
      expect(find.text('Contraseña actualizada'), findsOneWidget);

      await tester.tap(find.byKey(const Key('boton-ingresar')));
      await tester.pumpAndSettle();

      expect(find.byType(RestablecerPage), findsNothing);
      expect(find.text('Acceso'), findsOneWidget);
    });

    testWidgets('un enlace vencido: el mensaje del servidor una vez y «Pedir '
        'otro enlace» con la hoja de recuperación', (tester) async {
      servicio.alRestablecer = (_, _) async => throw errorHttp(
        400,
        'El enlace no es válido o ya venció. Pide uno nuevo.',
      );
      await montar(tester, 'viejo');

      await escribir(tester, 'Nueva-clave-1', 'Nueva-clave-1');

      expect(
        find.text('El enlace no es válido o ya venció. Pide uno nuevo.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('boton-pedir-otro-enlace')));
      await tester.pumpAndSettle();

      expect(find.text('Recuperar contraseña'), findsOneWidget);
    });

    testWidgets('sin token: «Enlace incompleto» y pedir uno nuevo', (
      tester,
    ) async {
      await montar(tester, '');

      expect(find.text('Enlace incompleto'), findsOneWidget);
      expect(find.byKey(const Key('restablecer-contrasena')), findsNothing);
    });
  });
}
