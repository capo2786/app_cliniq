// test/login_page_test.dart

import 'package:app_cliniq/core/app/version_instalada.dart';
import 'package:app_cliniq/core/storage/almacen_claves.dart';
import 'package:app_cliniq/core/storage/credenciales_service.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/auth/data/almacen_de_sesion.dart';
import 'package:app_cliniq/features/auth/data/auth_service.dart';
import 'package:app_cliniq/features/auth/data/models/usuario.dart';
import 'package:app_cliniq/features/auth/presentacion/login_page.dart';
import 'package:app_cliniq/features/auth/providers/auth_bloc.dart';
import 'package:app_cliniq/features/auth/providers/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'dobles/dobles.dart';
import 'dobles/navegador_falso.dart';

/// La pantalla de acceso, montada con servicios falsos: sin red, sin
/// llavero y sin lector de huellas de verdad.
void main() {
  late AuthServiceFalso servicio;
  late AlmacenClavesEnMemoria llavero;
  late CredencialesService credenciales;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Cliniq',
      packageName: 'ec.cliniq.sage.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    VersionInstalada.olvidar();

    servicio = AuthServiceFalso();
    llavero = AlmacenClavesEnMemoria();
    credenciales = CredencialesService(llavero);
  });

  Future<AuthBloc> montar(
    WidgetTester tester, {
    bool huella = false,
    bool restaurar = false,
  }) async {
    // Un teléfono de tamaño común, para que todo quepa como en la realidad.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final bloc = AuthBloc(
      servicio: servicio,
      almacen: AlmacenDeSesion(llavero),
      credenciales: credenciales,
      fijarToken: (_) {},
      reloj: () => DateTime(2026, 9, 28, 9),
      restaurarAlCrear: restaurar,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: temaCliniq(),
          home: LoginPage(
            credenciales: credenciales,
            biometria: BiometriaFalsa(hay: huella),
            servicio: servicio,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    return bloc;
  }

  Future<void> tocar(WidgetTester tester, Finder boton) async {
    await tester.ensureVisible(boton);
    await tester.pump();
    await tester.tap(boton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('muestra la marca, el formulario, crear cuenta y la versión', (
    tester,
  ) async {
    await montar(tester);

    expect(find.text('Cliniq'), findsOneWidget);
    expect(find.text('Accede a tu cuenta'), findsOneWidget);
    expect(find.byKey(const Key('campo-correo')), findsOneWidget);
    expect(find.byKey(const Key('campo-contrasena')), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(find.text('¿No tienes cuenta?'), findsOneWidget);
    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.textContaining('Pide tu registro'), findsNothing);
    expect(find.text('Cliniq v1.0.0 (1)'), findsOneWidget);
    expect(find.text('Entrar con tu huella'), findsNothing);
  });

  testWidgets('«Crea tu cuenta» abre el registro en el navegador', (
    tester,
  ) async {
    final navegador = NavegadorFalso()..instalar();
    await montar(tester);

    await tocar(tester, find.byKey(const Key('boton-crear-cuenta')));

    expect(navegador.abiertas, [
      'https://cliniq.gcaicedo-proyectos.com/registro',
    ]);
    expect(navegador.ultimaFuera, isTrue);
  });

  testWidgets('si no hay navegador, el aviso deja la dirección a la vista', (
    tester,
  ) async {
    NavegadorFalso(abre: false).instalar();
    await montar(tester);

    await tocar(tester, find.byKey(const Key('boton-crear-cuenta')));

    expect(
      find.textContaining('https://cliniq.gcaicedo-proyectos.com/registro'),
      findsOneWidget,
    );
  });

  testWidgets('una cuenta del personal no entra y se le indica el panel web', (
    tester,
  ) async {
    final navegador = NavegadorFalso()..instalar();
    servicio.alEntrar = (_, _) async => AccesoConcedido(
      token: 'jwt',
      usuario: Usuario({
        'uid': 'm1',
        'permisos': ['agenda.atender'],
      }),
    );
    final bloc = await montar(tester);

    await tester.enterText(
      find.byKey(const Key('campo-correo')),
      'luis@clinica.com',
    );
    await tester.enterText(
      find.byKey(const Key('campo-contrasena')),
      'secreta1',
    );
    await tocar(tester, find.byKey(const Key('boton-entrar')));

    expect(bloc.state, isA<AuthCuentaDelPersonal>());
    expect(
      find.text(
        'Esta aplicación es para pacientes. El personal de la clínica usa el '
        'panel web: https://cliniq.gcaicedo-proyectos.com',
      ),
      findsOneWidget,
    );

    await tocar(tester, find.byKey(const Key('boton-panel-web')));
    expect(navegador.abiertas, ['https://cliniq.gcaicedo-proyectos.com']);
  });

  testWidgets('correo sin confirmar: reenviar el enlace y esperar un minuto '
      'para otro', (tester) async {
    servicio.alEntrar = (_, _) async => throw errorHttp(
      403,
      'Confirma tu correo para ingresar. Revisa tu bandeja o pide un nuevo '
          'enlace.',
      'CORREO_NO_VERIFICADO',
    );
    await montar(tester);

    await tester.enterText(
      find.byKey(const Key('campo-correo')),
      'Ana@Correo.com',
    );
    await tester.enterText(find.byKey(const Key('campo-contrasena')), 'x');
    await tocar(tester, find.byKey(const Key('boton-entrar')));

    expect(find.text('Confirma tu correo para entrar'), findsOneWidget);

    final boton = find.byKey(const Key('boton-reenviar-enlace'));
    bool habilitado() => tester.widget<TextButton>(boton).onPressed != null;

    expect(habilitado(), isTrue);
    await tocar(tester, boton);

    expect(servicio.llamadas.last, 'reenviar:ana@correo.com');
    expect(
      find.textContaining('Si el correo tiene una cuenta pendiente'),
      findsOneWidget,
    );
    expect(habilitado(), isFalse);
    expect(find.textContaining('Reenviar el enlace ('), findsOneWidget);

    await tester.pump(const Duration(seconds: 58));
    expect(habilitado(), isFalse);

    await tester.pump(const Duration(seconds: 2));
    expect(habilitado(), isTrue);
    expect(find.text('Reenviar el enlace'), findsOneWidget);
  });

  testWidgets('si reenviar falla por la red, se dice y no hay que esperar', (
    tester,
  ) async {
    servicio.alEntrar = (_, _) async =>
        throw errorHttp(403, 'Confirma tu correo.', 'CORREO_NO_VERIFICADO');
    servicio.errorAlReenviar = errorDeRed();
    await montar(tester);

    await tester.enterText(
      find.byKey(const Key('campo-correo')),
      'ana@correo.com',
    );
    await tester.enterText(find.byKey(const Key('campo-contrasena')), 'x');
    await tocar(tester, find.byKey(const Key('boton-entrar')));
    await tocar(tester, find.byKey(const Key('boton-reenviar-enlace')));

    expect(find.textContaining('Sin conexión'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('boton-reenviar-enlace')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('sin datos no se envía nada y se dice qué falta', (tester) async {
    await montar(tester);

    await tocar(tester, find.byKey(const Key('boton-entrar')));

    expect(find.text('Ingresa tu correo electrónico.'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
    expect(servicio.llamadas, isEmpty);
  });

  testWidgets('credenciales equivocadas: el aviso aparece en la tarjeta', (
    tester,
  ) async {
    servicio.alEntrar = (_, _) async => throw errorHttp(401, 'x');
    await montar(tester);

    await tester.enterText(
      find.byKey(const Key('campo-correo')),
      'ana@correo.com',
    );
    await tester.enterText(find.byKey(const Key('campo-contrasena')), 'mala');
    await tocar(tester, find.byKey(const Key('boton-entrar')));

    expect(servicio.llamadas, ['login:ana@correo.com']);
    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('cuenta bloqueada: explica los 15 minutos y ofrece recuperar', (
    tester,
  ) async {
    servicio.alEntrar = (_, _) async => throw errorHttp(
      423,
      'Cuenta bloqueada temporalmente por varios intentos fallidos. '
      'Intenta de nuevo en 15 minutos.',
    );
    await montar(tester);

    await tester.enterText(
      find.byKey(const Key('campo-correo')),
      'ana@correo.com',
    );
    await tester.enterText(find.byKey(const Key('campo-contrasena')), 'mala');
    await tocar(tester, find.byKey(const Key('boton-entrar')));

    expect(find.text('Cuenta bloqueada por 15 minutos'), findsOneWidget);
    expect(
      find.textContaining('Intenta de nuevo en 15 minutos'),
      findsOneWidget,
    );
    expect(find.text('Recuperar contraseña'), findsOneWidget);
  });

  testWidgets('con verificación en dos pasos aparece el paso del código', (
    tester,
  ) async {
    servicio.alEntrar = (_, _) async =>
        const SegundoFactorRequerido(desafio: 'd1', destino: 'a***@correo.com');
    await montar(tester);

    await tester.enterText(
      find.byKey(const Key('campo-correo')),
      'ana@correo.com',
    );
    await tester.enterText(
      find.byKey(const Key('campo-contrasena')),
      'secreta1',
    );
    await tocar(tester, find.byKey(const Key('boton-entrar')));

    expect(find.text('Verificación en dos pasos'), findsOneWidget);
    expect(find.textContaining('a***@correo.com'), findsOneWidget);
    expect(find.byKey(const Key('campo-codigo')), findsOneWidget);
  });

  testWidgets('quien ya entró ve el acceso con huella, con el correo puesto '
      'y la contraseña vacía', (tester) async {
    await credenciales.guardar(email: 'ana@correo.com', password: 'secreta1');

    await montar(tester, huella: true);

    expect(find.text('Entrar con tu huella'), findsOneWidget);
    expect(find.text('Entrar con otra cuenta'), findsOneWidget);

    final correo = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('campo-correo')),
        matching: find.byType(EditableText),
      ),
    );
    final contrasena = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('campo-contrasena')),
        matching: find.byType(EditableText),
      ),
    );
    expect(correo.controller.text, 'ana@correo.com');
    expect(contrasena.controller.text, isEmpty);

    // «Entrar con otra cuenta» olvida lo guardado.
    await tocar(tester, find.text('Entrar con otra cuenta'));
    expect(find.text('Entrar con tu huella'), findsNothing);
    expect(await credenciales.leer(), isNull);
  });

  testWidgets('la huella entra con las credenciales guardadas', (tester) async {
    await credenciales.guardar(email: 'ana@correo.com', password: 'secreta1');
    servicio.alEntrar = (_, _) async => throw errorHttp(401);

    await montar(tester, huella: true);
    await tocar(tester, find.text('Entrar con tu huella'));

    expect(servicio.llamadas, ['login:ana@correo.com']);
  });

  testWidgets('la sesión vencida se avisa al llegar al acceso', (tester) async {
    await AlmacenDeSesion(llavero).guardar(
      SesionGuardada(
        token: 'jwt',
        venceEn: DateTime(2026, 9, 28, 8),
        usuario: usuarioDePrueba(),
      ),
    );

    await montar(tester, restaurar: true);

    expect(find.textContaining('Tu sesión venció'), findsOneWidget);
  });
}
