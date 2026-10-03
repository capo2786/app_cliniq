// test/escaner_page_test.dart
//
// El escáner experimental con una fuente de cuadros falsa: el aviso, los
// modos, la medición, el resultado del teléfono y del servidor, guardar,
// enviar al médico, la calidad baja y el rostro.

import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/ayuda/data/models/ayuda_de_accion.dart';
import 'package:app_cliniq/features/mediciones/data/analisis_en_servidor.dart';
import 'package:app_cliniq/features/mediciones/data/cola_mediciones.dart';
import 'package:app_cliniq/features/mediciones/data/mediciones_service.dart';
import 'package:app_cliniq/features/mediciones/dominio/destinos_medico.dart';
import 'package:app_cliniq/features/mediciones/escaner/analizador_de_medicion.dart';
import 'package:app_cliniq/features/mediciones/escaner/aviso_experimental.dart';
import 'package:app_cliniq/features/mediciones/escaner/escaner_page.dart';
import 'package:app_cliniq/features/mediciones/escaner/motor_signos_camara.dart';
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

  group('El escáner experimental', () {
    late FuenteFalsa fuente;

    setUp(() => fuente = FuenteFalsa());

    Future<void> abrir(
      WidgetTester tester, {
      AnalizadorDeMedicion? analizador,
      DestinoMedico? destino,
      bool avisoAceptado = true,
      bool dedoActivo = true,
    }) async {
      final aviso = AvisoDelEscaner(cache);
      if (avisoAceptado) await aviso.aceptar('u1');
      await montarPantalla(
        tester,
        config: configDePrueba(telemedicina: {'escanerDedoActivo': dedoActivo}),
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
      // Las tarjetas del resultado entran y sus números suben.
      await tester.pump(const Duration(seconds: 2));
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
      // Con el dedo encendido por la clínica: primero el rostro.
      final rostro = find.text('Con tu rostro (recomendado)');
      final dedo = find.text('Con el dedo (alternativo)');
      expect(rostro, findsOneWidget);
      expect(dedo, findsOneWidget);
      expect(
        tester.getTopLeft(rostro).dy,
        lessThan(tester.getTopLeft(dedo).dy),
      );
      expect(
        find.text(
          'Cubre con la yema la lente que está junto a la luz que se enciende.',
        ),
        findsOneWidget,
      );
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
      // Nunca presión, saturación, temperatura ni glucosa con la cámara:
      // ni una unidad de esas en las tarjetas de valores (el % del detalle
      // es la calidad y el pNN50, que sí salen de la señal).
      expect(find.textContaining('mmHg'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('escaner-tarjetas')),
          matching: find.textContaining('%'),
        ),
        findsNothing,
      );
      expect(find.textContaining('°C'), findsNothing);
      expect(find.textContaining('mg/dL'), findsNothing);
      expect(find.textContaining('SpO'), findsNothing);
      // La tarjeta honesta lleva a registrarlas con los aparatos.
      expect(find.byKey(const Key('escaner-tarjeta-honesta')), findsOneWidget);
      expect(find.text('En rango (60–100)'), findsOneWidget);
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

      expect(
        tester.widget<Text>(find.byKey(const Key('escaner-fc'))).data,
        '74',
      );
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

    testWidgets('rostro: a pantalla completa con las esquinas, la guía y '
        '«Cancelar»', (tester) async {
      await abrir(tester);
      await tester.tap(find.byKey(const Key('modo-rostro')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('CON TU ROSTRO'), findsOneWidget);
      await tester.tap(find.byKey(const Key('escaner-empezar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('vista-previa-falsa')), findsOneWidget);
      expect(find.byKey(const Key('escaner-esquinas')), findsOneWidget);
      expect(find.text('Signos vitales · Experimental'), findsOneWidget);
      expect(find.text('Escáner experimental'), findsNothing); // sin barra
      fuente.emitir(
        cuadrosDeRostro(
          Sintetizador(26).rostro(lpm: 72, segundos: 3),
          piel: 0.1,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Pon tu cara dentro del marco'), findsOneWidget);
      expect(find.text('Preparando…'), findsOneWidget);
      expect(fuente.abiertas.single.name, 'rostro');

      await tester.tap(find.byKey(const Key('escaner-cancelar')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(fuente.abierta, isFalse);
    });
  });
}
