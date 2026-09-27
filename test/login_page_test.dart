// test/login_page_test.dart

import 'package:app_cliniq/core/app/version_instalada.dart';
import 'package:app_cliniq/core/storage/almacen_claves.dart';
import 'package:app_cliniq/core/storage/credenciales_service.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/auth/data/almacen_de_sesion.dart';
import 'package:app_cliniq/features/auth/data/auth_service.dart';
import 'package:app_cliniq/features/auth/presentacion/login_page.dart';
import 'package:app_cliniq/features/auth/providers/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'dobles/dobles.dart';

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

  testWidgets('muestra la marca, el formulario, el registro en la clínica y '
      'la versión', (tester) async {
    await montar(tester);

    expect(find.text('Cliniq'), findsOneWidget);
    expect(find.text('Accede a tu cuenta'), findsOneWidget);
    expect(find.byKey(const Key('campo-correo')), findsOneWidget);
    expect(find.byKey(const Key('campo-contrasena')), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
    expect(
      find.text('¿No tienes cuenta? Pide tu registro en la clínica'),
      findsOneWidget,
    );
    expect(find.text('Cliniq v1.0.0 (1)'), findsOneWidget);
    expect(find.text('Entrar con tu huella'), findsNothing);
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
