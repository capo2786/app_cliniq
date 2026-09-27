// test/recorrido_consultas_test.dart

import 'package:app_cliniq/core/app/version_instalada.dart';
import 'package:app_cliniq/core/archivos/selector_de_archivos.dart';
import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/core/network/api_client.dart';
import 'package:app_cliniq/core/red/estado_de_la_red.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/consultas/presentacion/consultas_page.dart';
import 'package:app_cliniq/features/consultas/presentacion/detalle_consulta_page.dart';
import 'package:app_cliniq/features/consultas/presentacion/nueva_consulta_page.dart';
import 'package:app_cliniq/features/inicio/presentacion/dashboard_page.dart';
import 'package:app_cliniq/main.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'dobles/adaptador_http.dart';
import 'dobles/consultas.dart';

/// Las consultas en línea y la videoconsulta, de punta a punta, con la
/// aplicación entera contra una API de mentira: entrar, ver la sala de la
/// cita de hoy, la lista, una consulta nueva con un archivo, responderle al
/// médico y retomar un borrador. Si una pantalla lanza o se desborda al
/// pintarse, falla aquí.
void main() {
  late AdaptadorHttpFalso api;
  late List<String> camposMultipart;
  late List<Object?> cuerposDeMensajes;

  final ahora = RelojClinica().ahora();
  final inicioVideo = ahora.add(const Duration(minutes: 5));
  final finVideo = inicioVideo.add(const Duration(minutes: 20));

  Map<String, dynamic> usuario() => {
    'uid': 'u1',
    'nombre': 'Ana María Pérez',
    'email': 'ana@correo.com',
    'role': 3,
    'permisos': [
      'portal.mis_citas',
      'portal.agendar',
      'portal.dependientes',
      'portal.consultas',
    ],
    'legalPendientes': <String>[],
  };

  Map<String, dynamic> respondida() => {
    ...consultaJson(
      id: 'c2',
      estado: 'RESPONDIDA',
      puedeEscribir: true,
      ultimoEsMedico: true,
      mensajes: [mensajeJson('m1')],
      adjuntos: [archivoJson('a1', nombre: 'brazo.jpg')],
    ),
    'seguimientoHasta': '2026-10-05T14:00:00.000Z',
  };

  setUp(() {
    camposMultipart = [];
    cuerposDeMensajes = [];

    Servicios.cacheParaPruebas = CacheEnMemoria();
    Servicios.selectorParaPruebas = _SelectorFalso();

    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Cliniq',
      packageName: 'ec.cliniq.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    VersionInstalada.olvidar();
    SondeoDeRed.olvidarLaInstancia();

    api = AdaptadorHttpFalso({
      'GET /': (_) =>
          (estado: 200, cuerpo: 'Hello World! Bienvenido a CliniQ API Gateway'),
      'POST /auth/login': (_) => (
        estado: 200,
        cuerpo: {'access_token': 'jwt', 'expires_in': 28800, 'user': usuario()},
      ),
      'GET /auth/me': (_) => (estado: 200, cuerpo: usuario()),
      'GET /agenda/paciente/mis-citas': (_) => (
        estado: 200,
        cuerpo: [
          {
            '_id': 'c-video',
            'start': '${aTextoLocal(inicioVideo)}.000Z',
            'end': '${aTextoLocal(finVideo)}.000Z',
            'type': 'TELEMEDICINA',
            'status': 'PROGRAMADA',
            'doctorId': 'doc1',
            'doctorName': 'Luis Mora',
            'doctorSpecialty': 'Dermatología',
            'reason': 'Control',
            'pacienteNombre': 'Ana María Pérez',
            'paraDependiente': false,
          },
        ],
      ),
      'GET /portal/citas/c-video/videollamada': (_) => (
        estado: 503,
        cuerpo: {
          'status': 503,
          'message': 'La videoconsulta no está configurada.',
        },
      ),
      'GET /portal/dependientes': (_) => (estado: 200, cuerpo: []),
      'GET /catalogos/lote': (_) => (estado: 200, cuerpo: {}),
      'GET /portal/consultas': (_) => (
        estado: 200,
        cuerpo: [
          {
            ...consultaJson(id: 'b1', estado: 'BORRADOR'),
            'motivoNombre': 'Borrador de lesión',
            'campos': camposLesion,
          },
          {...respondida(), 'motivoNombre': 'Lesión respondida'},
          {
            ...consultaJson(id: 'c3', estado: 'CERRADA'),
            'motivoNombre': 'Consulta vieja',
          },
        ],
      ),
      'GET /portal/consultas/opciones': (_) =>
          (estado: 200, cuerpo: opcionesJson()),
      'POST /portal/consultas': (o) => (
        estado: 201,
        cuerpo: consultaJson(id: 'c-nueva', estado: 'BORRADOR'),
      ),
      'POST /portal/consultas/c-nueva/adjuntos': (o) {
        final formulario = o.data as FormData;
        camposMultipart.addAll(formulario.files.map((f) => f.key));
        return (estado: 201, cuerpo: archivoJson('a9'));
      },
      'POST /portal/consultas/c-nueva/enviar': (_) =>
          (estado: 200, cuerpo: consultaJson(id: 'c-nueva')),
      'GET /portal/consultas/c2': (_) => (estado: 200, cuerpo: respondida()),
      'POST /portal/consultas/c2/mensajes': (o) {
        cuerposDeMensajes.add(o.data);
        final datos = respondida();
        return (
          estado: 200,
          cuerpo: {
            ...datos,
            'mensajes': [
              ...(datos['mensajes'] as List),
              mensajeJson(
                'm2',
                esMedico: false,
                texto: (o.data as Map)['texto'].toString(),
                fecha: '2026-09-28T17:00:00.000Z',
              ),
            ],
          },
        );
      },
      'GET /portal/consultas/b1': (_) => (
        estado: 200,
        cuerpo: consultaJson(
          id: 'b1',
          estado: 'BORRADOR',
          descripcion: 'Empecé a escribir…',
          respuestas: [
            {
              'clave': 'zona',
              'etiqueta': 'Zona del cuerpo',
              'tipo': 'seleccion',
              'valor': 'Cara',
            },
          ],
        ),
      ),
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

  Future<void> recorrer(WidgetTester tester, {double escalaTexto = 1}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    tester.platformDispatcher.textScaleFactorTestValue = escalaTexto;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const CliniqApp());
    await esperar(tester, 10);

    await tester.enterText(
      find.byKey(const Key('campo-correo')),
      'ana@correo.com',
    );
    await tester.enterText(
      find.byKey(const Key('campo-contrasena')),
      'secreta1',
    );
    await tocar(tester, find.byKey(const Key('boton-entrar')));
    await esperar(tester, 10);
    expect(find.byType(DashboardPage), findsOneWidget);

    // 1. La cita de telemedicina de hoy trae su botón, con la sala abierta.
    final video = find.byKey(const Key('boton-videoconsulta'));
    expect(video, findsOneWidget);
    expect(find.textContaining('cámara y el micrófono'), findsOneWidget);
    await tocar(tester, video);
    expect(api.pedidas, contains('GET /portal/citas/c-video/videollamada'));
    expect(find.text('La videoconsulta no está configurada.'), findsOneWidget);

    // 2. Consultas en línea, desde el inicio, avisando de la respuesta.
    expect(find.text('Tienes 1 respuesta del médico'), findsOneWidget);
    await tocar(tester, find.byKey(const Key('acceso-consultas')));
    await esperar(tester, 6);
    expect(find.byType(ConsultasPage), findsOneWidget);
    expect(find.text('BORRADORES'), findsOneWidget);
    expect(find.text('EN CURSO'), findsOneWidget);
    expect(find.text('Respuesta del médico'), findsOneWidget);

    // 3. Una consulta nueva, paso a paso, con un archivo.
    await tocar(tester, find.byKey(const Key('boton-nueva-consulta')));
    await esperar(tester, 6);
    expect(find.byType(NuevaConsultaPage), findsOneWidget);
    expect(find.text('¿Para quién es la consulta?'), findsOneWidget);

    await tocar(tester, find.byKey(const Key('boton-seguir-consulta')));
    expect(find.text('¿Qué especialidad necesitas?'), findsOneWidget);
    await tocar(tester, find.text('Pediatría'));
    expect(find.text('¿Cuál es el motivo?'), findsOneWidget);
    await tocar(tester, find.text('Fiebre'));
    expect(find.text('Elige al médico'), findsOneWidget);
    await tocar(tester, find.text('Dr(a). Rosa Vega'));
    expect(find.text('Cuéntale al médico'), findsOneWidget);

    // Seguir sin responder marca lo que falta.
    await tocar(tester, find.byKey(const Key('boton-seguir-consulta')));
    expect(find.text('Responde esta pregunta.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo-temp')), '38,5');
    await tester.enterText(
      find.byKey(const Key('campo-descripcion')),
      'Fiebre desde anoche, con dolor de garganta.',
    );
    await esperar(tester, 2);
    await tocar(tester, find.byKey(const Key('boton-adjuntar')));
    await tocar(tester, find.text('Elegir archivos'));
    expect(find.text('garganta.jpg'), findsOneWidget);

    await tocar(tester, find.byKey(const Key('boton-seguir-consulta')));
    expect(find.text('Revisa y envía'), findsOneWidget);
    expect(find.text('38,5 °C'), findsOneWidget);

    await tocar(tester, find.byKey(const Key('boton-seguir-consulta')));
    await esperar(tester, 8);
    expect(find.text('¡Consulta enviada!'), findsOneWidget);
    expect(find.text('CA-000123'), findsOneWidget);

    final pedidas = api.pedidas
        .where((p) => p.contains('c-nueva') || p == 'POST /portal/consultas')
        .toList();
    expect(pedidas, [
      'POST /portal/consultas',
      'POST /portal/consultas/c-nueva/adjuntos',
      'POST /portal/consultas/c-nueva/enviar',
    ]);
    expect(camposMultipart, ['archivo']);

    await tocar(tester, find.text('Volver a mis consultas'));
    await esperar(tester, 6);
    expect(find.byType(ConsultasPage), findsOneWidget);

    // 4. Responderle al médico en una consulta respondida.
    await tocar(tester, find.text('Lesión respondida'));
    await esperar(tester, 6);
    expect(find.byType(DetalleConsultaPage), findsOneWidget);
    expect(find.textContaining('Puedes escribirle hasta el'), findsOneWidget);

    // La lista del detalle se arma a medida que se baja.
    final lista = find
        .descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('brazo.jpg'),
      200,
      scrollable: lista,
    );
    await tester.scrollUntilVisible(
      find.text('Es una dermatitis de contacto.'),
      200,
      scrollable: lista,
    );
    await esperar(tester, 2);

    await tester.enterText(
      find.byKey(const Key('campo-mensaje')),
      'Gracias, doctor',
    );
    await tocar(tester, find.byKey(const Key('boton-enviar-mensaje')));
    await esperar(tester, 6);
    expect(cuerposDeMensajes, [
      {'texto': 'Gracias, doctor'},
    ]);
    await tester.scrollUntilVisible(
      find.text('Gracias, doctor'),
      200,
      scrollable: lista,
    );
    expect(find.text('Gracias, doctor'), findsOneWidget);

    await tocar(tester, find.byType(BackButton));
    await esperar(tester, 4);

    // 5. Retomar el borrador: abre en el formulario, con lo guardado.
    await tocar(tester, find.text('Borrador de lesión'));
    await esperar(tester, 8);
    expect(find.text('Tu borrador'), findsOneWidget);
    expect(find.text('Cuéntale al médico'), findsOneWidget);
    expect(find.textContaining('Es un borrador guardado'), findsOneWidget);

    // Sin cambios, salir no pregunta nada.
    await tocar(tester, find.byTooltip('Atrás'));
    await esperar(tester, 4);
    expect(find.byType(NuevaConsultaPage), findsNothing);
    expect(find.byType(ConsultasPage), findsOneWidget);

    final excepcion = tester.takeException();
    if (excepcion is FlutterError) debugPrint(excepcion.toStringDeep());
    expect(excepcion, isNull);
  }

  testWidgets(
    'videoconsulta, lista, consulta nueva, respuesta y borrador',
    (tester) => recorrer(tester),
  );

  testWidgets(
    'lo mismo con el texto del sistema agrandado',
    (tester) => recorrer(tester, escalaTexto: 1.3),
  );
}

/// Hace de cámara, galería y selector de archivos.
class _SelectorFalso implements SelectorDeArchivos {
  SeleccionDeArchivos get _foto =>
      SeleccionDeArchivos(archivos: [fotoLocal('garganta.jpg')]);

  @override
  Future<SeleccionDeArchivos> tomarFoto() async => _foto;

  @override
  Future<SeleccionDeArchivos> elegirFotos() async => _foto;

  @override
  Future<SeleccionDeArchivos> elegirDocumentos() async => _foto;
}
