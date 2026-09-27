// test/mi_salud_page_test.dart

import 'package:app_cliniq/core/catalogos/catalogo_service.dart';
import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/dependientes/data/models/dependiente.dart';
import 'package:app_cliniq/features/mi_salud/data/mi_salud_service.dart';
import 'package:app_cliniq/features/mi_salud/presentacion/mi_salud_page.dart';
import 'package:app_cliniq/features/mi_salud/presentacion/orden_page.dart';
import 'package:app_cliniq/features/mi_salud/presentacion/receta_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/mi_salud.dart';
import 'dobles/pantalla.dart';

/// La pantalla de Mi salud y el detalle de una receta y de una orden, con
/// la configuración y los catálogos de la clínica.
void main() {
  setUpAll(() => ZonaClinica.aplicar('America/Guayaquil'));

  late DioGrabador api;
  late CacheLocal cache;
  late bool hayRed;
  late Map<String, dynamic> respuesta;

  setUp(() {
    sondeoConRed();
    cache = CacheEnMemoria();
    hayRed = true;
    respuesta = miSaludJson();
    api = DioGrabador({
      'GET /portal/mi-salud': (pedido) {
        if (!hayRed) throw errorDeRed();
        return pedido.queryParameters['pacienteId'] == 'd1'
            ? miSaludJson(
                uid: 'd1',
                nombre: 'Tomás Pérez',
                atenciones: const [],
                conSignos: false,
              )
            : respuesta;
      },
      'GET /portal/recetas/r1': (_) => recetaJson(),
      'GET /portal/ordenes/o1': (_) =>
          ordenJson(tipo: 'IMAGEN', prioridad: 'URGENTE'),
    });
  });

  MiSaludService servicio() => MiSaludService(api.dio, cache);

  Future<void> montar(
    WidgetTester tester, {
    List<Dependiente> dependientes = const [],
  }) async {
    await montarPantalla(
      tester,
      MiSaludPage(
        servicio: servicio(),
        dependientes: DependientesFalso(dependientes),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> bajarHasta(WidgetTester tester, Finder buscado) =>
      tester.scrollUntilVisible(
        buscado,
        200,
        scrollable: find.byType(Scrollable).first,
      );

  /// Lleva el elemento a la vista y lo toca.
  Future<void> tocar(WidgetTester tester, Finder buscado) async {
    await bajarHasta(tester, buscado);
    await tester.ensureVisible(buscado);
    await tester.pumpAndSettle();
    await tester.tap(buscado);
    await tester.pumpAndSettle();
  }

  testWidgets('la ficha, las mediciones y la consulta más reciente abierta', (
    tester,
  ) async {
    await montar(tester);

    expect(find.text('Mi salud'), findsWidgets);
    expect(find.textContaining('en Clínica Andina'), findsOneWidget);
    expect(find.text('Ana María Pérez'), findsOneWidget);
    // Sexo y tipo de sangre con las etiquetas de sus catálogos.
    expect(find.text('34 años · Femenino · Sangre O+'), findsOneWidget);
    expect(find.text('Penicilina'), findsOneWidget);
    expect(find.text('150/95'), findsOneWidget);
    expect(find.text('70 kg'), findsOneWidget);
    expect(find.text('25,7'), findsOneWidget);

    await bajarHasta(tester, find.text('Viernes 25 de septiembre de 2026'));
    // La modalidad con el nombre del catálogo.
    expect(find.text('Telemedicina'), findsOneWidget);
    expect(find.text('Luis Mora · Medicina Familiar'), findsOneWidget);

    await bajarHasta(tester, find.byKey(const Key('orden-o1')));
    expect(find.textContaining('Amigdalitis aguda'), findsOneWidget);
    expect(find.textContaining('por confirmar'), findsOneWidget);
    expect(find.text('Amoxicilina por 10 días.'), findsOneWidget);
    expect(find.textContaining('Próximo control:'), findsOneWidget);
    expect(find.text('Amoxicilina 500 mg Cápsula'), findsOneWidget);
    expect(find.text('Laboratorio: 2 exámenes'), findsOneWidget);
  });

  testWidgets('tocar la consulta la cierra y la vuelve a abrir', (
    tester,
  ) async {
    await montar(tester);

    await tocar(tester, find.byKey(const Key('atencion-at1')));
    expect(find.byKey(const Key('receta-r1')), findsNothing);

    await tocar(tester, find.byKey(const Key('atencion-at1')));
    expect(find.byKey(const Key('receta-r1')), findsOneWidget);
  });

  testWidgets('la receta se abre entera, con su código de verificación', (
    tester,
  ) async {
    await montar(tester);
    await tocar(tester, find.byKey(const Key('receta-r1')));

    expect(find.byType(RecetaPage), findsOneWidget);
    expect(api.claves, contains('GET /portal/recetas/r1'));
    expect(find.text('Receta médica'), findsOneWidget);
    expect(find.text('Amoxicilina 500 mg Cápsula'), findsOneWidget);
    expect(find.text('1 cápsula, Cada 8 horas, 10 días'), findsOneWidget);
    expect(find.text('Vía: Oral · Cantidad: 30'), findsOneWidget);

    await bajarHasta(tester, find.byKey(const Key('codigo-verificacion')));
    expect(find.text('UC7F6DB5UU'), findsOneWidget);
    expect(find.text('1005-2019-2081234'), findsOneWidget);
  });

  testWidgets('la orden urgente de imagen lo dice', (tester) async {
    await montar(tester);
    await tocar(tester, find.byKey(const Key('orden-o1')));

    expect(find.byType(OrdenPage), findsOneWidget);
    expect(find.text('Orden de imagen'), findsOneWidget);
    expect(find.text('Urgente'), findsOneWidget);
    expect(find.text('Proteína C reactiva (PCR)'), findsNothing);
    expect(find.textContaining('Proteína C reactiva'), findsOneWidget);
    expect(find.text('En ayunas'), findsOneWidget);
  });

  testWidgets('«para quién»: los dependientes, y al elegir uno se pide el '
      'suyo', (tester) async {
    await montar(
      tester,
      dependientes: const [Dependiente(uid: 'd1', nombre: 'Tomás Pérez')],
    );

    expect(find.byKey(const Key('para-yo')), findsOneWidget);
    await tester.tap(find.byKey(const Key('para-d1')));
    await tester.pumpAndSettle();

    expect(api.ultimo('GET /portal/mi-salud').queryParameters, {
      'pacienteId': 'd1',
    });
    expect(find.text('Tomás Pérez'), findsWidgets);
    expect(find.text('Ana María Pérez'), findsNothing);
    expect(find.text('Aún no hay consultas registradas'), findsOneWidget);
  });

  testWidgets('sin permiso de dependientes no se ofrece «para quién»', (
    tester,
  ) async {
    await montarPantalla(
      tester,
      MiSaludPage(
        servicio: servicio(),
        dependientes: DependientesFalso(const [
          Dependiente(uid: 'd1', nombre: 'Tomás Pérez'),
        ]),
      ),
      usuario: pacienteDePrueba(permisos: ['portal.mis_citas']),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('para-yo')), findsNothing);
  });

  testWidgets('sin red y sin copia: el error con «Reintentar»; con red, '
      'carga', (tester) async {
    hayRed = false;
    await montar(tester);

    expect(find.text('No pudimos cargar esto'), findsOneWidget);
    hayRed = true;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(find.text('Penicilina'), findsOneWidget);
  });

  testWidgets('sin red con copia: la copia y cuándo se guardó', (tester) async {
    await tester.runAsync(() => servicio().cargar('u1'));
    hayRed = false;

    await montar(tester);

    expect(find.text('Penicilina'), findsOneWidget);
    expect(find.textContaining('Mostramos la copia guardada'), findsOneWidget);
  });

  testWidgets('el embarazo en curso, con los días de gestación de la clínica', (
    tester,
  ) async {
    final hoy = Servicios.reloj.hoy();
    respuesta = miSaludJson(
      embarazo: {'actual': true, 'fum': fechaIso(sumarDias(hoy, -73))},
    );

    await montar(tester);

    expect(find.textContaining('Embarazo: 10 semanas 3 días'), findsOneWidget);
  });

  testWidgets(
    'una modalidad que el catálogo no tiene se enseña con su código',
    (tester) async {
      final lote = catalogosJson()..remove(Catalogos.modalidadCita);
      lote[Catalogos.modalidadCita] = const [];
      respuesta = miSaludJson(atenciones: [atencionJson(tipo: 'DOMICILIO')]);

      await montarPantalla(
        tester,
        MiSaludPage(servicio: servicio(), dependientes: DependientesFalso()),
        catalogos: catalogosDePrueba(lote),
      );
      await tester.pumpAndSettle();
      await bajarHasta(tester, find.text('DOMICILIO'));

      expect(find.text('DOMICILIO'), findsOneWidget);
    },
  );

  testWidgets('una receta anulada se marca y su detalle lo explica', (
    tester,
  ) async {
    await montarPantalla(
      tester,
      RecetaPage(
        id: 'r9',
        servicio: MiSaludService(
          DioGrabador({
            'GET /portal/recetas/r9': (_) => recetaJson(
              id: 'r9',
              estado: 'ANULADA',
              anuladaMotivo: 'Dosis equivocada',
            ),
          }).dio,
          cache,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Anulada'), findsOneWidget);
    expect(find.textContaining('Motivo: Dosis equivocada'), findsOneWidget);
  });
}
