// test/campo_dinamico_test.dart

import 'dart:typed_data';

import 'package:app_cliniq/core/archivos/archivo_meta.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/consultas/data/models/campo_formulario.dart';
import 'package:app_cliniq/features/consultas/presentacion/widgets/campo_dinamico.dart';
import 'package:app_cliniq/features/consultas/presentacion/widgets/visor_imagen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cada tipo de pregunta del formulario pinta su control y devuelve el
/// valor con el tipo que espera la API.
void main() {
  late List<Object?> valores;

  setUp(() => valores = []);

  Future<void> montar(
    WidgetTester tester,
    CampoFormulario campo, {
    Object? valor,
    String? error,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: temaCliniq(),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: CampoDinamico(
              campo: campo,
              valor: valor,
              error: error,
              alCambiar: valores.add,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('texto: la etiqueta con asterisco si es requerida y el texto '
      'tal cual', (tester) async {
    await montar(
      tester,
      const CampoFormulario(
        clave: 'forma',
        etiqueta: 'Forma',
        tipo: TipoCampo.texto,
        requerido: true,
        ayuda: 'Redonda, alargada…',
      ),
    );

    expect(find.text('Forma *'), findsOneWidget);
    expect(find.text('Redonda, alargada…'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo-forma')), 'Redonda');
    expect(valores.last, 'Redonda');
  });

  testWidgets('número: con su unidad al lado y el error dentro del campo', (
    tester,
  ) async {
    await montar(
      tester,
      const CampoFormulario(
        clave: 'temp',
        etiqueta: 'Temperatura',
        tipo: TipoCampo.numero,
        unidad: '°C',
      ),
      valor: 38.5,
      error: 'Escribe solo un número (en °C).',
    );

    expect(find.text('°C'), findsOneWidget);
    expect(find.text('38,5'), findsOneWidget, reason: 'con coma decimal');
    expect(find.text('Escribe solo un número (en °C).'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campo-temp')), '39abc');
    expect(valores.last, '39', reason: 'solo cifras, coma, punto o signo');
  });

  testWidgets('sí o no: dos fichas', (tester) async {
    await montar(
      tester,
      const CampoFormulario(
        clave: 'pica',
        etiqueta: '¿Pica?',
        tipo: TipoCampo.siNo,
        requerido: true,
      ),
      error: 'Responde esta pregunta.',
    );

    expect(find.text('Responde esta pregunta.'), findsOneWidget);

    await tester.tap(find.text('No'));
    expect(valores.last, false);
    await tester.tap(find.text('Sí'));
    expect(valores.last, true);
  });

  testWidgets('selección con pocas opciones: fichas; tocar la elegida en una '
      'opcional la quita', (tester) async {
    await montar(
      tester,
      const CampoFormulario(
        clave: 'zona',
        etiqueta: 'Zona',
        tipo: TipoCampo.seleccion,
        opciones: ['Cara', 'Brazos', 'Piernas'],
      ),
      valor: 'Cara',
    );

    await tester.tap(find.text('Brazos'));
    expect(valores.last, 'Brazos');

    await tester.tap(find.text('Cara'));
    expect(valores.last, isNull);
  });

  testWidgets('selección con muchas opciones: una lista desplegable', (
    tester,
  ) async {
    await montar(
      tester,
      const CampoFormulario(
        clave: 'dia',
        etiqueta: 'Día',
        tipo: TipoCampo.seleccion,
        opciones: [
          'Lunes',
          'Martes',
          'Miércoles',
          'Jueves',
          'Viernes',
          'Sábado',
        ],
      ),
    );

    expect(find.text('Elige una opción'), findsOneWidget);

    await tester.tap(find.byKey(const Key('campo-dia')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jueves').last);
    await tester.pumpAndSettle();

    expect(valores.last, 'Jueves');
  });

  testWidgets('fecha: se elige en el calendario y vuelve como AAAA-MM-DD', (
    tester,
  ) async {
    await montar(
      tester,
      const CampoFormulario(
        clave: 'desde',
        etiqueta: '¿Desde cuándo?',
        tipo: TipoCampo.fecha,
      ),
      valor: '2026-09-21',
    );

    expect(find.text('Lunes 21 de septiembre de 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('campo-desde')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('Elegir'));
    await tester.pumpAndSettle();

    expect(valores.last, '2026-09-15');
  });

  group('Visor de imágenes', () {
    const archivo = ArchivoMeta(
      id: 'a1',
      nombre: 'receta.png',
      mime: 'image/png',
      tamano: 10,
    );

    testWidgets('baja la imagen y la enseña con zoom', (tester) async {
      final pedidas = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: temaCliniq(),
          home: VisorDeImagen(
            archivo: archivo,
            descargar: (id) async {
              pedidas.add(id);
              return Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 1, 2, 3]);
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(pedidas, ['a1']);
      expect(find.text('receta.png'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('si no baja, lo dice y deja reintentar', (tester) async {
      var intentos = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: temaCliniq(),
          home: VisorDeImagen(
            archivo: archivo,
            descargar: (id) async {
              intentos++;
              if (intentos == 1) throw StateError('sin red');
              return Uint8List.fromList([1, 2, 3]);
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('No pudimos abrir la imagen.'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump();

      expect(intentos, 2);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });
  });
}
