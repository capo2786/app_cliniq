// test/cancelar_consulta_test.dart

import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/consultas/presentacion/widgets/cancelar_consulta.dart';
import 'package:app_cliniq/features/consultas/providers/detalle_consulta_bloc.dart';
import 'package:app_cliniq/features/consultas/providers/detalle_consulta_event.dart';
import 'package:app_cliniq/features/consultas/providers/detalle_consulta_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/consultas.dart';

/// La hoja para cancelar una consulta enviada: el motivo es obligatorio y
/// admite hasta 500 caracteres (`MOTIVO_CANCELACION_MAX` del servidor), con
/// su contador.
void main() {
  late ConsultasFalso servicio;
  late DetalleConsultaBloc bloc;

  setUp(() => servicio = ConsultasFalso());

  final campo = find.byKey(const Key('campo-motivo-cancelacion'));
  final cancelar = find.widgetWithText(FilledButton, 'Cancelar consulta');

  String motivoEscrito(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  /// El bloc nace dentro de la prueba (con su reloj de mentira) y el
  /// BlocProvider lo cierra al desmontarse.
  Future<void> abrirHoja(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: temaCliniq(),
        home: BlocProvider(
          lazy: false,
          create: (_) => bloc = DetalleConsultaBloc(
            servicio: servicio,
            uid: 'u1',
            id: 'c1',
            latidos: () => const Stream<void>.empty(),
          )..add(const DetalleConsultaSolicitado()),
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => mostrarCancelarConsulta(context),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(bloc.state.carga, CargaDetalle.lista);
    expect(bloc.state.puedeCancelar, isTrue);

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('el contador llega hasta 500 y no deja escribir más', (
    tester,
  ) async {
    await abrirHoja(tester);

    expect(find.text('0/500'), findsOneWidget);

    await tester.enterText(campo, 'a' * 600);
    await tester.pump();

    expect(motivoEscrito(tester), hasLength(500));
    expect(find.text('500/500'), findsOneWidget);
  });

  testWidgets('sin motivo, o con uno que el servidor mediría de más de 500, '
      'no se cancela y se dice por qué', (tester) async {
    await abrirHoja(tester);

    await tester.ensureVisible(cancelar);
    await tester.tap(cancelar);
    await tester.pump();
    expect(find.text('Cuéntanos por qué la cancelas.'), findsOneWidget);

    // 300 emojis caben en el contador, pero el servidor cuenta 600.
    await tester.enterText(campo, '🙂' * 300);
    await tester.tap(cancelar);
    await tester.pump();
    expect(find.text('El motivo admite hasta 500 caracteres.'), findsOneWidget);

    expect(servicio.llamadas.where((l) => l.startsWith('cancelar')), isEmpty);
  });

  testWidgets('con un motivo válido cancela y la hoja se cierra', (
    tester,
  ) async {
    await abrirHoja(tester);

    await tester.enterText(campo, '  Ya me siento mejor  ');
    await tester.tap(cancelar);
    await tester.pumpAndSettle();

    expect(servicio.llamadas.last, 'cancelar:c1:Ya me siento mejor');
    expect(campo, findsNothing);
  });
}
