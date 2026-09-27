// test/seguridad_test.dart

import 'package:app_cliniq/core/storage/almacen_claves.dart';
import 'package:app_cliniq/core/storage/credenciales_service.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/perfil/presentacion/widgets/seguridad.dart';
import 'package:app_cliniq/features/perfil/providers/perfil_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dobles.dart';

/// La contraseña nueva pide el mínimo que configuró la clínica
/// (`seguridad.passwordMinimo`), no un número escrito en la aplicación.
void main() {
  Future<void> abrir(WidgetTester tester, int minimo) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final cubit = PerfilCubit(
      auth: AuthServiceFalso(),
      credenciales: CredencialesService(AlmacenClavesEnMemoria()),
      biometria: BiometriaFalsa(),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      conDatosDeLaClinica(
        config: configDePrueba(seguridad: {'passwordMinimo': minimo}),
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: temaCliniq(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => mostrarCambiarContrasena(context),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> escribirYGuardar(WidgetTester tester, String nueva) async {
    final campos = find.byType(EditableText);
    await tester.enterText(campos.at(0), 'actual-1');
    await tester.enterText(campos.at(1), nueva);
    await tester.enterText(campos.at(2), nueva);
    // El título y el botón dicen lo mismo: el botón es el último.
    final boton = find.text('Cambiar contraseña').last;
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pump();
  }

  testWidgets('con un mínimo de 10, 9 caracteres no alcanzan', (tester) async {
    await abrir(tester, 10);

    expect(find.textContaining('Usa al menos 10 caracteres.'), findsOneWidget);
    expect(find.text('Mínimo 10 caracteres'), findsOneWidget);

    await escribirYGuardar(tester, 'nueve1234');

    expect(find.text('Debe tener al menos 10 caracteres.'), findsOneWidget);
  });

  testWidgets('con un mínimo de 6, 6 caracteres alcanzan', (tester) async {
    await abrir(tester, 6);

    await escribirYGuardar(tester, 'seis12');

    expect(find.textContaining('Debe tener al menos'), findsNothing);
  });
}
