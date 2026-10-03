// test/mediciones_pantallas_test.dart
//
// Las pantallas de las mediciones con dobles: «Mis signos vitales»,
// «Registrar», el escáner experimental con una fuente de cuadros falsa (el
// aviso, los modos, la medición, el resultado del teléfono y del servidor,
// guardar y enviar al médico, no se pudo medir) y los accesos desde la cita.

import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/ayuda/data/models/ayuda_de_accion.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/citas/presentacion/widgets/detalle_cita.dart';
import 'package:app_cliniq/features/mediciones/data/analisis_en_servidor.dart';
import 'package:app_cliniq/features/mediciones/data/cola_mediciones.dart';
import 'package:app_cliniq/features/mediciones/data/mediciones_service.dart';
import 'package:app_cliniq/features/mediciones/dominio/destinos_medico.dart';
import 'package:app_cliniq/features/mediciones/escaner/analizador_de_medicion.dart';
import 'package:app_cliniq/features/mediciones/escaner/aviso_experimental.dart';
import 'package:app_cliniq/features/mediciones/escaner/escaner_page.dart';
import 'package:app_cliniq/features/mediciones/escaner/motor_signos_camara.dart';
import 'package:app_cliniq/features/mediciones/presentacion/mis_signos_vitales_page.dart';
import 'package:app_cliniq/features/mediciones/presentacion/registrar_medicion_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/mediciones.dart';
import 'dobles/pantalla.dart';
import 'dobles/senales.dart';

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
        MisSignosVitalesPage(servicio: servicio(), cola: cola()),
        ayuda: _ayuda,
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ayuda-app.mediciones')), findsOneWidget);
      expect(find.byKey(const Key('signos-registrar')), findsOneWidget);
      // El escáner viene apagado por defecto: no se ofrece.
      expect(find.byKey(const Key('signos-camara')), findsNothing);
      // Dos presiones: hay evolución; un solo pulso: no.
      expect(find.byKey(const Key('grafico-PA')), findsOneWidget);
      expect(find.byKey(const Key('grafico-FC')), findsNothing);

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
      await tester.scrollUntilVisible(
        find.byKey(const Key('eliminar-pa1')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

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

  group('El escáner experimental', () {
    late FuenteFalsa fuente;

    setUp(() => fuente = FuenteFalsa());

    Future<void> abrir(
      WidgetTester tester, {
      AnalizadorDeMedicion? analizador,
      DestinoMedico? destino,
      bool avisoAceptado = true,
    }) async {
      final aviso = AvisoDelEscaner(cache);
      if (avisoAceptado) await aviso.aceptar('u1');
      await montarPantalla(
        tester,
        EscanerPage(
          fuente: fuente,
          cola: cola(),
          aviso: aviso,
          destino: destino,
          analizador:
              analizador ??
              AnalizadorDeMedicion(
                local: const MotorInterno(),
                hayRed: () => false,
              ),
        ),
        ayuda: _ayuda,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> medirConElDedo(WidgetTester tester, Serie serie) async {
      await tester.tap(find.byKey(const Key('modo-dedo')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('CON EL DEDO'), findsOneWidget);
      await tester.tap(find.byKey(const Key('escaner-empezar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('escaner-cuenta')), findsOneWidget);

      fuente.emitir(cuadrosDeDedo(serie));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('la primera vez: el aviso, con el número de emergencias', (
      tester,
    ) async {
      await abrir(tester, avisoAceptado: false);

      expect(find.textContaining('no es un dispositivo médico'), findsOne);
      expect(find.textContaining('llama al 911'), findsOneWidget);
      expect(find.byKey(const Key('ayuda-app.escaner')), findsOneWidget);
      expect(find.byKey(const Key('escaner-privacidad')), findsOneWidget);

      await tester.tap(find.byKey(const Key('escaner-entiendo')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('modo-dedo')), findsOneWidget);
      expect(find.text('Recomendado'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(await AvisoDelEscaner(cache).aceptado('u1'), isTrue);
    });

    testWidgets('dedo: mide, da la FC con su calidad y la guarda', (
      tester,
    ) async {
      await abrir(tester);
      await medirConElDedo(
        tester,
        Sintetizador(21).dedo(lpm: 72, segundos: 31, ruido: 0.1),
      );

      final fc = tester.widget<Text>(find.byKey(const Key('escaner-fc')));
      final valor = int.parse(fc.data!.split(' ').first);
      expect(valor, closeTo(72, 3));
      expect(find.text('Calidad buena'), findsOneWidget);
      expect(find.text('Calculado en el teléfono'), findsOneWidget);
      expect(find.text('Experimental · referencial'), findsOneWidget);
      // Nunca presión, saturación, temperatura ni glucosa con la cámara.
      expect(find.textContaining('mmHg'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('°C'), findsNothing);
      expect(find.textContaining('mg/dL'), findsNothing);
      // Sin cita ni consulta abierta, no hay a quién enviarla.
      expect(find.byKey(const Key('escaner-sin-destino')), findsOneWidget);
      expect(fuente.abierta, isFalse);

      await tester.tap(find.byKey(const Key('escaner-guardar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Guardada en tus signos vitales'), findsOneWidget);

      final medicion =
          ((api.ultimo('POST /portal/mediciones').data as Map)['mediciones']
                  as List)
              .first;
      expect(medicion['metodo'], 'CAMARA_DEDO');
      expect(medicion['notas'], 'motor: interno-ppg v1');
    });

    testWidgets('con red: el resultado del servidor, y lo dice', (
      tester,
    ) async {
      final servidor = DioGrabador({
        'POST /portal/mediciones/analizar': (_) => {
          'fc': 74,
          'fr': 14,
          'vfc': {'sdnn': 52, 'rmssd': 41},
          'calidad': 0.86,
          'motor': 'senales-ms 1.0.0',
          'advertencias': <String>[],
        },
      });
      await abrir(
        tester,
        analizador: AnalizadorDeMedicion(
          local: const MotorInterno(),
          servidor: AnalisisEnServidor(servidor.dio),
          hayRed: () => true,
        ),
      );
      await medirConElDedo(
        tester,
        Sintetizador(22).dedo(lpm: 72, segundos: 31),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('74 lpm'), findsOneWidget);
      expect(find.byKey(const Key('escaner-fr')), findsOneWidget);
      expect(find.byKey(const Key('escaner-vfc')), findsOneWidget);
      expect(
        find.text('Analizado en el servidor (experimental)'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('escaner-guardar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final mediciones =
          (api.ultimo('POST /portal/mediciones').data as Map)['mediciones']
              as List;
      expect(mediciones.map((m) => m['tipo']), ['FC', 'FR']);
      expect(mediciones.first['notas'], 'motor: senales-ms 1.0.0');
    });

    testWidgets('si el servidor falla: el del teléfono', (tester) async {
      final servidor = DioGrabador({
        'POST /portal/mediciones/analizar': (_) => throw errorHttp(503),
      });
      await abrir(
        tester,
        analizador: AnalizadorDeMedicion(
          local: const MotorInterno(),
          servidor: AnalisisEnServidor(servidor.dio),
          hayRed: () => true,
        ),
      );
      await medirConElDedo(
        tester,
        Sintetizador(23).dedo(lpm: 60, segundos: 31),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Calculado en el teléfono'), findsOneWidget);
      expect(servidor.claves, ['POST /portal/mediciones/analizar']);
    });

    testWidgets('«Enviar a mi médico» desde una cita', (tester) async {
      await abrir(
        tester,
        destino: const DestinoMedico.cita(
          'cita3',
          titulo: 'Cita de telemedicina del lunes 5 de octubre, 10:30',
        ),
      );
      await medirConElDedo(
        tester,
        Sintetizador(24).dedo(lpm: 110, segundos: 31),
      );

      await tester.tap(find.byKey(const Key('escaner-enviar-medico')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Enviada a tu médico'), findsOneWidget);
      final medicion =
          ((api.ultimo('POST /portal/mediciones').data as Map)['mediciones']
                  as List)
              .first;
      expect(medicion['citaId'], 'cita3');
    });

    testWidgets('sin la yema sobre la cámara: se detiene con un consejo', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.byKey(const Key('modo-dedo')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('escaner-empezar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      fuente.emitir(
        cuadrosDeDedo(
          Sintetizador(25).dedo(lpm: 72, segundos: 30),
          cobertura: 0.1,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No pudimos medir esta vez'), findsOneWidget);
      expect(find.textContaining('cubre bien la cámara'), findsOneWidget);
      expect(find.byKey(const Key('escaner-reintentar')), findsOneWidget);
      expect(find.byKey(const Key('escaner-fc')), findsNothing);
    });

    testWidgets('rostro: la vista de la cámara con el óvalo y el consejo', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.byKey(const Key('modo-rostro')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('CON EL ROSTRO (BETA)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('escaner-empezar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('vista-previa-falsa')), findsOneWidget);
      fuente.emitir(
        cuadrosDeRostro(
          Sintetizador(26).rostro(lpm: 72, segundos: 3),
          piel: 0.1,
        ),
      );
      await tester.pump();
      expect(find.text('Coloca tu rostro dentro del óvalo'), findsOneWidget);
      expect(fuente.abiertas.single.name, 'rostro');

      await tester.tap(find.byKey(const Key('escaner-cancelar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fuente.abierta, isFalse);
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
