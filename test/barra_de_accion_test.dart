import 'package:app_cliniq/core/presentacion/widgets/barra_de_accion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un formulario con un campo de varias líneas (como el motivo de la cita) y
/// el botón «Continuar» abajo, dentro de la aplicación con su cierre de
/// teclado al tocar fuera.
Future<void> montar(WidgetTester tester, {required VoidCallback alSeguir}) {
  return tester.pumpWidget(
    MaterialApp(
      builder: (context, hijo) => CerrarTecladoAlTocarFuera(child: hijo!),
      home: Scaffold(
        body: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(20),
          children: const [
            Text('Motivo de consulta'),
            TextField(key: Key('campo'), minLines: 5, maxLines: 9),
            SizedBox(height: 40, child: Text('Espacio libre')),
          ],
        ),
        bottomNavigationBar: BarraDeAccion(
          child: ElevatedButton(
            key: const Key('seguir'),
            onPressed: () {
              cerrarTeclado();
              alSeguir();
            },
            child: const Text('Continuar'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  const tecladoAlto = 300.0;

  void abrirTeclado(WidgetTester tester) {
    final escala = tester.view.devicePixelRatio;
    tester.view.viewInsets = FakeViewPadding(bottom: tecladoAlto * escala);
    addTearDown(tester.view.resetViewInsets);
  }

  testWidgets(
    'con el teclado abierto, «Continuar» queda encima y se puede tocar',
    (tester) async {
      var seguido = 0;
      await montar(tester, alSeguir: () => seguido++);

      await tester.tap(find.byKey(const Key('campo')));
      abrirTeclado(tester);
      await tester.pumpAndSettle();

      final alto =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final boton = tester.getRect(find.byKey(const Key('seguir')));
      expect(boton.bottom, lessThanOrEqualTo(alto - tecladoAlto));

      await tester.tap(find.byKey(const Key('seguir')));
      await tester.pump();

      expect(seguido, 1);
      expect(
        FocusManager.instance.primaryFocus?.context?.widget,
        isNot(isA<EditableText>()),
      );
    },
  );

  testWidgets('tocar fuera del campo cierra el teclado', (tester) async {
    await montar(tester, alSeguir: () {});

    await tester.tap(find.byKey(const Key('campo')));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('Espacio libre'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
  });
}
