// test/privacidad_test.dart

import 'package:app_cliniq/core/catalogos/catalogo_service.dart';
import 'package:app_cliniq/core/configuracion/config_publica.dart';
import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/storage/almacen_claves.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/storage/credenciales_service.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/auth/data/almacen_de_sesion.dart';
import 'package:app_cliniq/features/auth/providers/auth_bloc.dart';
import 'package:app_cliniq/features/auth/providers/auth_state.dart';
import 'package:app_cliniq/features/privacidad/data/arco_service.dart';
import 'package:app_cliniq/features/privacidad/dominio/reglas_arco.dart';
import 'package:app_cliniq/features/privacidad/presentacion/nueva_solicitud_arco_page.dart';
import 'package:app_cliniq/features/privacidad/presentacion/privacidad_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';

/// Mis derechos sobre mis datos (ARCO): las solicitudes, su plazo y una nueva.
void main() {
  ZonaClinica.aplicar('America/Guayaquil');

  late CacheLocal cache;
  late bool hayRed;
  late List<Map<String, dynamic>> solicitudes;
  late DioGrabador api;
  late Object? Function(Map<dynamic, dynamic> cuerpo) alCrear;

  final ahora = DateTime.now().toUtc();

  Map<String, dynamic> solicitud(
    String id, {
    String tipo = 'RECTIFICACION',
    String estado = 'RECIBIDA',
    Duration creadaHace = const Duration(hours: 2),
    Duration venceEn = const Duration(days: 15),
    bool vencida = false,
    String? respuesta,
  }) => {
    '_id': id,
    'usuarioId': 'u1',
    'usuarioNombre': 'Ana María Pérez',
    'usuarioEmail': 'ana@correo.com',
    'tipo': tipo,
    'detalle': 'Mi segundo apellido está mal escrito: es Pérez, no Peres.',
    'estado': estado,
    'respuesta': ?respuesta,
    'creadaEn': ahora.subtract(creadaHace).toIso8601String(),
    'plazoVence': ahora.add(venceEn).toIso8601String(),
    'vencida': vencida,
    'historial': [
      {
        'fecha': ahora.subtract(creadaHace).toIso8601String(),
        'estado': 'RECIBIDA',
        'porNombre': 'Ana María Pérez',
      },
      if (estado != 'RECIBIDA')
        {
          'fecha': ahora.toIso8601String(),
          'estado': estado,
          'porNombre': 'Delegada de datos',
          'nota': ?respuesta,
        },
    ],
  };

  setUp(() {
    cache = CacheEnMemoria();
    hayRed = true;
    solicitudes = [
      solicitud(
        's1',
        tipo: 'ACCESO',
        estado: 'RESUELTA',
        creadaHace: const Duration(days: 20),
        venceEn: const Duration(days: -5),
        respuesta: 'Te enviamos tus datos por correo.',
      ),
      solicitud('s2'),
    ];
    alCrear = (cuerpo) => solicitud(
      's3',
      tipo: cuerpo['tipo'] as String,
      creadaHace: Duration.zero,
    );
    api = DioGrabador({
      'GET /portal/arco': (_) {
        if (!hayRed) throw errorDeRed();
        return solicitudes;
      },
      'POST /portal/arco': (pedido) => alCrear(pedido.data as Map),
    });
  });

  ArcoService servicio() => ArcoService(api.dio, cache);

  group('El servicio', () {
    test('GET /portal/arco: las mías, con plazo, respuesta e historial, y '
        'guarda la copia de la persona', () async {
      final datos = await servicio().mias('u1');

      final resuelta = datos.solicitudes.first;
      expect(resuelta.tipo, 'ACCESO');
      expect(resuelta.estado, 'RESUELTA');
      expect(resuelta.respuesta, 'Te enviamos tus datos por correo.');
      expect(resuelta.historial.map((p) => p.estado), ['RECIBIDA', 'RESUELTA']);
      expect(resuelta.historial.last.nota, resuelta.respuesta);
      expect(resuelta.plazoVence.isUtc, isTrue);
      expect(datos.desdeCache, isFalse);
      expect(await cache.leer(ArcoService.claveCache('u1')), hasLength(2));
    });

    test('sin red, la copia; al cerrar sesión se va', () async {
      await servicio().mias('u1');
      hayRed = false;

      final copia = await servicio().mias('u1');
      expect(copia.desdeCache, isTrue);
      expect(copia.solicitudes.last.historial, hasLength(1));

      await cache.vaciarDatosPersonales();
      await expectLater(servicio().mias('u1'), throwsA(anything));
    });

    test('POST /portal/arco {tipo, detalle}', () async {
      final creada = await servicio().crear(
        tipo: 'OPOSICION',
        detalle: 'No quiero recordatorios por SMS.',
      );

      expect(api.ultimo('POST /portal/arco').data, {
        'tipo': 'OPOSICION',
        'detalle': 'No quiero recordatorios por SMS.',
      });
      expect(creada.id, 's3');
      expect(creada.estado, 'RECIBIDA');
    });
  });

  group('Las reglas', () {
    test('el detalle: de 10 a 2000 caracteres, sin los espacios de los '
        'extremos', () {
      expect(validarDetalleArco(''), 'Cuéntanos qué necesitas.');
      expect(validarDetalleArco('   corto   '), contains('al menos 10'));
      expect(validarDetalleArco('0123456789'), isNull);
      expect(validarDetalleArco('x' * 2000), isNull);
      expect(validarDetalleArco('x' * 2001), 'Máximo 2000 caracteres.');
    });

    test('vencida: abierta y con el plazo cumplido; una cerrada nunca', () {
      SolicitudArco de(Map<String, dynamic> json) =>
          SolicitudArco.desdeJson(json)!;

      final abierta = de(solicitud('a', venceEn: const Duration(days: 2)));
      final pasada = de(solicitud('b', venceEn: const Duration(hours: -1)));
      final marcada = de(solicitud('c', vencida: true));
      final cerrada = de(
        solicitud(
          'd',
          estado: 'RECHAZADA',
          venceEn: const Duration(days: -3),
          vencida: true,
        ),
      );

      expect(arcoVencida(abierta, ahora), isFalse);
      expect(arcoVencida(pasada, ahora), isTrue);
      expect(arcoVencida(marcada, ahora), isTrue);
      expect(arcoVencida(cerrada, ahora), isFalse);
      expect(arcoCerrada(cerrada), isTrue);
    });

    test('las abiertas primero y, dentro de cada grupo, la más reciente', () {
      final lista = [
        for (final json in [
          solicitud('vieja-cerrada', estado: 'RESUELTA'),
          solicitud('abierta-vieja', creadaHace: const Duration(days: 3)),
          solicitud(
            'nueva-cerrada',
            estado: 'RECHAZADA',
            creadaHace: Duration.zero,
          ),
          solicitud('abierta-nueva', creadaHace: const Duration(minutes: 1)),
        ])
          SolicitudArco.desdeJson(json)!,
      ];

      expect(ordenarSolicitudes(lista).map((s) => s.id), [
        'abierta-nueva',
        'abierta-vieja',
        'nueva-cerrada',
        'vieja-cerrada',
      ]);
    });

    test('el plazo en palabras, en la hora de la clínica', () {
      // El 12 de octubre a las 15:19 UTC son las 10:19 en la clínica.
      final s = SolicitudArco.desdeJson({
        ...solicitud('p'),
        'plazoVence': '2026-10-12T15:19:41.391Z',
      })!;

      expect(
        textoPlazoArco(s, DateTime(2026, 9, 27), vencida: false),
        'Respuesta a más tardar el 12 de octubre (en 15 días).',
      );
      expect(
        textoPlazoArco(s, DateTime(2026, 10, 11, 23), vencida: false),
        contains('(mañana)'),
      );
      expect(
        textoPlazoArco(s, DateTime(2026, 10, 12, 8), vencida: false),
        contains('(hoy)'),
      );
      expect(
        textoPlazoArco(s, DateTime(2026, 10, 13), vencida: true),
        'El plazo de respuesta venció el 12 de octubre.',
      );
    });

    test('los derechos que se ofrecen: los activos de TIPO_ARCO, en su '
        'orden; sin catálogo, todos', () {
      expect(
        catalogosDePrueba().codigosOfrecidos(Catalogos.tipoArco, tiposArco),
        ['ACCESO', 'OPOSICION', 'RECTIFICACION', 'ELIMINACION'],
      );
      expect(
        catalogosDePrueba({Catalogos.tipoArco: []})
            .codigosOfrecidos(Catalogos.tipoArco, tiposArco),
        tiposArco,
      );
    });

    test('el plazo legal sale de la configuración (general.arcoPlazoDias)', () {
      expect(configDePrueba().general.arcoPlazoDias, 15);
      expect(
        configDePrueba(general: {'arcoPlazoDias': 10}).general.arcoPlazoDias,
        10,
      );
      expect(
        () => ConfigPublica.desdeJson(
          configJson(general: {'arcoPlazoDias': null}),
        ),
        throwsFormatException,
      );
    });
  });

  group('La pantalla', () {
    setUp(sondeoConRed);

    final campoDetalle = find.byKey(const Key('campo-detalle-arco'));

    Future<void> escribirDetalle(WidgetTester tester, String texto) async {
      await tester.scrollUntilVisible(
        campoDetalle,
        200,
        scrollable: find
            .descendant(
              of: find.byType(NuevaSolicitudArcoPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(campoDetalle, texto);
    }

    Future<void> montar(WidgetTester tester, {ConfigPublica? config}) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

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
          config: config,
          BlocProvider.value(
            value: auth,
            child: MaterialApp(
              theme: temaCliniq(),
              home: PrivacidadPage(servicio: servicio()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('las solicitudes, con los nombres del catálogo, el plazo, la '
        'respuesta y el historial', (tester) async {
      await montar(
        tester,
        config: configDePrueba(general: {'arcoPlazoDias': 10}),
      );

      expect(
        find.textContaining('tiene 10 días para responderte'),
        findsOneWidget,
      );
      expect(find.text('Rectificación'), findsOneWidget);
      expect(find.text('Recibida'), findsOneWidget);
      expect(find.text('Resuelta'), findsOneWidget);
      expect(find.textContaining('Respuesta a más tardar el'), findsOneWidget);
      expect(find.text('Te enviamos tus datos por correo.'), findsOneWidget);

      // La abierta va primero.
      expect(
        tester.getTopLeft(find.byKey(const Key('solicitud-s2'))).dy,
        lessThan(tester.getTopLeft(find.byKey(const Key('solicitud-s1'))).dy),
      );

      await tester.ensureVisible(find.text('Ver el historial (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver el historial (2)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Delegada de datos'), findsOneWidget);
    });

    testWidgets('sin solicitudes, qué va a pasar cuando envíe una', (
      tester,
    ) async {
      solicitudes = [];
      await montar(tester);

      expect(find.byKey(const Key('sin-solicitudes-arco')), findsOneWidget);
    });

    testWidgets('sin red ni copia, el error con «Reintentar»', (tester) async {
      hayRed = false;
      await montar(tester);

      expect(find.text('No pudimos cargar esto'), findsOneWidget);

      hayRed = true;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Rectificación'), findsOneWidget);
    });

    testWidgets('una nueva: los derechos activos del catálogo con su '
        'descripción, el detalle con sus límites, y vuelve con la solicitud '
        'en la lista', (tester) async {
      await montar(tester);

      await tester.tap(find.byKey(const Key('nueva-solicitud-arco')));
      await tester.pumpAndSettle();
      expect(find.byType(NuevaSolicitudArcoPage), findsOneWidget);

      // Los activos, en su orden, con su explicación; Portabilidad no.
      expect(find.byKey(const Key('derecho-ACCESO')), findsOneWidget);
      expect(find.byKey(const Key('derecho-PORTABILIDAD')), findsNothing);
      expect(
        find.text('Pedir que dejemos de usar tus datos para algo concreto.'),
        findsOneWidget,
      );

      // Un detalle muy corto no se manda.
      await escribirDetalle(tester, 'Corto');
      await tester.tap(find.byKey(const Key('enviar-solicitud-arco')));
      await tester.pumpAndSettle();
      expect(find.textContaining('al menos 10 caracteres'), findsOneWidget);
      expect(api.claves.where((c) => c.startsWith('POST')), isEmpty);

      await tester.ensureVisible(find.byKey(const Key('derecho-OPOSICION')));
      await tester.tap(find.byKey(const Key('derecho-OPOSICION')));
      await escribirDetalle(
        tester,
        '  No quiero recibir recordatorios por mensaje de texto.  ',
      );
      await tester.tap(find.byKey(const Key('enviar-solicitud-arco')));
      await tester.pumpAndSettle();

      expect(api.ultimo('POST /portal/arco').data, {
        'tipo': 'OPOSICION',
        'detalle': 'No quiero recibir recordatorios por mensaje de texto.',
      });
      expect(find.byType(NuevaSolicitudArcoPage), findsNothing);
      expect(find.textContaining('Solicitud enviada'), findsOneWidget);
      expect(find.byKey(const Key('solicitud-s3')), findsOneWidget);
      expect(find.text('Oposición'), findsOneWidget);
    });

    testWidgets('si el servidor no la acepta, su mensaje y el formulario '
        'intacto', (tester) async {
      alCrear = (_) => throw errorHttp(
        400,
        'Describe tu solicitud (entre 10 y 2000 caracteres).',
      );
      await montar(tester);

      await tester.tap(find.byKey(const Key('nueva-solicitud-arco')));
      await tester.pumpAndSettle();
      await escribirDetalle(tester, 'Quiero saber qué datos tienen de mí.');
      await tester.tap(find.byKey(const Key('enviar-solicitud-arco')));
      await tester.pumpAndSettle();

      expect(
        find.text('Describe tu solicitud (entre 10 y 2000 caracteres).'),
        findsOneWidget,
      );
      expect(find.byType(NuevaSolicitudArcoPage), findsOneWidget);
      expect(find.text('Quiero saber qué datos tienen de mí.'), findsOneWidget);
    });
  });
}
