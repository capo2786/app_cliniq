// test/escaner_rostro_test.dart
//
// El escáner con el rostro, de punta a punta sin cámara: imágenes
// sintéticas con una cara cuyo color late a 72 lpm pasan por el procesador
// de verdad, y un detector falso dice dónde está la cara. La vista a
// pantalla completa, la malla, la guía, el arranque solo, la pausa, la FC
// en vivo, el resultado con su detalle y el selector de modo.

import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/mediciones/data/cola_mediciones.dart';
import 'package:app_cliniq/features/mediciones/data/mediciones_service.dart';
import 'package:app_cliniq/features/mediciones/escaner/analizador_de_medicion.dart';
import 'package:app_cliniq/features/mediciones/escaner/aviso_experimental.dart';
import 'package:app_cliniq/features/mediciones/escaner/escaner_page.dart';
import 'package:app_cliniq/features/mediciones/escaner/motor_signos_camara.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/cuadro_de_camara.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/detector_de_rostro.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/rostro_detectado.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/pantalla.dart';
import 'dobles/rostro.dart';
import 'dobles/senales.dart';

/// Lo que el detector falso ve en cada momento.
enum _Cara { ninguna, lejos, girada, bien }

void main() {
  setUpAll(() => ZonaClinica.aplicar('America/Guayaquil'));

  final plantilla = PlantillaDeRostro(
    rostroSintetico(
      cx: 60,
      cy: 70,
      ancho: 65,
      anchoImagen: 120,
      altoImagen: 160,
    ),
  );
  // 40 s de piel que late a 72 lpm (POS la encuentra en el color).
  final pulso = Sintetizador(41).rostro(lpm: 72, segundos: 40, ruido: 0.2);

  late CacheLocal cache;
  late _Cara Function(Duration momento) guion;

  setUp(() {
    sondeoConRed();
    cache = CacheEnMemoria();
    Servicios.cacheParaPruebas = cache;
    guion = (_) => _Cara.bien;
  });

  RostroDetectado? detectar(CuadroDeCamara c) => switch (guion(c.momento)) {
    _Cara.ninguna => null,
    _Cara.lejos => rostroSintetico(
      cx: 60,
      cy: 70,
      ancho: 30,
      anchoImagen: 120,
      altoImagen: 160,
      momento: c.momento,
    ),
    _Cara.girada => rostroSintetico(
      cx: 60,
      cy: 70,
      ancho: 65,
      anguloY: 30,
      anchoImagen: 120,
      altoImagen: 160,
      momento: c.momento,
    ),
    _Cara.bien => rostroSintetico(
      cx: 60,
      cy: 70,
      ancho: 65,
      anchoImagen: 120,
      altoImagen: 160,
      momento: c.momento,
    ),
  };

  /// Los cuadros del índice [desde] al [hasta] de la serie sintética.
  Iterable<CuadroDeCamara> cuadros(int desde, int hasta) sync* {
    for (var i = desde; i < hasta && i < pulso.tiempos.length; i++) {
      yield CuadroDeCamara(
        imagen: plantilla.imagen((
          r: pulso.rojo[i],
          g: pulso.verde[i],
          b: pulso.azul[i],
        )),
        momento: Duration(microseconds: (pulso.tiempos[i] * 1e6).round()),
      );
    }
  }

  /// Abre el escáner y empieza a medir con el rostro.
  Future<FuenteDeImagenesFalsa> empezar(
    WidgetTester tester, {
    CrearDetector? crearDetector,
    int segundos = 30,
  }) async {
    final fuente = FuenteDeImagenesFalsa(
      crearDetector: crearDetector ?? () => DetectorFalso(respuesta: detectar),
    );
    final aviso = AvisoDelEscaner(cache);
    await aviso.aceptar('u1');
    final api = DioGrabador({
      'POST /portal/mediciones': (_) => {'mediciones': <Object>[]},
    });
    await montarPantalla(
      tester,
      config: configDePrueba(telemedicina: {'escanerSegundos': segundos}),
      EscanerPage(
        fuente: fuente,
        cola: ColaMediciones(cache, MedicionesService(api.dio, cache)),
        aviso: aviso,
        analizador: AnalizadorDeMedicion(
          local: const MotorInterno(),
          hayRed: () => false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // Sin el modo dedo: directo a las instrucciones del rostro.
    expect(find.byKey(const Key('modo-dedo')), findsNothing);
    await tester.tap(find.byKey(const Key('escaner-empezar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return fuente;
  }

  /// Emite de [desde] a [hasta] y deja que la pantalla se pinte.
  Future<void> emitir(
    WidgetTester tester,
    FuenteDeImagenesFalsa fuente,
    int desde,
    int hasta,
  ) async {
    fuente.emitir(cuadros(desde, hasta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  double opacidadDeLaMalla(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(const Key('escaner-malla')),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  testWidgets('a pantalla completa: esquinas, barrido y la malla solo con '
      'detección', (tester) async {
    guion = (m) => m < const Duration(seconds: 1) ? _Cara.ninguna : _Cara.bien;
    final fuente = await empezar(tester);
    expect(find.byKey(const Key('vista-previa-falsa')), findsOneWidget);
    expect(find.byKey(const Key('escaner-esquinas')), findsOneWidget);
    expect(find.byKey(const Key('escaner-barrido')), findsOneWidget);

    await emitir(tester, fuente, 0, 20);
    expect(opacidadDeLaMalla(tester), 0);

    await emitir(tester, fuente, 20, 40);
    expect(opacidadDeLaMalla(tester), 1);
    expect(
      find.text(
        'El video se analiza en tu teléfono y nunca se guarda ni se '
        'envía',
      ),
      findsOneWidget,
    );
  });

  testWidgets('sin ML Kit: solo las esquinas y el barrido, sin malla', (
    tester,
  ) async {
    final fuente = await empezar(
      tester,
      crearDetector: () => throw UnsupportedError('sin ML Kit'),
    );
    await emitir(tester, fuente, 0, 30);
    expect(find.byKey(const Key('escaner-malla')), findsNothing);
    expect(find.byKey(const Key('escaner-esquinas')), findsOneWidget);
    expect(find.byKey(const Key('escaner-barrido')), findsOneWidget);
    // El color de la piel dentro del marco basta para la guía.
    expect(find.text('Perfecto, no te muevas'), findsOneWidget);
  });

  testWidgets('la guía cambia según la detección', (tester) async {
    guion = (m) => switch (m.inMilliseconds) {
      < 1000 => _Cara.ninguna,
      < 2000 => _Cara.lejos,
      < 3000 => _Cara.girada,
      _ => _Cara.bien,
    };
    final fuente = await empezar(tester);

    await emitir(tester, fuente, 0, 25);
    expect(find.text('Pon tu cara dentro del marco'), findsOneWidget);
    await emitir(tester, fuente, 25, 55);
    expect(find.text('Acércate un poco'), findsOneWidget);
    await emitir(tester, fuente, 55, 85);
    expect(find.text('Mira de frente a la cámara'), findsOneWidget);
    await emitir(tester, fuente, 85, 100);
    expect(find.text('Perfecto, no te muevas'), findsOneWidget);
  });

  testWidgets('la cuenta no arranca hasta el encuadre y se pausa al perder '
      'el rostro', (tester) async {
    guion = (m) => switch (m.inMilliseconds) {
      < 1500 => _Cara.lejos,
      < 5000 => _Cara.bien,
      < 8000 => _Cara.ninguna,
      _ => _Cara.bien,
    };
    final fuente = await empezar(tester);

    await emitir(tester, fuente, 0, 44); // ~1,5 s lejos
    expect(find.text('Preparando…'), findsOneWidget);
    expect(find.textContaining('Tomando la medición'), findsNothing);

    await emitir(tester, fuente, 44, 150); // ~3,5 s bien: arranca a ~2,5 s
    expect(find.textContaining('Tomando la medición…'), findsOneWidget);

    await emitir(tester, fuente, 150, 225); // 2,5 s sin cara: pausa
    expect(find.textContaining('En pausa ·'), findsOneWidget);
    expect(find.text('Pon tu cara dentro del marco'), findsOneWidget);
    final enPausa = tester
        .widget<Text>(find.byKey(const Key('escaner-cuenta')))
        .data;
    await emitir(tester, fuente, 225, 240);
    expect(
      tester.widget<Text>(find.byKey(const Key('escaner-cuenta'))).data,
      enPausa,
    );

    await emitir(tester, fuente, 240, 300); // vuelve: sigue
    expect(find.textContaining('Tomando la medición…'), findsOneWidget);
  });

  testWidgets('aparece el mosaico de la FC en vivo, con los latidos', (
    tester,
  ) async {
    final fuente = await empezar(tester);
    await emitir(tester, fuente, 0, 150); // arranca a ~1 s; mide ~4 s
    expect(find.byKey(const Key('escaner-fc-vivo')), findsNothing);
    expect(find.text('—'), findsNWidgets(2)); // FC y respiración

    await emitir(tester, fuente, 150, 420); // ~13 s medidos
    final fc = tester.widget<Text>(find.byKey(const Key('escaner-fc-vivo')));
    expect(int.parse(fc.data!), closeTo(72, 4));
    expect(find.text('en vivo'), findsOneWidget);
    expect(find.byKey(const Key('escaner-mini-fc')), findsOneWidget);
    final latidos = tester
        .widget<Text>(find.byKey(const Key('escaner-latidos')))
        .data!;
    expect(int.parse(latidos.split(': ').last), greaterThan(4));
  });

  testWidgets('el resultado: tarjetas, la honesta y el detalle con sus '
      'gráficas (y lo que no alcanza)', (tester) async {
    final fuente = await empezar(tester, segundos: 20);
    for (var i = 0; i < 750; i += 150) {
      await emitir(tester, fuente, i, i + 150);
    }
    await tester.pump(const Duration(seconds: 2));

    final fc = tester.widget<Text>(find.byKey(const Key('escaner-fc')));
    expect(int.parse(fc.data!), closeTo(72, 4));
    expect(find.text('En rango (60–100)'), findsOneWidget);
    expect(find.byKey(const Key('escaner-nivel')), findsOneWidget);
    expect(find.byKey(const Key('escaner-tarjeta-honesta')), findsOneWidget);
    expect(fuente.abierta, isFalse);

    final lista = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('grafica-onda')),
      300,
      scrollable: lista,
    );
    expect(find.text('Detalle calculado en tu teléfono'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('grafica-fc')),
      300,
      scrollable: lista,
    );
    expect(find.text('Referencia para adultos'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('grafica-espectro')),
      300,
      scrollable: lista,
    );
    // 20 s no alcanzan para Poincaré (pide 30 s y buena calidad) ni hay
    // respiración: lo dicen en lugar de inventar.
    await tester.scrollUntilVisible(
      find.text('Respiración'),
      300,
      scrollable: lista,
    );
    expect(
      find.text('No hay suficiente señal para esta gráfica'),
      findsWidgets,
    );
    expect(find.byKey(const Key('grafica-poincare')), findsNothing);
  });
}
