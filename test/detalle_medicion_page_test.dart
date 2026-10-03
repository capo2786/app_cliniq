// test/detalle_medicion_page_test.dart
//
// «Detalle de la medición»: la lógica pura (el caso, la compañera, las
// tarjetas, los datos y el origen) y la pantalla con dobles en los cuatro
// casos (con detalle, de la cámara sin detalle, de un aparato y pendiente
// de envío), los errores (404, sin red con copia y sin ella), el toque en
// la lista que navega (y su semántica de botón), la ruta y eliminar.

import 'dart:math' as math;

import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/mediciones/data/cola_mediciones.dart';
import 'package:app_cliniq/features/mediciones/data/mediciones_service.dart';
import 'package:app_cliniq/features/mediciones/data/models/medicion.dart';
import 'package:app_cliniq/features/mediciones/dominio/detalle_medicion.dart';
import 'package:app_cliniq/features/mediciones/escaner/motor_signos_camara.dart';
import 'package:app_cliniq/features/mediciones/escaner/serie_senal.dart';
import 'package:app_cliniq/features/mediciones/presentacion/detalle/detalle_medicion_page.dart';
import 'package:app_cliniq/features/mediciones/presentacion/detalle/ficha_medicion.dart';
import 'package:app_cliniq/features/mediciones/presentacion/mis_signos_vitales_page.dart';
import 'package:app_cliniq/features/navegacion/dominio/destinos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/mediciones.dart';
import 'dobles/pantalla.dart';
import 'dobles/senales.dart';

late DetalleMedicion _detalle;

/// El pulso de la cámara como lo da la lista (sin el detalle).
Map<String, dynamic> _pulsoEnLista({bool tieneDetalle = true}) => medicionJson(
  id: 'fc1',
  tipo: 'FC',
  valor: 72,
  metodo: 'CAMARA_DEDO',
  calidad: 0.86,
  contexto: 'REPOSO',
  medidoEn: '2026-10-02T14:00:00.000Z',
)..addAll({'notas': 'motor: interno-ppg v1', 'tieneDetalle': tieneDetalle});

/// La respiración del mismo escaneo.
Map<String, dynamic> _respiracionEnLista() => medicionJson(
  id: 'fr1',
  tipo: 'FR',
  valor: 15,
  metodo: 'CAMARA_DEDO',
  calidad: 0.86,
  contexto: 'REPOSO',
  medidoEn: '2026-10-02T14:00:00.000Z',
)..['notas'] = 'motor: interno-ppg v1';

void main() {
  setUpAll(() {
    ZonaClinica.aplicar('America/Guayaquil');
    final serie = SerieSenal.de(
      ModoEscaner.dedo,
      cuadrosDeDedo(
        Sintetizador(91).dedo(lpm: 72, segundos: 31, respiracionRpm: 15),
      ),
    );
    _detalle = const MotorInterno().analizar(serie).detalle!;
  });

  group('La lógica de la pantalla', () {
    final pulso = Medicion.desdeJson(_pulsoEnLista())!;
    final respiracion = Medicion.desdeJson(_respiracionEnLista())!;
    final presion = Medicion.desdeJson(medicionJson(id: 'pa1'))!;

    test('el caso de cada medición', () {
      expect(casoDe(presion), CasoDeDetalle.aparato);
      expect(casoDe(pulso), CasoDeDetalle.detalleSinCargar);
      expect(hayQuePedirla(pulso), isTrue);
      expect(hayQuePedirla(presion), isFalse);
      expect(hayQuePedirla(null), isTrue);
      final anterior = Medicion.desdeJson(_pulsoEnLista(tieneDetalle: false))!;
      expect(casoDe(anterior), CasoDeDetalle.anteriorAlDetalle);
      expect(casoDe(respiracion), CasoDeDetalle.respiracionDeCamara);
      final completa = Medicion.desdeJson(
        _pulsoEnLista()..['detalle'] = _detalle.aJson(),
      )!;
      expect(casoDe(completa), CasoDeDetalle.conDetalle);
      expect(hayQuePedirla(completa), isFalse);
    });

    test('la compañera es la del mismo escaneo', () {
      expect(companeraDe(pulso, [presion, respiracion, pulso]), respiracion);
      expect(companeraDe(respiracion, [pulso]), pulso);
      expect(companeraDe(presion, [pulso, respiracion]), isNull);
      final otraHora = Medicion.desdeJson(
        _respiracionEnLista()..['medidoEn'] = '2026-10-02T15:00:00.000Z',
      )!;
      expect(companeraDe(pulso, [otraHora]), isNull);
    });

    test('las tarjetas: FC y FR del escaneo, la calidad y la variabilidad '
        'del teléfono solo si es válida', () {
      final v = valoresDeTarjetas(pulso, companera: respiracion);
      expect((v.fc, v.fr, v.calidad, v.vfc), (72, 15, 0.86, null));

      final completa = Medicion.desdeJson(
        _pulsoEnLista()..['detalle'] = _detalle.aJson(),
      )!;
      final conVfc = valoresDeTarjetas(completa);
      expect(_detalle.vfcValida, isTrue);
      expect(conVfc.vfc!.rmssd, closeTo(_detalle.metricas!.rmssd, 0.06));
      expect(conVfc.fr, isNull);
    });

    test('el origen, las notas y los datos de un aparato', () {
      expect(
        origenDelAnalisis('motor: senales-ms 1.0.0'),
        'Analizado en el servidor (experimental)',
      );
      expect(
        origenDelAnalisis('motor: interno-pos v1'),
        'Calculado en el '
        'teléfono',
      );
      expect(origenDelAnalisis('Después de caminar'), isNull);
      expect(notasVisibles('motor: interno-ppg v1'), isNull);
      expect(notasVisibles(' Después de caminar '), 'Después de caminar');

      expect(datosDeMedicion(presion), [
        ('Sistólica (la alta)', '128 mmHg'),
        ('Diastólica (la baja)', '82 mmHg'),
        ('Referencia', 'Alta'),
        ('Momento', 'En reposo'),
        ('Cómo se midió', 'Aparato de casa'),
      ]);
    });

    test('un envío pendiente: primero el pulso con su detalle', () {
      final envio = EnvioPendiente(
        idLocal: 'local1',
        creadoEn: DateTime.utc(2026, 10, 3),
        mediciones: [
          MedicionNueva(
            tipo: TipoMedicion.fr,
            valor: 15,
            metodo: MetodoMedicion.camaraDedo,
            medidoEn: DateTime.utc(2026, 10, 3, 15),
          ),
          MedicionNueva(
            tipo: TipoMedicion.fc,
            valor: 72,
            metodo: MetodoMedicion.camaraDedo,
            medidoEn: DateTime.utc(2026, 10, 3, 15),
            detalle: _detalle,
          ),
        ],
      );
      final mediciones = medicionesDelEnvio(envio);
      expect(mediciones.first.tipo, TipoMedicion.fc);
      expect(mediciones.first.detalle, _detalle);
      expect(companeraDe(mediciones.first, mediciones)!.tipo, TipoMedicion.fr);
    });

    test('la ruta /portal/mediciones/:id abre el detalle', () {
      expect(
        destinoDeRuta('/portal/mediciones/fc1'),
        const DestinoNativo(PantallaNativa.medicion, {'id': 'fc1'}),
      );
      expect(
        destinoDeRuta('/portal/mediciones'),
        const DestinoNativo(PantallaNativa.mediciones),
      );
    });
  });

  group('La pantalla', () {
    late CacheLocal cache;
    late DioGrabador api;
    late bool hayRed;
    late List<Map<String, dynamic>> lista;
    late Map<String, dynamic> completa;

    setUp(() {
      sondeoConRed();
      cache = CacheEnMemoria();
      Servicios.cacheParaPruebas = cache;
      hayRed = true;
      completa = _pulsoEnLista()..['detalle'] = _detalle.aJson();
      lista = [
        medicionJson(id: 'pa1', medidoEn: '2026-10-01T13:00:00.000Z'),
        _pulsoEnLista(),
        _respiracionEnLista(),
      ];
      api = DioGrabador({
        'GET /portal/mediciones': (_) {
          if (!hayRed) throw errorDeRed();
          return {'items': lista, 'total': lista.length, 'page': 1};
        },
        'GET /portal/mediciones/fc1': (_) {
          if (!hayRed) throw errorDeRed();
          return completa;
        },
        'DELETE /portal/mediciones/fc1': (_) {
          lista.removeWhere((m) => m['_id'] == 'fc1');
          return null;
        },
      });
    });

    MedicionesService servicio() => MedicionesService(api.dio, cache);
    ColaMediciones cola() => ColaMediciones(cache, servicio());

    /// Abre [pagina] encima de otra, como en la aplicación (al eliminar,
    /// vuelve).
    Future<void> abrirEncima(WidgetTester tester, Widget pagina) async {
      await montarPantalla(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<bool>(builder: (_) => pagina)),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
    }

    /// Baja por la pantalla hasta ver [finder]. Mueve la lista sin
    /// arrastrar: un arrastre que empieza sobre una gráfica no la mueve.
    Future<void> verHasta(WidgetTester tester, Finder finder) async {
      final lista = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
        final p = lista.position;
        p.jumpTo(math.min(p.pixels + 300, p.maxScrollExtent));
        await tester.pump();
      }
      await tester.ensureVisible(finder);
      await tester.pump();
    }

    testWidgets('con detalle: la cabecera, las tarjetas y las seis gráficas '
        'del resultado (abierta solo con su id, como la ruta)', (tester) async {
      await montarPantalla(
        tester,
        DetalleMedicionPage(
          medicionId: 'fc1',
          servicio: servicio(),
          cola: cola(),
        ),
      );
      await tester.pumpAndSettle();

      expect(api.claves, contains('GET /portal/mediciones/fc1'));
      expect(find.text('Detalle de la medición'), findsWidgets);
      expect(find.text('72 lpm'), findsOneWidget);
      expect(find.text('Viernes 2 de octubre de 2026 · 09:00'), findsOneWidget);
      expect(find.text('Cámara · experimental'), findsOneWidget);
      expect(find.text('Calidad buena'), findsWidgets);
      expect(find.text('En reposo'), findsOneWidget);
      expect(find.text('Calculado en el teléfono'), findsOneWidget);
      expect(find.byKey(const Key('escaner-tarjeta-fc')), findsOneWidget);
      expect(find.byKey(const Key('escaner-vfc')), findsOneWidget);

      await verHasta(tester, find.byKey(const Key('grafica-onda')));
      for (final grafica in ['onda', 'fc', 'intervalos', 'poincare']) {
        expect(find.byKey(Key('grafica-$grafica')), findsOneWidget);
      }
      await verHasta(tester, find.byKey(const Key('grafica-respiracion')));
      expect(find.byKey(const Key('grafica-espectro')), findsOneWidget);
      expect(find.text('Detalle calculado en tu teléfono'), findsOneWidget);
      await verHasta(tester, find.byKey(const Key('detalle-eliminar')));
      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('de la cámara sin detalle: las tarjetas que hay y la nota', (
      tester,
    ) async {
      final anterior = Medicion.desdeJson(_pulsoEnLista(tieneDetalle: false))!;
      await montarPantalla(
        tester,
        DetalleMedicionPage(
          medicionId: 'fc1',
          medicion: anterior,
          companera: Medicion.desdeJson(_respiracionEnLista()),
          servicio: servicio(),
          cola: cola(),
        ),
      );
      await tester.pumpAndSettle();

      expect(api.claves, isEmpty);
      expect(find.byKey(const Key('escaner-tarjeta-fc')), findsOneWidget);
      expect(find.byKey(const Key('escaner-fr')), findsOneWidget);
      expect(find.byKey(const Key('escaner-nivel')), findsOneWidget);
      expect(find.byKey(const Key('escaner-vfc')), findsNothing);
      await verHasta(tester, find.byKey(const Key('detalle-anterior')));
      expect(find.text(notaAnteriorAlDetalle), findsOneWidget);
      expect(find.byKey(const Key('escaner-detalle')), findsNothing);
    });

    testWidgets('de un aparato: la cabecera y los datos, sin gráficas', (
      tester,
    ) async {
      final presion = Medicion.desdeJson(
        medicionJson(id: 'pa1')..['notas'] = 'Después de caminar',
      )!;
      await montarPantalla(
        tester,
        DetalleMedicionPage(
          medicionId: 'pa1',
          medicion: presion,
          servicio: servicio(),
          cola: cola(),
        ),
      );
      await tester.pumpAndSettle();

      expect(api.claves, isEmpty);
      expect(find.text('128/82 mmHg'), findsOneWidget);
      expect(find.text('Aparato de casa'), findsWidgets);
      expect(find.text('Después de caminar'), findsOneWidget);
      expect(find.byKey(const Key('detalle-datos')), findsOneWidget);
      expect(find.text('Sistólica (la alta)'), findsOneWidget);
      expect(find.text('Diastólica (la baja)'), findsOneWidget);
      expect(find.byKey(const Key('escaner-tarjetas')), findsNothing);
      expect(find.byKey(const Key('escaner-detalle')), findsNothing);
    });

    testWidgets('pendiente de envío: los datos de la cola, con su detalle', (
      tester,
    ) async {
      hayRed = false;
      final laCola = cola();
      api.rutas['POST /portal/mediciones'] = (_) => throw errorDeRed();
      await tester.runAsync(
        () => laCola.registrar(
          'u1',
          mediciones: [
            MedicionNueva(
              tipo: TipoMedicion.fc,
              valor: 72,
              metodo: MetodoMedicion.camaraRostro,
              calidad: 0.86,
              medidoEn: DateTime.utc(2026, 10, 3, 15),
              notas: 'motor: interno-pos v1',
              detalle: _detalle,
            ),
          ],
        ),
      );
      final envio = (await laCola.pendientes('u1')).single;

      await abrirEncima(
        tester,
        DetalleMedicionPage.pendiente(
          envio,
          servicio: servicio(),
          cola: laCola,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pendiente de envío'), findsOneWidget);
      expect(find.byKey(const Key('detalle-pendiente')), findsOneWidget);
      expect(find.byKey(const Key('escaner-tarjeta-fc')), findsOneWidget);
      await verHasta(tester, find.byKey(const Key('grafica-onda')));
      expect(find.byKey(const Key('grafica-onda')), findsOneWidget);
      expect(api.claves, isNot(contains('GET /portal/mediciones/local')));

      // «Descartar» lo quita de la cola, con su pregunta.
      await verHasta(tester, find.byKey(const Key('detalle-eliminar')));
      await tester.tap(find.byKey(const Key('detalle-eliminar')));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar esta medición?'), findsOneWidget);
      await tester.tap(find.text('Descartar').last);
      await tester.pumpAndSettle();
      expect(await laCola.pendientes('u1'), isEmpty);
      expect(find.text('Medición descartada.'), findsOneWidget);
      expect(find.text('Abrir'), findsOneWidget);
    });

    testWidgets('404: «Esta medición ya no existe»', (tester) async {
      api.rutas['GET /portal/mediciones/fc1'] = (_) => throw errorHttp(404);
      await montarPantalla(
        tester,
        DetalleMedicionPage(
          medicionId: 'fc1',
          servicio: servicio(),
          cola: cola(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Esta medición ya no existe'), findsOneWidget);
      expect(find.byKey(const Key('detalle-cabecera')), findsNothing);
    });

    testWidgets('sin red: la copia guardada; sin copia, el error', (
      tester,
    ) async {
      // Sin copia y sin nada de la lista: el error con «Reintentar».
      hayRed = false;
      await montarPantalla(
        tester,
        DetalleMedicionPage(
          medicionId: 'fc1',
          servicio: servicio(),
          cola: cola(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);

      // Con lo de la lista: la cabecera y las tarjetas, y el aviso.
      await montarPantalla(
        tester,
        DetalleMedicionPage(
          key: const ValueKey('con-lista'),
          medicionId: 'fc1',
          medicion: Medicion.desdeJson(_pulsoEnLista()),
          servicio: servicio(),
          cola: cola(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detalle-cabecera')), findsOneWidget);
      expect(find.byKey(const Key('escaner-tarjeta-fc')), findsOneWidget);
      await verHasta(tester, find.byKey(const Key('detalle-sin-cargar')));
      expect(find.textContaining('Sin conexión'), findsOneWidget);

      // Abierta antes con red: la copia, sin red.
      hayRed = true;
      await tester.runAsync(() => servicio().obtener('u1', 'fc1'));
      hayRed = false;
      await montarPantalla(
        tester,
        DetalleMedicionPage(
          key: const ValueKey('con-copia'),
          medicionId: 'fc1',
          servicio: servicio(),
          cola: cola(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Mostramos la copia guardada'), findsOne);
      expect(find.byKey(const Key('escaner-detalle')), findsOneWidget);
    });

    testWidgets('en «Registro», cada medición es un botón con flecha que '
        'abre su detalle; eliminar vuelve y refresca', (tester) async {
      final semantica = tester.ensureSemantics();
      await montarPantalla(
        tester,
        MisSignosVitalesPage(servicio: servicio(), cola: cola()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pestana-registro')));
      await tester.pumpAndSettle();

      final tarjeta = find.byKey(const Key('medicion-fc1'));
      await verHasta(tester, tarjeta);
      expect(
        find.descendant(
          of: tarjeta,
          matching: find.byIcon(Icons.chevron_right_rounded),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(tarjeta),
        isSemantics(isButton: true, hint: 'Ver el detalle de la medición'),
      );
      semantica.dispose();

      final pedidasAntes = api.claves
          .where((c) => c == 'GET /portal/mediciones')
          .length;
      await tester.tap(find.text('72 lpm'));
      await tester.pumpAndSettle();
      expect(api.claves, contains('GET /portal/mediciones/fc1'));
      expect(find.byKey(const Key('detalle-cabecera')), findsOneWidget);
      // La respiración del mismo escaneo va en las tarjetas.
      expect(find.byKey(const Key('escaner-fr')), findsOneWidget);

      await verHasta(tester, find.byKey(const Key('detalle-eliminar')));
      await tester.tap(find.byKey(const Key('detalle-eliminar')));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar esta medición?'), findsOneWidget);
      await tester.tap(find.text('Eliminar').last);
      await tester.pumpAndSettle();

      expect(api.claves, contains('DELETE /portal/mediciones/fc1'));
      expect(find.byKey(const Key('detalle-cabecera')), findsNothing);
      expect(find.text('Medición eliminada.'), findsOneWidget);
      expect(
        api.claves.where((c) => c == 'GET /portal/mediciones').length,
        greaterThan(pedidasAntes),
      );
      expect(find.byKey(const Key('medicion-fc1')), findsNothing);
    });
  });
}
