// test/mis_signos_vitales_page_test.dart
//
// «Mis signos vitales» y «Registrar» con dobles, y el acceso desde la
// cita de telemedicina.

import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/ayuda/data/models/ayuda_de_accion.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/citas/presentacion/widgets/detalle_cita.dart';
import 'package:app_cliniq/features/mediciones/data/cola_mediciones.dart';
import 'package:app_cliniq/features/mediciones/data/mediciones_service.dart';
import 'package:app_cliniq/features/mediciones/dominio/destinos_medico.dart';
import 'package:app_cliniq/features/mediciones/presentacion/mis_signos_vitales_page.dart';
import 'package:app_cliniq/features/mediciones/presentacion/registrar_medicion_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/mediciones.dart';
import 'dobles/pantalla.dart';

const _ayuda = {
  'app.mediciones': AyudaDeAccion(
    titulo: 'Mis signos vitales',
    texto: 'Registra los valores de tus aparatos de casa.',
  ),
  'app.escaner': AyudaDeAccion(
    titulo: 'Escáner experimental',
    texto: 'Mide tu pulso con la cámara.',
  ),
};

/// El «ahora» de las tendencias: las mediciones de prueba son del 1 y 2 de
/// octubre de 2026.
final _ahora = DateTime.utc(2026, 10, 3, 15);

void main() {
  setUpAll(() => ZonaClinica.aplicar('America/Guayaquil'));

  late CacheLocal cache;
  late DioGrabador api;
  late bool hayRed;
  late List<Map<String, dynamic>> lista;

  setUp(() {
    sondeoConRed();
    cache = CacheEnMemoria();
    Servicios.cacheParaPruebas = cache;
    hayRed = true;
    lista = [
      medicionJson(id: 'pa1', medidoEn: '2026-10-01T13:00:00.000Z'),
      medicionJson(
        id: 'pa2',
        valor: 135,
        valor2: 88,
        medidoEn: '2026-10-02T13:00:00.000Z',
      ),
      medicionJson(
        id: 'fc1',
        tipo: 'FC',
        valor: 78,
        metodo: 'CAMARA_DEDO',
        calidad: 0.82,
        contexto: null,
        medidoEn: '2026-10-02T14:00:00.000Z',
        usadaEnAtencionId: 'at1',
      ),
    ];
    api = DioGrabador({
      'GET /portal/mediciones': (_) {
        if (!hayRed) throw errorDeRed();
        return {'items': lista, 'total': lista.length, 'page': 1, 'limit': 20};
      },
      'POST /portal/mediciones': (_) {
        if (!hayRed) throw errorDeRed();
        return {'mediciones': <Object>[]};
      },
      'DELETE /portal/mediciones/pa1': (_) => null,
    });
  });

  MedicionesService servicio() => MedicionesService(api.dio, cache);
  ColaMediciones cola() => ColaMediciones(cache, servicio());

  group('Mis signos vitales', () {
    testWidgets('la lista con sus insignias, la evolución de la presión y el '
        '«?»', (tester) async {
      await montarPantalla(
        tester,
        MisSignosVitalesPage(
          servicio: servicio(),
          cola: cola(),
          ahora: () => _ahora,
        ),
        ayuda: _ayuda,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ayuda-app.mediciones')), findsOneWidget);
      expect(find.byKey(const Key('signos-registrar')), findsOneWidget);
      // El escáner viene apagado por defecto: no se ofrece.
      expect(find.byKey(const Key('signos-camara')), findsNothing);
      // Abre en «Tendencias». Dos presiones: hay evolución; un solo pulso:
      // no.
      await tester.scrollUntilVisible(
        find.byKey(const Key('grafico-PA')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('grafico-PA')), findsOneWidget);
      expect(find.byKey(const Key('grafico-FC')), findsNothing);

      // La lista, en «Registro».
      await tester.scrollUntilVisible(
        find.byKey(const Key('pestana-registro')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('pestana-registro')));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.text('135/88 mmHg'), findsWidgets);
      expect(find.text('Cámara · experimental'), findsOneWidget);
      expect(find.text('Calidad buena'), findsOneWidget);
      expect(find.text('Usada en una atención'), findsOneWidget);
      expect(find.text('Aparato de casa'), findsNWidgets(2));
      // La usada no se puede borrar; las otras sí.
      expect(find.byKey(const Key('eliminar-fc1')), findsNothing);
    });

    testWidgets('con el escáner encendido, «Medir con la cámara»', (
      tester,
    ) async {
      await montarPantalla(
        tester,
        MisSignosVitalesPage(servicio: servicio(), cola: cola()),
        config: configDePrueba(telemedicina: {'escanerCamaraActivo': true}),
      );
      await tester.pumpAndSettle();

      expect(find.text('Medir con la cámara (experimental)'), findsOneWidget);
    });

    testWidgets('con las mediciones apagadas por la clínica, no se registra', (
      tester,
    ) async {
      await montarPantalla(
        tester,
        MisSignosVitalesPage(servicio: servicio(), cola: cola()),
        config: configDePrueba(
          telemedicina: {'medicionesPacienteActiva': false},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('signos-registrar')), findsNothing);
      expect(find.textContaining('no tiene activado'), findsOneWidget);
    });

    testWidgets('borrar pregunta antes y llama a DELETE', (tester) async {
      await montarPantalla(
        tester,
        MisSignosVitalesPage(servicio: servicio(), cola: cola()),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pestana-registro')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('eliminar-pa1')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('eliminar-pa1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('eliminar-pa1')));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar esta medición?'), findsOneWidget);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(api.claves, contains('DELETE /portal/mediciones/pa1'));
      expect(find.byKey(const Key('medicion-pa1')), findsNothing);
    });

    testWidgets('sin datos ni copia: el error con «Reintentar»', (
      tester,
    ) async {
      hayRed = false;
      await montarPantalla(
        tester,
        MisSignosVitalesPage(servicio: servicio(), cola: cola()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('Registrar', () {
    Future<void> tocar(WidgetTester tester, Key clave) async {
      await tester.scrollUntilVisible(
        find.byKey(clave),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(clave));
      await tester.pump();
    }

    /// Se abre encima de otra pantalla, como en la aplicación: al guardar
    /// vuelve a ella con el aviso.
    Future<void> abrir(WidgetTester tester, {DestinoMedico? destino}) async {
      await montarPantalla(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) =>
                      RegistrarMedicionPage(cola: cola(), destino: destino),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('el pulso de un aparato, en reposo, ahora', (tester) async {
      await abrir(tester);

      await tester.tap(find.byKey(const Key('tipo-FC')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('registrar-valor')), '78');
      await tocar(tester, const Key('contexto-REPOSO'));
      await tester.scrollUntilVisible(
        find.byKey(const Key('registrar-hora')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ahora'), findsOneWidget);

      await tester.tap(find.byKey(const Key('registrar-guardar')));
      await tester.pumpAndSettle();

      final cuerpo = api.ultimo('POST /portal/mediciones').data as Map;
      final medicion = (cuerpo['mediciones'] as List).single as Map;
      expect(medicion['tipo'], 'FC');
      expect(medicion['valor'], 78);
      expect(medicion['metodo'], 'DISPOSITIVO');
      expect(medicion['contexto'], 'REPOSO');
      expect(medicion.containsKey('unidad'), isFalse);
      expect(find.text('Medición guardada.'), findsOneWidget);
    });

    testWidgets('la presión: la sistólica mayor que la diastólica', (
      tester,
    ) async {
      await abrir(tester);

      await tester.enterText(find.byKey(const Key('registrar-valor')), '90');
      await tester.enterText(find.byKey(const Key('registrar-valor2')), '95');
      await tester.tap(find.byKey(const Key('registrar-guardar')));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('registrar-error')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('registrar-error')), findsOneWidget);
      expect(find.textContaining('mayor que la diastólica'), findsOneWidget);
      expect(api.claves, isNot(contains('POST /portal/mediciones')));
    });

    testWidgets('sin red: queda pendiente en el teléfono y lo dice', (
      tester,
    ) async {
      hayRed = false;
      await abrir(tester);

      await tester.enterText(find.byKey(const Key('registrar-valor')), '128');
      await tester.enterText(find.byKey(const Key('registrar-valor2')), '82');
      await tester.tap(find.byKey(const Key('registrar-guardar')));
      await tester.pumpAndSettle();

      expect(find.textContaining('la guardamos en este teléfono'), findsOne);
      expect(await cola().pendientes('u1'), hasLength(1));
    });

    testWidgets('desde una cita: se comparte con ese médico', (tester) async {
      await abrir(
        tester,
        destino: const DestinoMedico.cita('cita7', titulo: 'Cita del lunes'),
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('registrar-compartir')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('registrar-compartir')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('registrar-valor')), '120');
      await tester.enterText(find.byKey(const Key('registrar-valor2')), '80');
      await tester.tap(find.byKey(const Key('registrar-guardar')));
      await tester.pumpAndSettle();

      final medicion =
          ((api.ultimo('POST /portal/mediciones').data as Map)['mediciones']
                  as List)
              .single;
      expect(medicion['citaId'], 'cita7');
    });
  });

  group('Los accesos', () {
    testWidgets('la cita de telemedicina pendiente ofrece «Mis signos '
        'vitales»; la presencial no', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      final inicio = RelojClinica().ahora().add(const Duration(days: 2));
      Cita cita(TipoCita tipo) => Cita(
        id: 'c1',
        inicio: DateTime(inicio.year, inicio.month, inicio.day, 10),
        fin: DateTime(inicio.year, inicio.month, inicio.day, 10, 20),
        tipo: tipo,
        estado: EstadoCita.programada,
        doctorId: 'doc',
        medico: 'Luis Mora',
      );

      Future<void> montar(TipoCita tipo) => tester.pumpWidget(
        conDatosDeLaClinica(
          key: ValueKey(tipo),
          MaterialApp(
            theme: temaCliniq(),
            home: Scaffold(
              body: Builder(
                builder: (context) =>
                    DetalleCita(cita: cita(tipo), contextoPadre: context),
              ),
            ),
          ),
        ),
      );

      await montar(TipoCita.telemedicina);
      await tester.pump();
      await tester.scrollUntilVisible(
        find.byKey(const Key('cita-signos-vitales')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const Key('cita-signos-vitales')), findsOneWidget);

      await montar(TipoCita.presencial);
      await tester.pump();
      expect(find.byKey(const Key('cita-signos-vitales')), findsNothing);
    });
  });
}
