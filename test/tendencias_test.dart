// test/tendencias_test.dart
//
// «Tendencias» de «Mis signos vitales»: el cálculo puro por tipo y
// periodo, y la pestaña con datos de varios tipos, el cambio de periodo
// (que vuelve a pedir al servidor) y sin red.

import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/mediciones/data/cola_mediciones.dart';
import 'package:app_cliniq/features/mediciones/data/mediciones_service.dart';
import 'package:app_cliniq/features/mediciones/data/models/medicion.dart';
import 'package:app_cliniq/features/mediciones/dominio/tendencias.dart';
import 'package:app_cliniq/features/mediciones/presentacion/mis_signos_vitales_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/mediciones.dart';
import 'dobles/pantalla.dart';

final _ahora = DateTime.utc(2026, 10, 3, 15);

String _haceDias(int dias) =>
    _ahora.subtract(Duration(days: dias)).toIso8601String();

/// Las mediciones de prueba, de varios tipos y fechas.
List<Map<String, dynamic>> _mediciones() => [
  medicionJson(id: 'pa1', valor: 118, valor2: 76, medidoEn: _haceDias(1)),
  medicionJson(id: 'pa2', valor: 135, valor2: 88, medidoEn: _haceDias(3)),
  medicionJson(id: 'pa3', valor: 125, valor2: 82, medidoEn: _haceDias(20)),
  medicionJson(
    id: 'fc1',
    tipo: 'FC',
    valor: 72,
    metodo: 'CAMARA_ROSTRO',
    calidad: 0.8,
    medidoEn: _haceDias(2),
  ),
  medicionJson(id: 'fc2', tipo: 'FC', valor: 80, medidoEn: _haceDias(5)),
  medicionJson(id: 'fc3', tipo: 'FC', valor: 64, medidoEn: _haceDias(60)),
  medicionJson(id: 't1', tipo: 'TEMP', valor: 36.8, medidoEn: _haceDias(4)),
  medicionJson(id: 'g1', tipo: 'GLUCOSA', valor: 95, medidoEn: _haceDias(40)),
];

void main() {
  setUpAll(() => ZonaClinica.aplicar('America/Guayaquil'));

  group('El cálculo de las tendencias', () {
    final mediciones = [for (final j in _mediciones()) Medicion.desdeJson(j)!];

    test('7 días: solo lo del periodo, por tipo y en orden', () {
      final t = calcularTendencias(mediciones, PeriodoTendencia.semana, _ahora);
      expect(t.map((x) => x.tipo), [
        TipoMedicion.fc,
        TipoMedicion.pa,
        TipoMedicion.temp,
      ]);

      final fc = t.first;
      expect(fc.puntos.length, 2);
      expect(fc.ultima.id, 'fc1');
      expect(fc.resumen, (minimo: 72.0, promedio: 76.0, maximo: 80.0));
      // De la más antigua a la más reciente; la de la cámara, marcada.
      expect(fc.puntos.map((p) => p.deCamara), [false, true]);
      expect(fc.conCamara && fc.conAparatos, isTrue);

      final pa = t[1];
      expect(pa.resumen.maximo, 135);
      expect(pa.resumen2, (minimo: 76.0, promedio: 82.0, maximo: 88.0));
      expect(t[2].resumen2, isNull);
    });

    test('3 meses: entra todo; 30 días deja fuera lo más viejo', () {
      final tres = calcularTendencias(
        mediciones,
        PeriodoTendencia.trimestre,
        _ahora,
      );
      expect(tres.first.puntos.length, 3); // FC
      expect(tres.map((x) => x.tipo), contains(TipoMedicion.glucosa));

      final mes = calcularTendencias(mediciones, PeriodoTendencia.mes, _ahora);
      expect(mes.map((x) => x.tipo), isNot(contains(TipoMedicion.glucosa)));
      expect(mes[1].puntos.length, 3); // las tres presiones
    });

    test('sin datos en el periodo: nada (nunca se rellena)', () {
      expect(calcularTendencias(const [], PeriodoTendencia.mes, _ahora), []);
      expect(
        PeriodoTendencia.semana.desde(_ahora),
        DateTime.utc(2026, 9, 26, 15),
      );
    });
  });

  group('La pestaña «Tendencias»', () {
    late CacheLocal cache;
    late DioGrabador api;
    late bool hayRed;

    setUp(() {
      sondeoConRed();
      cache = CacheEnMemoria();
      Servicios.cacheParaPruebas = cache;
      hayRed = true;
      api = DioGrabador({
        'GET /portal/mediciones': (pedido) {
          if (!hayRed) throw errorDeRed();
          final desde = DateTime.tryParse(
            '${pedido.queryParameters['desde'] ?? ''}',
          );
          final items = [
            for (final m in _mediciones())
              if (desde == null ||
                  !DateTime.parse(m['medidoEn'] as String).isBefore(desde))
                m,
          ];
          return {
            'items': items,
            'total': items.length,
            'page': 1,
            'limit': 100,
          };
        },
      });
    });

    Future<void> abrir(WidgetTester tester) async {
      final servicio = MedicionesService(api.dio, cache);
      await montarPantalla(
        tester,
        MisSignosVitalesPage(
          servicio: servicio,
          cola: ColaMediciones(cache, servicio),
          ahora: () => _ahora,
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tocar(WidgetTester tester, Key clave) async {
      await tester.ensureVisible(find.byKey(clave));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(clave));
      await tester.pumpAndSettle();
    }

    Future<void> verHasta(WidgetTester tester, Finder finder) =>
        tester.scrollUntilVisible(
          finder,
          200,
          scrollable: find.byType(Scrollable).first,
        );

    testWidgets('tarjetas de varios tipos, con resumen, franja y leyenda', (
      tester,
    ) async {
      await abrir(tester);

      // Abre en 30 días y lo pide así al servidor.
      final pedido = api.pedidos.lastWhere(
        (p) => p.queryParameters.containsKey('desde'),
      );
      expect(pedido.queryParameters['limit'], 100);
      expect(
        DateTime.parse(pedido.queryParameters['desde'] as String),
        _ahora.subtract(const Duration(days: 30)),
      );

      await verHasta(tester, find.byKey(const Key('tendencias-leyenda')));
      expect(find.text('Cámara (experimental)'), findsOneWidget);
      expect(find.byKey(const Key('tendencia-FC')), findsOneWidget);
      // FC: 72 (cámara) y 80, con su rango.
      expect(find.text('72 lpm'), findsOneWidget);
      expect(find.text('En rango (60–100)'), findsOneWidget);
      await verHasta(tester, find.byKey(const Key('grafico-FC')));
      expect(find.text('Referencia para adultos'), findsWidgets);

      await verHasta(tester, find.byKey(const Key('grafico-PA')));
      expect(find.text('118/76 mmHg'), findsOneWidget);
      expect(find.text('118/76'), findsOneWidget); // el mínimo
      expect(find.text('135/88'), findsOneWidget); // el máximo

      // Una sola temperatura: la tarjeta, sin gráfica.
      await verHasta(tester, find.byKey(const Key('tendencia-TEMP')));
      expect(find.byKey(const Key('grafico-TEMP')), findsNothing);
      expect(find.textContaining('una sola medición'), findsOneWidget);
      expect(find.byKey(const Key('tendencia-GLUCOSA')), findsNothing);
    });

    testWidgets('al cambiar el periodo se vuelve a pedir y cambia', (
      tester,
    ) async {
      await abrir(tester);
      await tocar(tester, const Key('periodo-90'));
      expect(
        DateTime.parse(api.pedidos.last.queryParameters['desde'] as String),
        _ahora.subtract(const Duration(days: 90)),
      );
      await verHasta(tester, find.byKey(const Key('tendencia-GLUCOSA')));
      expect(find.byKey(const Key('tendencia-GLUCOSA')), findsOneWidget);

      await tocar(tester, const Key('periodo-7'));
      expect(find.byKey(const Key('tendencia-GLUCOSA')), findsNothing);
      await verHasta(tester, find.byKey(const Key('tendencia-TEMP')));
      expect(find.byKey(const Key('tendencia-TEMP')), findsOneWidget);
    });

    testWidgets('sin red: lo guardado en el teléfono, y lo dice', (
      tester,
    ) async {
      // Una primera visita con red deja la copia; la segunda, sin red.
      await abrir(tester);
      hayRed = false;
      await tester.pumpWidget(const SizedBox());
      await abrir(tester);

      await verHasta(tester, find.byKey(const Key('tendencia-FC')));
      expect(
        find.textContaining('Sin conexión: la tendencia usa solo lo guardado'),
        findsOneWidget,
      );
    });
  });
}
