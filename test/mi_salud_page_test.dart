// test/mi_salud_page_test.dart

import 'package:app_cliniq/core/catalogos/catalogo_service.dart';
import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/dependientes/data/models/dependiente.dart';
import 'package:app_cliniq/features/mi_salud/data/mi_salud_service.dart';
import 'package:app_cliniq/features/mi_salud/data/models/mi_salud.dart';
import 'package:app_cliniq/features/mi_salud/presentacion/certificado_page.dart';
import 'package:app_cliniq/features/mi_salud/presentacion/mi_salud_page.dart';
import 'package:app_cliniq/features/mi_salud/presentacion/orden_page.dart';
import 'package:app_cliniq/features/mi_salud/presentacion/receta_page.dart';
import 'package:app_cliniq/features/mi_salud/presentacion/visor_pdf_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/mi_salud.dart';
import 'dobles/pantalla.dart';
import 'dobles/pdf.dart';

/// La pantalla de Mi salud y el detalle de una receta y de una orden, con
/// la configuración y los catálogos de la clínica.
void main() {
  setUpAll(() => ZonaClinica.aplicar('America/Guayaquil'));

  late DioGrabador api;
  late CacheLocal cache;
  late bool hayRed;
  late Map<String, dynamic> respuesta;
  late PdfFalso pdf;

  setUp(() {
    sondeoConRed();
    // El visor de PDF, sin el lector del sistema ni el disco del teléfono.
    pdf = PdfFalso();
    Servicios.documentosPdfParaPruebas = pdf;
    Servicios.salidaParaPruebas = SalidaFalsa();
    Servicios.pintorParaPruebas = const PintorFalso();
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
      'GET /portal/certificados/c1': (_) => certificadoJson(),
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

  group('Recetas y certificados firmados', () {
    setUp(() {
      respuesta = miSaludJson(
        atenciones: [
          atencionJson(
            recetas: [recetaJson(firmada: true, pdfDisponible: true)],
            certificados: [certificadoJson()],
          ),
        ],
      );
      api.rutas['GET /portal/recetas/r1'] = (_) =>
          recetaJson(firmada: true, pdfDisponible: true);
    });

    testWidgets('el certificado de reposo en la consulta, con su firma y «Ver '
        'PDF»', (tester) async {
      await montar(tester);
      await bajarHasta(tester, find.byKey(const Key('pdf-certificado-c1')));

      expect(find.text('CERTIFICADOS DE REPOSO'), findsOneWidget);
      expect(find.text('Reposo absoluto · 3 días'), findsOneWidget);
      expect(
        find.text(
          'Del sábado 26 de septiembre al lunes 28 de septiembre de 2026',
        ),
        findsOneWidget,
      );
      expect(find.text('Firmado electrónicamente'), findsOneWidget);
      expect(find.text('Firmada electrónicamente'), findsOneWidget);
      expect(find.byKey(const Key('pdf-receta-r1')), findsOneWidget);
    });

    testWidgets('el certificado se abre con los días, las fechas, las '
        'recomendaciones y el sello de la firma', (tester) async {
      await montar(tester);
      await tocar(tester, find.byKey(const Key('certificado-c1')));

      expect(find.byType(CertificadoPage), findsOneWidget);
      expect(api.claves, contains('GET /portal/certificados/c1'));
      expect(find.text('Certificado médico de reposo'), findsOneWidget);
      expect(
        find.text('Emitido el viernes 25 de septiembre de 2026'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Firmado electrónicamente por LUIS ALBERTO MORA SALAZAR el sábado '
          '26 de septiembre de 2026 a las 10:15',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Emisor del certificado: Security Data'),
        findsOneWidget,
      );
      expect(find.text('3 días'), findsOneWidget);
      expect(find.text('(tres)'), findsOneWidget);
      expect(find.text('Reposo absoluto'), findsOneWidget);
      expect(find.text('Sábado 26 de septiembre de 2026'), findsOneWidget);
      expect(find.text('Lunes 28 de septiembre de 2026'), findsOneWidget);
      expect(find.text('Enfermedad general'), findsOneWidget);
      // La modalidad con el nombre de su catálogo.
      expect(find.text('Telemedicina'), findsOneWidget);
      expect(find.text('Empleador'), findsOneWidget);

      await bajarHasta(tester, find.byKey(const Key('codigo-verificacion')));
      expect(
        find.text('Hidratación abundante y evitar el frío.'),
        findsOneWidget,
      );
      // El paciente no autorizó el diagnóstico: no aparece, como en el PDF.
      expect(
        find.text('Diagnóstico reservado: no aparece en el certificado.'),
        findsOneWidget,
      );
      expect(find.textContaining('Amigdalitis'), findsNothing);
      expect(find.text('CR7Q2MXK9P'), findsOneWidget);
      expect(find.byKey(const Key('boton-ver-pdf')), findsOneWidget);
    });

    testWidgets('«Ver PDF» abre el visor de la aplicación con la huella '
        'firmada', (tester) async {
      await montar(tester);
      await tocar(tester, find.byKey(const Key('certificado-c1')));
      await tester.tap(find.byKey(const Key('boton-ver-pdf')));
      await tester.pumpAndSettle();

      expect(find.byType(VisorPdfPage), findsOneWidget);
      expect(pdf.pedidos.single, (
        tipo: TipoDocumentoFirmado.certificado,
        id: 'c1',
        sha256: huellaDePrueba,
      ));
      expect(find.text('PDF: /documentos/certificado_c1.pdf'), findsOneWidget);
      expect(find.text('Guardar en el teléfono'), findsOneWidget);
    });

    testWidgets('«Ver PDF» también desde la fila de la receta', (tester) async {
      await montar(tester);
      await tocar(tester, find.byKey(const Key('pdf-receta-r1')));

      expect(find.byType(VisorPdfPage), findsOneWidget);
      expect(find.byType(RecetaPage), findsNothing);
      expect(pdf.pedidos.single.tipo, TipoDocumentoFirmado.receta);
      expect(find.text('Receta'), findsOneWidget);
    });

    testWidgets('la receta firmada lo dice y ofrece «Ver PDF»', (tester) async {
      await montar(tester);
      await tocar(tester, find.byKey(const Key('receta-r1')));

      expect(find.byType(RecetaPage), findsOneWidget);
      expect(find.byKey(const Key('sello-firma')), findsOneWidget);
      expect(
        find.textContaining('Firmado electrónicamente por LUIS ALBERTO'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('boton-ver-pdf')));
      await tester.pumpAndSettle();
      expect(pdf.pedidos.single, (
        tipo: TipoDocumentoFirmado.receta,
        id: 'r1',
        sha256: huellaDePrueba,
      ));
    });

    testWidgets('sin firma o sin PDF disponible no hay sello ni «Ver PDF»', (
      tester,
    ) async {
      respuesta = miSaludJson(
        atenciones: [
          atencionJson(
            recetas: [recetaJson()],
            certificados: [
              certificadoJson(firmado: true, pdfDisponible: false),
            ],
          ),
        ],
      );
      api.rutas['GET /portal/recetas/r1'] = (_) => recetaJson();

      await montar(tester);
      await bajarHasta(tester, find.byKey(const Key('certificado-c1')));
      expect(find.byKey(const Key('pdf-receta-r1')), findsNothing);
      expect(find.byKey(const Key('pdf-certificado-c1')), findsNothing);
      expect(find.text('Firmada electrónicamente'), findsNothing);

      await tocar(tester, find.byKey(const Key('receta-r1')));
      expect(find.byKey(const Key('sello-firma')), findsNothing);
      expect(find.byKey(const Key('boton-ver-pdf')), findsNothing);
    });

    testWidgets('una consulta todavía abierta enseña solo lo firmado', (
      tester,
    ) async {
      respuesta = miSaludJson(
        atenciones: [
          atencionEnCursoJson(certificados: [certificadoJson()]),
          atencionJson(),
        ],
      );

      await montar(tester);
      await bajarHasta(tester, find.byKey(const Key('certificado-c1')));

      expect(find.text('En curso'), findsOneWidget);
      expect(find.textContaining('La consulta sigue abierta'), findsOneWidget);
      expect(find.text('Reposo absoluto · 3 días'), findsOneWidget);
      expect(find.byKey(const Key('pdf-certificado-c1')), findsOneWidget);
    });

    testWidgets('con el diagnóstico autorizado, el certificado lo enseña', (
      tester,
    ) async {
      await montarPantalla(
        tester,
        CertificadoPage(
          id: 'c2',
          servicio: MiSaludService(
            DioGrabador({
              'GET /portal/certificados/c2': (_) => certificadoJson(
                id: 'c2',
                mostrarDiagnostico: true,
                tipoReposo: 'RELATIVO',
              ),
            }).dio,
            cache,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reposo relativo'), findsOneWidget);
      await bajarHasta(tester, find.textContaining('Amigdalitis aguda'));
      expect(find.text('DIAGNÓSTICO'), findsOneWidget);
      expect(find.textContaining('Diagnóstico reservado'), findsNothing);
    });

    testWidgets('un certificado anulado se marca y ya no ofrece el PDF', (
      tester,
    ) async {
      await montarPantalla(
        tester,
        CertificadoPage(
          id: 'c3',
          servicio: MiSaludService(
            DioGrabador({
              'GET /portal/certificados/c3': (_) => certificadoJson(
                id: 'c3',
                estado: 'ANULADA',
                anuladoMotivo: 'Fechas equivocadas',
              ),
            }).dio,
            cache,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Anulado'), findsOneWidget);
      expect(
        find.textContaining('ya no es válido. Motivo: Fechas equivocadas'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('boton-ver-pdf')), findsNothing);
    });
  });
}
