// test/clinicas_pantallas_test.dart

import 'dart:async';

import 'package:app_cliniq/core/app/version_instalada.dart';
import 'package:app_cliniq/core/network/api_client.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/network/interceptor_de_empresa.dart';
import 'package:app_cliniq/core/storage/almacen_claves.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/storage/credenciales_service.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/auth/data/almacen_de_sesion.dart';
import 'package:app_cliniq/features/auth/data/auth_service.dart';
import 'package:app_cliniq/features/auth/presentacion/login_page.dart';
import 'package:app_cliniq/features/auth/presentacion/registro_page.dart';
import 'package:app_cliniq/features/auth/providers/auth_bloc.dart';
import 'package:app_cliniq/features/auth/providers/auth_state.dart';
import 'package:app_cliniq/features/clinicas/presentacion/hoja_elegir_clinica.dart';
import 'package:app_cliniq/features/clinicas/providers/clinica_cubit.dart';
import 'package:app_cliniq/features/legal/data/legal_service.dart';
import 'package:app_cliniq/features/navegacion/dominio/enlaces_entrantes.dart';
import 'package:app_cliniq/features/navegacion/presentacion/receptor_de_enlaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'dobles/adaptador_http.dart';
import 'dobles/clinica.dart';
import 'dobles/clinicas.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';

/// Las pantallas de las clínicas: elegir una cuando el correo está en
/// varias, cambiar de clínica con su código y el enlace de registro.
void main() {
  late AuthServiceFalso servicio;
  late AlmacenClavesEnMemoria llavero;

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
  });

  tearDown(() => EmpresaDeLasPeticiones.codigo = null);

  Future<ClinicaCubit> montarAcceso(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final bloc = AuthBloc(
      servicio: servicio,
      almacen: AlmacenDeSesion(llavero),
      credenciales: CredencialesService(llavero),
      fijarToken: (_) {},
      restaurarAlCrear: false,
    );
    addTearDown(bloc.close);

    final clinicas = clinicaCubitDePrueba(inicial: clinicaAndina).cubit;
    addTearDown(clinicas.close);

    await tester.pumpWidget(
      conDatosDeLaClinica(
        MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: bloc),
            BlocProvider<ClinicaCubit>.value(value: clinicas),
          ],
          child: MaterialApp(
            theme: temaCliniq(),
            home: LoginPage(
              credenciales: CredencialesService(llavero),
              biometria: BiometriaFalsa(hay: false),
              servicio: servicio,
              legal: LegalService(
                DioGrabador({'GET /legal/documentos': (_) => []}).dio,
                CacheEnMemoria(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    return clinicas;
  }

  Future<void> tocar(WidgetTester tester, Finder objetivo) async {
    await tester.ensureVisible(objetivo);
    await tester.pumpAndSettle();
    await tester.tap(objetivo);
    await tester.pumpAndSettle();
  }

  testWidgets('el correo está en varias clínicas: sale la hoja con sus '
      'nombres y se entra en la elegida', (tester) async {
    servicio.alEntrar = (email, password) async {
      if (servicio.empresas.last == null) {
        throw errorEmpresaAmbigua([clinicaAndina, clinicaDelSur]);
      }
      return AccesoConcedido(token: 'jwt', usuario: usuarioDePrueba());
    };
    await montarAcceso(tester);

    await tester.enterText(find.byKey(const Key('campo-correo')), 'ana@c.ec');
    await tester.enterText(find.byKey(const Key('campo-contrasena')), 'x1');
    await tocar(tester, find.byKey(const Key('boton-entrar')));

    expect(find.byType(HojaElegirClinica), findsOneWidget);
    expect(find.text('¿En qué clínica quieres entrar?'), findsOneWidget);
    expect(find.text('Centro Médico del Sur'), findsOneWidget);
    expect(find.bySemanticsLabel('Entrar a Centro Médico del Sur'), findsOne);

    await tocar(tester, find.byKey(const Key('clinica-sur')));

    expect(find.byType(HojaElegirClinica), findsNothing);
    expect(servicio.empresas, [null, 'sur']);
    expect(
      tester.element(find.byType(LoginPage)).read<AuthBloc>().state,
      isA<AuthAutenticado>(),
    );
  });

  testWidgets('cerrar la hoja sin elegir deja el formulario como estaba', (
    tester,
  ) async {
    servicio.alEntrar = (_, _) async =>
        throw errorEmpresaAmbigua([clinicaAndina, clinicaDelSur]);
    await montarAcceso(tester);

    await tester.enterText(find.byKey(const Key('campo-correo')), 'ana@c.ec');
    await tester.enterText(find.byKey(const Key('campo-contrasena')), 'x1');
    await tocar(tester, find.byKey(const Key('boton-entrar')));
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    expect(find.byType(HojaElegirClinica), findsNothing);
    expect(
      tester.element(find.byType(LoginPage)).read<AuthBloc>().state,
      const AuthNoAutenticado(),
    );
  });

  testWidgets('«Cambiar de clínica»: el código se busca, se ve la clínica '
      'con su nombre y se usa', (tester) async {
    final clinicas = await montarAcceso(tester);

    await tocar(tester, find.text('Cambiar de clínica'));
    expect(find.text('Código de la clínica'), findsOneWidget);
    expect(find.textContaining('Ahora estás en Clínica Andina'), findsOne);

    // Un código que no existe se dice, sin cambiar nada.
    await tester.enterText(
      find.byKey(const Key('campo-codigo-clinica')),
      'nadie',
    );
    await tocar(tester, find.byKey(const Key('boton-buscar-clinica')));
    expect(find.byKey(const Key('error-codigo')), findsOneWidget);
    expect(clinicas.clinica, clinicaAndina);

    // Una suspendida tampoco se usa, y se dice que no está disponible.
    await tester.enterText(
      find.byKey(const Key('campo-codigo-clinica')),
      'cerrada',
    );
    await tocar(tester, find.byKey(const Key('boton-buscar-clinica')));
    expect(
      find.text(
        'La clínica «cerrada» no está disponible por ahora. Consulta con tu '
        'clínica.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('boton-usar-clinica')), findsNothing);
    expect(clinicas.clinica, clinicaAndina);

    await tester.enterText(
      find.byKey(const Key('campo-codigo-clinica')),
      'sur',
    );
    await tocar(tester, find.byKey(const Key('boton-buscar-clinica')));

    expect(find.text('Encontramos tu clínica'), findsOneWidget);
    expect(find.text('Centro Médico del Sur'), findsOneWidget);
    expect(clinicas.clinica, clinicaAndina);

    await tocar(tester, find.byKey(const Key('boton-usar-clinica')));

    expect(find.text('Código de la clínica'), findsNothing);
    expect(clinicas.clinica?.codigo, 'sur');
    expect(clinicas.state.cambios, 1);
    expect(EmpresaDeLasPeticiones.codigo, 'sur');
  });

  testWidgets('«No sé el código» olvida la clínica guardada', (tester) async {
    final clinicas = await montarAcceso(tester);

    await tocar(tester, find.text('Cambiar de clínica'));
    await tocar(tester, find.byKey(const Key('boton-olvidar-clinica')));

    expect(clinicas.clinica, isNull);
    expect(EmpresaDeLasPeticiones.codigo, isNull);
    expect(find.text('¿Tu clínica te dio un código?'), findsOneWidget);
  });

  testWidgets('sin el cubit de la clínica (una pantalla suelta) no hay '
      'botón de cambiar', (tester) async {
    final bloc = AuthBloc(
      servicio: servicio,
      almacen: AlmacenDeSesion(llavero),
      credenciales: CredencialesService(llavero),
      fijarToken: (_) {},
      restaurarAlCrear: false,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      conDatosDeLaClinica(
        BlocProvider<AuthBloc>.value(
          value: bloc,
          child: MaterialApp(
            home: LoginPage(
              credenciales: CredencialesService(llavero),
              biometria: BiometriaFalsa(hay: false),
              servicio: servicio,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byKey(const Key('boton-cambiar-clinica')), findsNothing);
  });

  testWidgets('en el registro se puede cambiar de clínica, y sus documentos '
      'legales se vuelven a pedir con la nueva', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    sondeoConRed();

    final clinicas = clinicaCubitDePrueba(inicial: clinicaAndina).cubit;
    addTearDown(clinicas.close);
    final legal = DioGrabador({'GET /legal/documentos': (_) => []});

    await tester.pumpWidget(
      conDatosDeLaClinica(
        BlocProvider<ClinicaCubit>.value(
          value: clinicas,
          child: MaterialApp(
            theme: temaCliniq(),
            home: RegistroPage(
              servicio: servicio,
              legal: LegalService(legal.dio, CacheEnMemoria()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(legal.pedidos, hasLength(1));

    await tocar(tester, find.text('Cambiar de clínica'));
    await tester.enterText(
      find.byKey(const Key('campo-codigo-clinica')),
      'sur',
    );
    await tocar(tester, find.byKey(const Key('boton-buscar-clinica')));
    await tocar(tester, find.byKey(const Key('boton-usar-clinica')));

    expect(clinicas.clinica?.codigo, 'sur');
    expect(legal.pedidos, hasLength(2));
  });

  group('El enlace de registro de una clínica', () {
    const panel = 'https://cliniq.gcaicedo-proyectos.com';
    EnlaceEntrante? leer(String enlace) =>
        leerEnlaceEntrante(Uri.parse(enlace), panel: panel);

    Future<ClinicaCubit> montarReceptor(
      WidgetTester tester,
      StreamController<Uri> enlaces,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      sondeoConRed();
      Servicios.cacheParaPruebas = CacheEnMemoria();
      ApiClient().dio.httpClientAdapter = AdaptadorHttpFalso({
        'GET /legal/documentos': (_) => (estado: 200, cuerpo: []),
      });

      final clinicas = clinicaCubitDePrueba().cubit;
      addTearDown(clinicas.close);

      await tester.pumpWidget(
        conDatosDeLaClinica(
          BlocProvider<ClinicaCubit>.value(
            value: clinicas,
            child: MaterialApp(
              theme: temaCliniq(),
              home: ReceptorDeEnlaces(
                enlaces: enlaces.stream,
                child: const Scaffold(body: Text('Acceso')),
              ),
            ),
          ),
        ),
      );
      return clinicas;
    }

    testWidgets('abre el registro con la clínica del enlace ya elegida', (
      tester,
    ) async {
      final enlaces = StreamController<Uri>();
      addTearDown(enlaces.close);
      final clinicas = await montarReceptor(tester, enlaces);

      enlaces.add(Uri.parse('$panel/registro?clinica=sur'));
      await tester.pumpAndSettle();

      expect(find.byType(RegistroPage), findsOneWidget);
      expect(clinicas.clinica?.codigo, 'sur');
      expect(EmpresaDeLasPeticiones.codigo, 'sur');
    });

    testWidgets('con un código que no existe lo dice y no abre nada', (
      tester,
    ) async {
      final enlaces = StreamController<Uri>();
      addTearDown(enlaces.close);
      final clinicas = await montarReceptor(tester, enlaces);

      enlaces.add(Uri.parse('$panel/registro?clinica=nadie'));
      await tester.pumpAndSettle();

      expect(find.byType(RegistroPage), findsNothing);
      expect(find.textContaining('«nadie»'), findsOneWidget);
      expect(clinicas.clinica, isNull);
    });

    testWidgets('con una clínica suspendida dice que no está disponible y no '
        'abre nada', (tester) async {
      final enlaces = StreamController<Uri>();
      addTearDown(enlaces.close);
      final clinicas = await montarReceptor(tester, enlaces);

      enlaces.add(Uri.parse('$panel/registro?clinica=cerrada'));
      await tester.pumpAndSettle();

      expect(find.byType(RegistroPage), findsNothing);
      expect(
        find.text(
          'La clínica «cerrada» no está disponible por ahora. Consulta con '
          'tu clínica.',
        ),
        findsOneWidget,
      );
      expect(clinicas.clinica, isNull);
      expect(EmpresaDeLasPeticiones.codigo, isNull);
    });

    test('lleva el código de la clínica; sin él, el registro de siempre', () {
      expect(
        leer('$panel/registro?clinica=demo'),
        const EnlaceRegistro('demo'),
      );
      expect(
        leer('$panel/registro/?clinica=%20Sur%20&utm=qr'),
        const EnlaceRegistro('Sur'),
      );
      expect(leer('$panel/registro'), const EnlaceRegistro(''));
      expect(leer('https://otro.com/registro?clinica=demo'), isNull);
    });
  });
}
