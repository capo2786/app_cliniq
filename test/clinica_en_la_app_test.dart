// test/clinica_en_la_app_test.dart

import 'package:app_cliniq/core/app/version_instalada.dart';
import 'package:app_cliniq/core/configuracion/config_publica_cubit.dart';
import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/network/api_client.dart';
import 'package:app_cliniq/core/network/interceptor_de_empresa.dart';
import 'package:app_cliniq/core/red/estado_de_la_red.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/tema/paleta_marca.dart';
import 'package:app_cliniq/core/tema/tokens.dart';
import 'package:app_cliniq/features/auth/presentacion/login_page.dart';
import 'package:app_cliniq/features/clinicas/providers/clinica_cubit.dart';
import 'package:app_cliniq/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'dobles/adaptador_http.dart';
import 'dobles/clinica.dart';
import 'dobles/clinicas.dart';

/// La aplicación entera con dos clínicas detrás de la misma API: lo que se
/// pide sin sesión sale con la `X-Empresa` de la clínica guardada, y al
/// cambiar de clínica cambian la marca y los datos.
void main() {
  late AdaptadorHttpFalso api;

  /// La clínica de cada petición, como la resolvería el gateway: la
  /// cabecera o, sin ella, la predeterminada.
  String clinicaDe(RequestOptions o) =>
      o.headers[cabeceraEmpresa]?.toString() ?? 'principal';

  setUp(() {
    ZonaClinica.aplicar('America/Guayaquil');
    Servicios.cacheParaPruebas = CacheEnMemoria();
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Cliniq',
      packageName: 'ec.cliniq.sage.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    VersionInstalada.olvidar();
    SondeoDeRed.olvidarLaInstancia();

    final base = rutasDeLaClinica();
    api = AdaptadorHttpFalso({
      ...base,
      'GET /': (_) => (estado: 200, cuerpo: 'ok'),
      'GET /configuracion/publica': (o) => (
        estado: 200,
        cuerpo: switch (clinicaDe(o)) {
          'sur' => configJson(
            clinica: {
              'nombre': 'Centro Médico del Sur',
              'colorPrimario': '#2E7D32',
              'colorFondo': '#F1F8E9',
            },
          ),
          _ => configJson(),
        },
      ),
      'GET /empresas/publica/sur': (_) =>
          (estado: 200, cuerpo: clinicaDelSur.aJson()),
    });
    ApiClient()
      ..dio.httpClientAdapter = api
      ..token = null;
  });

  tearDown(() {
    EmpresaDeLasPeticiones.codigo = null;
    EmpresaDeLasPeticiones.alNoEstarDisponible = null;
    PaletaMarca.actual = PaletaMarca.deSiempre;
  });

  Future<void> abrir(WidgetTester tester, {bool conAndina = true}) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    if (conAndina) EmpresaDeLasPeticiones.codigo = clinicaAndina.codigo;
    await tester.pumpWidget(
      CliniqApp(clinica: conAndina ? clinicaAndina : null),
    );
    for (var i = 0; i < 20 && find.byType(LoginPage).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, Finder objetivo) async {
    await tester.ensureVisible(objetivo);
    await tester.pumpAndSettle();
    await tester.tap(objetivo);
    await tester.pumpAndSettle();
  }

  testWidgets('sin clínica guardada nada lleva X-Empresa: la predeterminada, '
      'como siempre', (tester) async {
    final cabeceras = <String?>[];
    api.rutas['GET /configuracion/publica'] = (o) {
      cabeceras.add(o.headers[cabeceraEmpresa]?.toString());
      return (estado: 200, cuerpo: configJson());
    };

    await abrir(tester, conAndina: false);

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Clínica Andina'), findsOneWidget);
    expect(cabeceras, isNotEmpty);
    expect(cabeceras.every((c) => c == null), isTrue);
  });

  testWidgets('cambiar de clínica en el acceso trae la marca de la nueva', (
    tester,
  ) async {
    await abrir(tester);
    expect(find.text('Clínica Andina'), findsWidgets);

    await tocar(tester, find.text('Cambiar de clínica'));
    await tester.enterText(
      find.byKey(const Key('campo-codigo-clinica')),
      'sur',
    );
    await tocar(tester, find.byKey(const Key('boton-buscar-clinica')));
    await tocar(tester, find.byKey(const Key('boton-usar-clinica')));
    await tester.pumpAndSettle();

    expect(find.text('Centro Médico del Sur'), findsWidgets);
    expect(find.text('Entrar a Centro Médico del Sur'), findsOneWidget);
    expect(AppColors.primario, const Color(0xFF2E7D32));
    // El fondo claro del panel llega oscurecido a la aplicación.
    expect(AppColors.fondo.computeLuminance(), lessThan(0.05));

    final cubit = tester.element(find.byType(LoginPage)).read<ClinicaCubit>();
    expect(cubit.clinica?.codigo, 'sur');
    expect(cubit.clinica?.nombre, 'Centro Médico del Sur');
    expect(
      await Servicios.almacenDeClinica.leer(),
      isNotNull,
      reason: 'la clínica queda guardada para la próxima vez',
    );
  });

  testWidgets('al entrar se guarda la clínica de la sesión (empresaSesion), '
      'sin confundirla con su empleador', (tester) async {
    api.rutas['POST /auth/login'] = (o) => (
      estado: 200,
      cuerpo: {
        'access_token': 'jwt',
        'user': {
          'uid': 'u1',
          'nombre': 'Ana Pérez',
          'email': 'ana@c.ec',
          'empresa': 'Banco del Pichincha',
          'empresaSesion': {'id': 'e2', 'codigo': 'sur', 'nombre': 'Del Sur'},
          'permisos': ['portal.mis_citas'],
          'legalPendientes': <String>[],
        },
      },
    );
    await abrir(tester);

    await tester.enterText(find.byKey(const Key('campo-correo')), 'ana@c.ec');
    await tester.enterText(find.byKey(const Key('campo-contrasena')), 'x1');
    await tocar(tester, find.byKey(const Key('boton-entrar')));

    final cubit = tester
        .element(find.byType(PuertaDeEntrada))
        .read<ClinicaCubit>();
    expect(cubit.clinica?.codigo, 'sur');
    expect((await Servicios.almacenDeClinica.leer())?.codigo, 'sur');

    expect(EmpresaDeLasPeticiones.codigo, 'sur');
  });

  testWidgets('la clínica guardada se suspendió: se olvida, se avisa una vez '
      'y se sigue con la predeterminada, sin quedarse en «no pudimos '
      'cargar»', (tester) async {
    // El gateway: todo lo que lleva X-Empresa de andina responde 403.
    api.rutas['GET /configuracion/publica'] = (_) => (
      estado: 200,
      cuerpo: configJson(clinica: {'nombre': 'Clínica Principal'}),
    );
    api.rutas.updateAll(
      (_, responder) =>
          (o) => clinicaDe(o) == 'andina'
          ? (estado: 403, cuerpo: cuerpoClinicaNoDisponible)
          : responder(o),
    );
    await Servicios.almacenDeClinica.guardar(clinicaAndina);

    await abrir(tester);

    expect(find.byKey(const Key('sin-datos-de-la-clinica')), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('Entrar a Clínica Principal'), findsOneWidget);
    expect(
      find.text(
        'La clínica «andina» no está disponible por ahora. Consulta con tu '
        'clínica.',
      ),
      findsOneWidget,
    );

    final cubit = tester.element(find.byType(LoginPage)).read<ClinicaCubit>();
    expect(cubit.clinica, isNull);
    expect(cubit.state.cambios, 1);
    expect(EmpresaDeLasPeticiones.codigo, isNull);
    expect(await Servicios.almacenDeClinica.leer(), isNull);

    // Lo que se pide después ya va a la predeterminada, sin X-Empresa.
    final cabeceras = <String?>[];
    final configuracion = api.rutas['GET /configuracion/publica']!;
    api.rutas['GET /configuracion/publica'] = (o) {
      cabeceras.add(o.headers[cabeceraEmpresa]?.toString());
      return configuracion(o);
    };
    await tester.runAsync(
      () => tester
          .element(find.byType(LoginPage))
          .read<ConfigPublicaCubit>()
          .cargar(),
    );
    expect(cabeceras, [null]);
  });
}
