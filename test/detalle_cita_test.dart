// test/detalle_cita_test.dart

import 'package:app_cliniq/core/catalogos/catalogo_service.dart';
import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/red/estado_de_la_red.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/citas/presentacion/widgets/detalle_cita.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';

/// El detalle de una cita con la configuración y los catálogos de la
/// clínica: las horas para cambiarla, los consejos, la modalidad y el
/// contacto.
void main() {
  setUpAll(() => ZonaClinica.aplicar('America/Guayaquil'));
  setUp(SondeoDeRed.olvidarLaInstancia);

  // Faltan 20 horas: con 12 de anticipación se puede cambiar; con 24, no.
  Cita cita() {
    final inicio = RelojClinica().ahora().add(const Duration(hours: 20));
    final redondeada = DateTime(
      inicio.year,
      inicio.month,
      inicio.day,
      inicio.hour,
      inicio.minute,
    );

    return Cita(
      id: 'c1',
      inicio: redondeada,
      fin: redondeada.add(const Duration(minutes: 30)),
      tipo: TipoCita.presencial,
      estado: EstadoCita.programada,
      doctorId: 'doc',
      medico: 'Luis Mora',
      especialidad: 'Pediatría',
    );
  }

  Future<void> montar(
    WidgetTester tester, {
    Map<String, dynamic>? agenda,
    Map<String, List<Map<String, dynamic>>>? lote,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      conDatosDeLaClinica(
        config: configDePrueba(agenda: agenda),
        catalogos: catalogosDePrueba(lote),
        MaterialApp(
          theme: temaCliniq(),
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  DetalleCita(cita: cita(), contextoPadre: context),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> bajarHasta(WidgetTester tester, Finder buscado) =>
      tester.scrollUntilVisible(
        buscado,
        200,
        scrollable: find.byType(Scrollable).first,
      );

  testWidgets('con las 12 horas de la clínica se ofrece reprogramar', (
    tester,
  ) async {
    await montar(tester);

    await bajarHasta(tester, find.text('Reprogramar'));
    expect(find.text('Reprogramar'), findsOneWidget);
    expect(find.text('Puedes cambiarla hasta 12 horas antes.'), findsOneWidget);
  });

  testWidgets('si la clínica pide 24 horas, se explica y se da el contacto', (
    tester,
  ) async {
    await montar(tester, agenda: {'horasMinimasCambio': 24});

    await bajarHasta(tester, find.byKey(const Key('contacto-telefono')));
    expect(find.text('Reprogramar'), findsNothing);
    expect(find.textContaining('Faltan menos de 24 horas'), findsOneWidget);
    expect(find.text('02 255 0000'), findsOneWidget);
    expect(find.text('contacto@andina.ec'), findsOneWidget);
  });

  testWidgets('la modalidad, el estado y los consejos salen de los catálogos', (
    tester,
  ) async {
    final lote = catalogosJson();
    lote[Catalogos.modalidadCita]![0]['nombre'] = 'En consultorio';
    lote[Catalogos.modalidadCita]![0]['descripcion'] = 'Sede norte';
    lote[Catalogos.estadoCita]![0]['nombre'] = 'Agendada';
    lote[Catalogos.preparacionCita] = [
      {'codigo': 'PRESENCIAL_1', 'nombre': 'Trae tu carnet de vacunas.'},
    ];

    await montar(tester, lote: lote);

    expect(find.text('Agendada'), findsOneWidget);
    expect(find.text('En consultorio · Sede norte'), findsOneWidget);
    expect(find.text('Luis Mora · Pediatría'), findsOneWidget);
    await bajarHasta(tester, find.text('Trae tu carnet de vacunas.'));
    expect(find.text('Cómo prepararte'), findsOneWidget);
    expect(find.textContaining('Llega 10 minutos'), findsNothing);
  });

  testWidgets('sin consejos en el catálogo no se inventa ninguno', (
    tester,
  ) async {
    final lote = catalogosJson()..[Catalogos.preparacionCita] = [];

    await montar(tester, lote: lote);
    await bajarHasta(tester, find.text('Reprogramar'));

    expect(find.text('Cómo prepararte'), findsNothing);
  });
}
