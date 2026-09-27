// test/formulario_dependiente_test.dart

import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/dependientes/data/models/dependiente.dart';
import 'package:app_cliniq/features/dependientes/presentacion/formulario_dependiente_page.dart';
import 'package:app_cliniq/features/dependientes/providers/dependientes_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dobles.dart';

/// El formulario de un dependiente: parentescos, documentos, sexo y tipo de
/// sangre de los catálogos de la clínica, y la cédula como ella lo pida.
void main() {
  setUp(sondeoConRed);

  Future<void> montar(
    WidgetTester tester, {
    Dependiente? dependiente,
    Map<String, dynamic>? general,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      conDatosDeLaClinica(
        key: UniqueKey(),
        config: configDePrueba(general: general),
        BlocProvider(
          create: (_) => DependientesBloc(DependientesFalso()),
          child: MaterialApp(
            theme: temaCliniq(),
            home: FormularioDependientePage(dependiente: dependiente),
          ),
        ),
      ),
    );
    // Hasta que termine la entrada animada de la pantalla.
    await tester.pumpAndSettle();
  }

  Future<void> abrirSelector(WidgetTester tester, String pista) async {
    await tester.tap(find.text(pista).first);
    await tester.pumpAndSettle();
  }

  testWidgets('los parentescos son los de PARENTESCO_DEPENDIENTE', (
    tester,
  ) async {
    await montar(tester);
    await abrirSelector(tester, '¿Qué es para ti?');

    expect(find.text('Tutor legal').last, findsOneWidget);
    expect(find.text('Hijo/a').last, findsOneWidget);
    // Los del contacto de emergencia (PARENTESCO) no se mezclan.
    expect(find.text('Cónyuge'), findsNothing);
  });

  testWidgets('los documentos y sus etiquetas salen de TIPO_DOCUMENTO', (
    tester,
  ) async {
    await montar(tester);

    expect(find.text('Cédula'), findsOneWidget);
    expect(find.text('Pasaporte'), findsOneWidget);
  });

  testWidgets('el sexo de un dependiente guardado se lee con su etiqueta', (
    tester,
  ) async {
    await montar(
      tester,
      dependiente: const Dependiente(
        uid: 'd1',
        nombre: 'Tomás Pérez',
        parentesco: 'Hijo/a',
        sexo: 'M',
        tipoSangre: 'O+',
      ),
    );

    expect(find.text('Masculino'), findsOneWidget);
    expect(find.text('O+'), findsOneWidget);
  });

  Future<bool> cedulaRechazada(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Cédula (10 dígitos, opcional)'),
      '1710034066',
    );
    final guardar = find.text('Registrar dependiente');
    await tester.scrollUntilVisible(
      guardar,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(guardar);
    await tester.pumpAndSettle();

    return find
        .text('La cédula no es válida. Revisa los diez dígitos.')
        .evaluate()
        .isNotEmpty;
  }

  testWidgets('con validarCedula encendido, el dígito verificador manda', (
    tester,
  ) async {
    await montar(tester, general: {'validarCedula': true});

    expect(await cedulaRechazada(tester), isTrue);
  });

  testWidgets('con validarCedula apagado, diez dígitos bastan', (tester) async {
    await montar(tester, general: {'validarCedula': false});

    expect(await cedulaRechazada(tester), isFalse);
  });
}
