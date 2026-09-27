// test/contacto_clinica_test.dart

import 'package:app_cliniq/core/presentacion/enlaces.dart';
import 'package:app_cliniq/core/presentacion/widgets/contacto_clinica.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/navegador_falso.dart';

/// Donde la aplicación le dice a la persona que se comunique con la clínica,
/// le da el teléfono y el correo de la configuración, para tocarlos.
void main() {
  Future<void> montar(
    WidgetTester tester,
    Widget hijo, {
    Map<String, dynamic>? clinica,
  }) async {
    await tester.pumpWidget(
      conDatosDeLaClinica(
        config: configDePrueba(clinica: clinica),
        MaterialApp(
          theme: temaCliniq(),
          home: Scaffold(body: Center(child: hijo)),
        ),
      ),
    );
  }

  test('el teléfono y el correo como direcciones tel: y mailto:', () {
    expect(direccionDeTelefono('02 255-0000').toString(), 'tel:022550000');
    expect(
      direccionDeTelefono('+593 99 123 4567').toString(),
      'tel:+593991234567',
    );
    expect(
      direccionDeCorreo(' contacto@andina.ec ').toString(),
      'mailto:contacto@andina.ec',
    );
  });

  testWidgets('tocar el teléfono llama y tocar el correo escribe', (
    tester,
  ) async {
    final navegador = NavegadorFalso()..instalar();
    await montar(tester, const ContactoClinica(mensaje: 'Comunícate.'));

    expect(find.text('Comunícate.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('contacto-telefono')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('contacto-correo')));
    await tester.pump();

    expect(navegador.abiertas, ['tel:022550000', 'mailto:contacto@andina.ec']);
  });

  testWidgets('sin teléfono ni correo configurados no se inventa nada', (
    tester,
  ) async {
    await montar(
      tester,
      const ContactoClinica(),
      clinica: {'telefono': '', 'correoContacto': ''},
    );

    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('el número de emergencias es el de la configuración', (
    tester,
  ) async {
    final navegador = NavegadorFalso()..instalar();
    await montar(
      tester,
      const BotonEmergencia(),
      clinica: {'telefonoEmergencia': '171'},
    );

    expect(find.text('Llamar al 171'), findsOneWidget);
    await tester.tap(find.byKey(const Key('boton-emergencia')));
    await tester.pump();

    expect(navegador.abiertas, ['tel:171']);
  });
}
