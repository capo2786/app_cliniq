// test/recorrido_app_test.dart

import 'package:app_cliniq/core/app/version_instalada.dart';
import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/core/network/api_client.dart';
import 'package:app_cliniq/core/red/estado_de_la_red.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/agendar/presentacion/agendar_page.dart';
import 'package:app_cliniq/features/auth/presentacion/login_page.dart';
import 'package:app_cliniq/features/inicio/presentacion/dashboard_page.dart';
import 'package:app_cliniq/features/legal/presentacion/aceptacion_legal_page.dart';
import 'package:app_cliniq/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'dobles/adaptador_http.dart';
import 'dobles/clinica.dart';

import 'package:app_cliniq/core/fechas/zona_clinica.dart';

/// La aplicación entera, de punta a punta, contra una API de mentira.
///
/// No hay teléfono en este entorno, así que esta prueba es lo más cerca de
/// usar la aplicación: arranca, entra, acepta los legales, recorre las
/// pestañas y camina el agendamiento. Si una pantalla lanza al pintarse o se
/// desborda, falla aquí.
void main() {
  // Las horas de la prueba se arman en la zona de la clínica, la misma que
  // la aplicación toma de su configuración.
  ZonaClinica.aplicar('America/Guayaquil');

  late AdaptadorHttpFalso api;
  late bool legalesAceptados;

  // Todo relativo a hoy, para que la prueba valga cualquier día.
  final hoy = RelojClinicaDeHoy.hoy();
  final manana = sumarDias(hoy, 1);
  final pasadoManana = sumarDias(hoy, 2);

  /// Un turno libre como lo manda la API: hora local sin zona.
  Map<String, dynamic> turno(DateTime dia, String inicio, String fin) => {
    'inicio': '${fechaIso(dia)}T$inicio:00',
    'fin': '${fechaIso(dia)}T$fin:00',
  };

  Map<String, dynamic> usuario() => {
    'uid': 'u1',
    'nombre': 'Ana María Pérez',
    'email': 'ana@correo.com',
    'role': 3,
    'roles': ['PACIENTE'],
    'permisos': ['portal.mis_citas', 'portal.agendar', 'portal.dependientes'],
    'legalPendientes': legalesAceptados ? <String>[] : ['TERMINOS'],
    'dosFactores': false,
    'telefono': '0991234567',
    'alergias': 'Penicilina',
  };

  Map<String, dynamic> medico() => {
    'uid': 'doc1',
    'nombre': 'Luis Mora',
    'especialidad': 'Pediatría',
    'ciudad': 'Quito',
    'modalidades': ['PRESENCIAL', 'TELEMEDICINA'],
    'horariosAtencion': [
      for (final dia in [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ])
        {
          'dia': dia,
          'activo': true,
          'rangos': [
            {'inicio': '06:00', 'fin': '22:00'},
          ],
        },
    ],
    'configAgenda': {'duraciones': {}, 'margenMinutos': 0, 'limiteDiario': 0},
    'bloqueos': [],
    'proximo': {...turno(manana, '09:00', '09:30'), 'modalidad': 'PRESENCIAL'},
  };

  setUp(() {
    legalesAceptados = false;

    // Sin disco para Hive en el anfitrión de pruebas: la caché va en memoria.
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

    api = AdaptadorHttpFalso({
      'GET /': (_) =>
          (estado: 200, cuerpo: 'Hello World! Bienvenido a CliniQ API Gateway'),
      'POST /auth/login': (o) {
        final datos = o.data as Map;
        if (datos['password'] != 'secreta1') {
          return (
            estado: 401,
            cuerpo: {
              'status': 401,
              'message': 'Correo o contraseña incorrectos',
            },
          );
        }
        return (
          estado: 200,
          cuerpo: {
            'access_token': 'jwt',
            'expires_in': 28800,
            'user': usuario(),
          },
        );
      },
      'GET /auth/me': (_) => (estado: 200, cuerpo: usuario()),
      'GET /legal/mis-aceptaciones': (_) => (
        estado: 200,
        cuerpo: {
          'aceptaciones': [
            if (legalesAceptados)
              {
                'clave': 'TERMINOS',
                'version': '1.0',
                'aceptadoEn': '2026-09-20T14:00:00.000Z',
              },
          ],
          'pendientes': legalesAceptados
              ? []
              : [
                  {
                    'clave': 'TERMINOS',
                    'version': '1.0',
                    'titulo': 'Términos y condiciones de uso',
                  },
                ],
        },
      ),
      'POST /legal/aceptar': (_) {
        legalesAceptados = true;
        return (
          estado: 200,
          cuerpo: {
            'aceptaciones': [
              {
                'clave': 'TERMINOS',
                'version': '1.0',
                'aceptadoEn': DateTime.now().toUtc().toIso8601String(),
              },
            ],
            'pendientes': [],
          },
        );
      },
      'GET /agenda/paciente/mis-citas': (_) => (
        estado: 200,
        cuerpo: [
          {
            '_id': 'c1',
            'title': 'Ana María Pérez',
            'start': '${fechaIso(pasadoManana)}T10:00:00.000Z',
            'end': '${fechaIso(pasadoManana)}T10:30:00.000Z',
            'type': 'PRESENCIAL',
            'status': 'PROGRAMADA',
            'doctorId': 'doc1',
            'doctorName': 'Luis Mora',
            'doctorSpecialty': 'Pediatría',
            'reason': 'Control',
            'pacienteNombre': 'Ana María Pérez',
            'paraDependiente': false,
          },
          {
            '_id': 'c0',
            'title': 'Tomás Pérez',
            'start': '2026-01-10T09:00:00.000Z',
            'end': '2026-01-10T09:30:00.000Z',
            'type': 'TELEMEDICINA',
            'status': 'ATENDIDA',
            'doctorId': 'doc1',
            'doctorName': 'Luis Mora',
            'pacienteNombre': 'Tomás Pérez',
            'paraDependiente': true,
          },
        ],
      ),
      'GET /portal/dependientes': (_) => (
        estado: 200,
        cuerpo: [
          {
            'uid': 'dep1',
            'nombre': 'Tomás Pérez',
            'tipoDocumento': 'CEDULA',
            'fechaNacimiento': '2018-04-02',
            'parentesco': 'Hijo/a',
          },
        ],
      ),
      ...rutasDeLaClinica(),
      'GET /portal/proximos-turnos': (_) => (
        estado: 200,
        cuerpo: {
          'especialidades': [
            {
              'nombre': 'Pediatría',
              'medicos': 1,
              'proximo': {
                ...turno(manana, '09:00', '09:30'),
                'doctorId': 'doc1',
                'modalidad': 'PRESENCIAL',
              },
            },
          ],
          'medicos': [medico()],
        },
      ),
      'GET /portal/turnos/doc1': (o) => (
        estado: 200,
        cuerpo: {
          'doctorId': 'doc1',
          'modalidad': o.queryParameters['modalidad'],
          'duracion': 30,
          'turnos': [
            turno(manana, '09:00', '09:30'),
            turno(manana, '09:30', '10:00'),
            turno(manana, '15:00', '15:30'),
            turno(pasadoManana, '10:00', '10:30'),
          ],
        },
      ),
      'GET /portal/arco': (_) => (estado: 200, cuerpo: []),
      'GET /portal/encuestas/pendientes': (_) => (estado: 200, cuerpo: []),
      'POST /portal/citas': (o) {
        final datos = o.data as Map;
        return (
          estado: 201,
          cuerpo: {
            '_id': 'nueva',
            'title': 'Tomás Pérez',
            'start': datos['start'],
            'end': datos['end'],
            'type': datos['type'],
            'status': 'PROGRAMADA',
            'doctorId': datos['doctorId'],
            'reason': datos['reason'],
            'doctorName': 'Luis Mora',
            'doctorSpecialty': 'Pediatría',
          },
        );
      },
    });

    ApiClient()
      ..dio.httpClientAdapter = api
      ..token = null;
  });

  Future<void> esperar(WidgetTester tester, [int veces = 6]) async {
    for (var i = 0; i < veces; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> tocar(WidgetTester tester, Finder objetivo) async {
    await tester.ensureVisible(objetivo.first);
    await tester.pump();
    await tester.tap(objetivo.first);
    await esperar(tester);
  }

  /// Baja dentro de la hoja inferior hasta ver lo buscado.
  Future<void> bajarEnLaHoja(WidgetTester tester, Finder buscado) async {
    await tester.scrollUntilVisible(
      buscado,
      200,
      scrollable: find
          .descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await esperar(tester, 2);
  }

  Future<void> recorrer(WidgetTester tester, {double escalaTexto = 1}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final original = FlutterError.onError;
    FlutterError.onError = (detalles) {
      debugPrint('DETALLE: ${detalles.toString()}');
      original?.call(detalles);
    };
    addTearDown(() => FlutterError.onError = original);

    await tester.pumpWidget(const CliniqApp());
    await esperar(tester, 10);

    // 1. Sin sesión guardada: el acceso.
    expect(find.byType(LoginPage), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('campo-correo')),
      'ana@correo.com',
    );
    await tester.enterText(find.byKey(const Key('campo-contrasena')), 'mala');
    await tocar(tester, find.byKey(const Key('boton-entrar')));
    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('campo-contrasena')),
      'secreta1',
    );
    await tocar(tester, find.byKey(const Key('boton-entrar')));
    await esperar(tester, 8);

    // 2. Con un documento pendiente: la aceptación bloquea.
    expect(find.byType(AceptacionLegalPage), findsOneWidget);
    expect(find.text('Términos y condiciones de uso'), findsOneWidget);

    await tocar(tester, find.text('He leído y acepto este documento'));
    await tocar(tester, find.text('Aceptar y continuar'));
    await esperar(tester, 10);

    // 3. El inicio, con la próxima cita y los accesos rápidos.
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Luis Mora'), findsWidgets);
    expect(find.text('Cómo prepararte'), findsOneWidget);
    expect(find.textContaining('Llega 10 minutos antes'), findsOneWidget);

    // 4. Citas: próximas e historial, con el detalle.
    await tocar(tester, find.byKey(const Key('pestana-mis-citas')));
    expect(find.text('Tus citas'), findsOneWidget);
    await tocar(tester, find.text('Luis Mora').last);
    await bajarEnLaHoja(tester, find.text('Cancelar cita'));
    expect(find.text('Reprogramar'), findsOneWidget);
    expect(find.text('Cancelar cita'), findsOneWidget);
    await tester.tapAt(const Offset(20, 40));
    await esperar(tester);

    await tocar(tester, find.text('Historial'));
    expect(find.text('Para Tomás Pérez'), findsOneWidget);

    // 5. Dependientes.
    await tocar(tester, find.byKey(const Key('pestana-mis-dependientes')));
    expect(find.text('Tomás Pérez'), findsOneWidget);

    // 6. Perfil.
    await tocar(tester, find.byKey(const Key('pestana-perfil')));
    expect(find.text('Mi perfil'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Penicilina'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Penicilina'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Documentos aceptados'.toUpperCase()),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await esperar(tester);
    // Aceptado, y también en la lista de documentos de la clínica
    // (`GET /legal/documentos`), con su enlace.
    expect(find.text('Términos y condiciones de uso'), findsNWidgets(2));
    expect(find.byKey(const Key('documento-terminos')), findsOneWidget);

    // Mis derechos sobre mis datos: siempre en el perfil, nativo.
    await tester.scrollUntilVisible(
      find.byKey(const Key('mis-derechos')),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tocar(tester, find.byKey(const Key('mis-derechos')));
    expect(find.text('Mis derechos sobre mis datos'), findsWidgets);
    expect(find.text('Aún no has hecho solicitudes'), findsOneWidget);
    await tocar(tester, find.byTooltip('Atrás'));
    expect(find.text('Aún no has hecho solicitudes'), findsNothing);

    // 7. Agendar, paso a paso hasta los horarios.
    await tocar(tester, find.byKey(const Key('pestana-agendar-cita')));
    await esperar(tester, 8);
    expect(find.byType(AgendarPage), findsOneWidget);
    expect(find.text('¿Para quién?'), findsOneWidget);

    await tocar(tester, find.text('Continuar'));
    expect(find.text('¿Qué necesitas?'), findsOneWidget);
    expect(
      find.text('1 médico · próximo turno mañana a las 09:00'),
      findsNWidgets(2),
      reason: 'el de «Todas las especialidades» y el de Pediatría',
    );
    await tocar(tester, find.text('Pediatría'));
    expect(find.text('Elige al médico'), findsOneWidget);
    expect(find.text('EL PRIMER TURNO DISPONIBLE'), findsOneWidget);

    // La tarjeta del médico, no la del primer turno (que va arriba).
    await tocar(tester, find.text('Luis Mora').last);
    expect(find.text('¿Cómo quieres la consulta?'), findsOneWidget);

    await tocar(tester, find.text('Telemedicina'));
    await esperar(tester, 6);
    expect(find.text('Elige día y hora'), findsOneWidget);
    expect(find.textContaining('horarios libres'), findsOneWidget);

    // El atrás del paso vuelve al anterior, no sale.
    await tocar(tester, find.byTooltip('Atrás'));
    expect(find.text('¿Cómo quieres la consulta?'), findsOneWidget);
    await tocar(tester, find.text('Presencial'));
    await esperar(tester, 6);

    // Elegir la primera hora libre, escribir el motivo y confirmar.
    final ficha = find.byWidgetPredicate(
      (w) => w is Text && RegExp(r'^\d\d:\d\d$').hasMatch(w.data ?? ''),
    );
    await tocar(tester, ficha);
    await tocar(tester, find.text('Continuar'));
    expect(find.text('Motivo de la consulta'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('campo-motivo')),
      'Control anual',
    );
    await esperar(tester, 2);
    await tocar(tester, find.text('Continuar'));
    expect(find.text('Revisa y confirma'), findsOneWidget);

    await tocar(tester, find.text('Confirmar cita'));
    await esperar(tester, 6);
    expect(find.text('¡Cita agendada!'), findsOneWidget);
    expect(api.pedidas, contains('POST /portal/citas'));

    await tocar(tester, find.text('Ver mis citas'));
    await esperar(tester, 6);
    expect(find.byType(AgendarPage), findsNothing);

    // Cancelar: la hoja pide un motivo del catálogo.
    await tocar(tester, find.byKey(const Key('pestana-mis-citas')));
    await tocar(tester, find.text('Próximas'));
    await tocar(tester, find.text('Luis Mora').last);
    await bajarEnLaHoja(tester, find.text('Cancelar cita'));
    await tocar(tester, find.text('Cancelar cita'));
    expect(find.text('¿Cancelar la cita?'), findsOneWidget);
    await tocar(tester, find.text('Cancelar cita').last);
    expect(find.text('Elige el motivo de la cancelación.'), findsOneWidget);
    await tocar(tester, find.text('Mantener la cita'));

    expect(api.pedidas, contains('POST /legal/aceptar'));
    expect(api.pedidas, contains('GET /portal/proximos-turnos'));
    expect(api.pedidas, contains('GET /portal/turnos/doc1'));
    expect(
      api.pedidas.where((p) => p.startsWith('GET /portal/disponibilidad')),
      isEmpty,
      reason: 'los huecos ya no se calculan en la aplicación',
    );
    final excepcion = tester.takeException();
    if (excepcion is FlutterError) debugPrint(excepcion.toStringDeep());
    expect(excepcion, isNull);
  }

  testWidgets(
    'arranca, entra, acepta los legales y recorre la aplicación',
    (tester) => recorrer(tester),
  );

  testWidgets(
    'el mismo recorrido con el texto del sistema agrandado',
    (tester) => recorrer(tester, escalaTexto: 1.3),
  );
}

/// El «hoy» de la clínica para armar los datos de la prueba.
class RelojClinicaDeHoy {
  static DateTime hoy() => RelojClinica().hoy();
}
