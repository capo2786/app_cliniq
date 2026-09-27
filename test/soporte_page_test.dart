// test/soporte_page_test.dart

import 'package:app_cliniq/core/archivos/archivos_service.dart';
import 'package:app_cliniq/core/archivos/selector_de_archivos.dart';
import 'package:app_cliniq/core/catalogos/catalogo_service.dart';
import 'package:app_cliniq/core/configuracion/config_publica.dart';
import 'package:app_cliniq/core/fechas/zona_clinica.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/consultas/presentacion/widgets/visor_imagen.dart';
import 'package:app_cliniq/features/soporte/data/soporte_service.dart';
import 'package:app_cliniq/features/soporte/presentacion/nuevo_ticket_page.dart';
import 'package:app_cliniq/features/soporte/presentacion/soporte_page.dart';
import 'package:app_cliniq/features/soporte/presentacion/ticket_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/pantalla.dart';
import 'dobles/soporte.dart';

/// Soporte de punta a punta en sus pantallas: la lista, el ticket nuevo
/// con sus catálogos y su archivo, y la conversación.
void main() {
  setUpAll(() => ZonaClinica.aplicar('America/Guayaquil'));

  late DioGrabador api;
  late CacheLocal cache;
  late List<Map<String, dynamic>> tickets;
  late Map<String, dynamic> detalle;

  setUp(() {
    sondeoConRed();
    cache = CacheEnMemoria();
    Servicios.selectorParaPruebas = _SelectorFalso();
    tickets = [resumenTicketJson()];
    detalle = ticketJson();
    api = DioGrabador({
      'GET /soporte/tickets': (_) => tickets,
      'GET /soporte/tickets/t1': (_) => detalle,
      'GET /soporte/tickets/t2': (_) => ticketJson(
        id: 't2',
        estado: 'ABIERTO',
        asunto: 'No puedo reprogramar',
        mensajes: const [],
      ),
      'POST /soporte/tickets': (pedido) => ticketJson(
        id: 't2',
        estado: 'ABIERTO',
        asunto: (pedido.data as Map)['asunto'] as String,
        mensajes: const [],
      ),
      'POST /soporte/tickets/t2/adjuntos': (_) => {
        '_id': 'arch9',
        'nombre': 'captura.png',
        'mime': 'image/png',
        'tamano': 40,
      },
      'POST /soporte/tickets/t2/mensajes': (_) => ticketJson(
        id: 't2',
        estado: 'ABIERTO',
        asunto: 'No puedo reprogramar',
        mensajes: [
          mensajeTicketJson(
            'm1',
            esSoporte: false,
            texto: 'Adjunto: captura.png',
            adjuntoId: 'arch9',
          ),
        ],
      ),
      'POST /soporte/tickets/t1/mensajes': (pedido) => ticketJson(
        mensajes: [
          ...detalle['mensajes'] as List<Map<String, dynamic>>,
          mensajeTicketJson(
            'm3',
            esSoporte: false,
            texto: (pedido.data as Map)['texto'] as String,
          ),
        ],
      ),
    });
  });

  SoporteService servicio() => SoporteService(api.dio, cache);

  /// Baja por la lista hasta [buscado]: las listas largas construyen solo
  /// lo que está cerca de la vista.
  Future<void> bajarHasta(WidgetTester tester, Finder buscado) async {
    if (buscado.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        buscado,
        200,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(buscado);
    await tester.pumpAndSettle();
  }

  Future<void> escribir(WidgetTester tester, String clave, String texto) async {
    final campo = find.byKey(Key(clave));
    await bajarHasta(tester, campo);
    await tester.enterText(campo, texto);
  }

  Future<void> tocar(WidgetTester tester, Finder buscado) async {
    await bajarHasta(tester, buscado);
    await tester.pumpAndSettle();
    await tester.tap(buscado);
    await tester.pumpAndSettle();
  }

  group('La lista', () {
    testWidgets('mis tickets con su estado y categoría del catálogo, y '
        '«Soporte respondió»', (tester) async {
      await montarPantalla(tester, SoportePage(servicio: servicio()));
      await tester.pumpAndSettle();

      expect(find.text('No carga el calendario'), findsOneWidget);
      expect(find.text('En proceso'), findsOneWidget);
      expect(find.text('Problema técnico'), findsOneWidget);
      expect(find.byKey(const Key('soporte-respondio')), findsOneWidget);
    });

    testWidgets('un ticket resuelto no dice «Soporte respondió»', (
      tester,
    ) async {
      tickets = [resumenTicketJson(estado: 'RESUELTO')];

      await montarPantalla(tester, SoportePage(servicio: servicio()));
      await tester.pumpAndSettle();

      expect(find.text('Resuelto'), findsOneWidget);
      expect(find.byKey(const Key('soporte-respondio')), findsNothing);
    });

    testWidgets('sin tickets, lo dice y ofrece escribir', (tester) async {
      tickets = [];

      await montarPantalla(tester, SoportePage(servicio: servicio()));
      await tester.pumpAndSettle();

      expect(find.text('Aún no tienes tickets'), findsOneWidget);
      expect(find.text('Escribir a soporte'), findsOneWidget);
    });

    testWidgets('sin red y sin copia: el error con «Reintentar»', (
      tester,
    ) async {
      api.rutas['GET /soporte/tickets'] = (_) => throw errorDeRed();

      await montarPantalla(tester, SoportePage(servicio: servicio()));
      await tester.pumpAndSettle();

      expect(find.text('No pudimos cargar esto'), findsOneWidget);
      api.rutas['GET /soporte/tickets'] = (_) => tickets;
      await tocar(tester, find.text('Reintentar'));
      expect(find.text('No carga el calendario'), findsOneWidget);
    });

    testWidgets('tocar un ticket abre su conversación', (tester) async {
      await montarPantalla(tester, SoportePage(servicio: servicio()));
      await tester.pumpAndSettle();

      await tocar(tester, find.byKey(const Key('ticket-t1')));

      expect(find.byType(TicketPage), findsOneWidget);
      expect(find.text('Gracias por avisar. Ya lo revisamos.'), findsOneWidget);
    });
  });

  group('El ticket nuevo', () {
    Future<void> abrirFormulario(WidgetTester tester) async {
      await montarPantalla(tester, SoportePage(servicio: servicio()));
      await tester.pumpAndSettle();
      await tocar(tester, find.byKey(const Key('boton-nuevo-ticket')));
      expect(find.byType(NuevoTicketPage), findsOneWidget);
    }

    testWidgets('las categorías y severidades de la clínica, con sus horas '
        'de respuesta', (tester) async {
      await montarPantalla(
        tester,
        SoportePage(servicio: servicio(), nuevoTicket: true),
        config: configDePrueba(
          general: {
            'soporteHorasSla': {
              'CRITICA': 2,
              'ALTA': 8,
              'MEDIA': 48,
              'BAJA': 96,
            },
          },
        ),
      );
      await tester.pumpAndSettle();

      // Con nuevoTicket el formulario se abre solo.
      expect(find.byType(NuevoTicketPage), findsOneWidget);
      expect(find.text('Citas'), findsOneWidget);
      expect(find.text('Consulta médica'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('severidad-MEDIA')));
      expect(
        find.text('Me complica, pero puedo seguir · Respuesta en hasta 48 h'),
        findsOneWidget,
      );
    });

    testWidgets('una consulta médica recuerda llamar a emergencias', (
      tester,
    ) async {
      await abrirFormulario(tester);
      expect(find.byKey(const Key('llamar-emergencias')), findsNothing);

      await tocar(tester, find.byKey(const Key('categoria-MEDICO')));

      expect(find.byKey(const Key('llamar-emergencias')), findsOneWidget);
      expect(find.text('Llamar al 911'), findsOneWidget);
    });

    testWidgets('con datos que el servidor rechazaría, se dice y no se manda', (
      tester,
    ) async {
      await abrirFormulario(tester);

      await escribir(tester, 'campo-asunto', 'ab');
      await tocar(tester, find.byKey(const Key('boton-enviar-ticket')));

      expect(
        find.text('El asunto debe tener al menos 3 caracteres.'),
        findsOneWidget,
      );
      expect(find.text('Cuéntanos qué pasa.'), findsOneWidget);
      expect(api.claves, isNot(contains('POST /soporte/tickets')));
    });

    testWidgets('con un archivo: se crea, sube y abre la conversación', (
      tester,
    ) async {
      await abrirFormulario(tester);

      await tocar(tester, find.byKey(const Key('severidad-ALTA')));
      await escribir(tester, 'campo-asunto', 'No puedo reprogramar');
      await escribir(
        tester,
        'campo-descripcion',
        'Al elegir la hora me sale un error y no guarda.',
      );
      await tocar(tester, find.byKey(const Key('boton-adjuntar-ticket')));
      await tocar(tester, find.text('Elegir un archivo'));
      expect(find.text('captura.png'), findsOneWidget);

      await tocar(tester, find.byKey(const Key('boton-enviar-ticket')));

      expect(api.ultimo('POST /soporte/tickets').data, {
        'categoria': 'CITAS',
        'severidad': 'ALTA',
        'asunto': 'No puedo reprogramar',
        'descripcion': 'Al elegir la hora me sale un error y no guarda.',
      });
      expect(api.ultimo('POST /soporte/tickets/t2/mensajes').data, {
        'texto': 'Adjunto: captura.png',
        'adjuntoId': 'arch9',
      });
      expect(find.byType(TicketPage), findsOneWidget);
      expect(find.text('No puedo reprogramar'), findsOneWidget);
    });

    testWidgets('sin categorías cargadas, el error con «Reintentar»', (
      tester,
    ) async {
      final lote = catalogosJson()..remove(Catalogos.categoriaTicket);

      await montarPantalla(
        tester,
        NuevoTicketPage(servicio: servicio()),
        catalogos: catalogosDePrueba(lote),
      );
      await tester.pumpAndSettle();

      expect(find.text('No pudimos cargar esto'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('La conversación', () {
    Future<void> abrirTicket(
      WidgetTester tester, {
      ArchivosService? archivos,
    }) async {
      await montarPantalla(
        tester,
        TicketPage(id: 't1', servicio: servicio(), archivos: archivos),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('en qué va, la descripción y los mensajes del equipo', (
      tester,
    ) async {
      await abrirTicket(tester);

      expect(find.text('No carga el calendario'), findsOneWidget);
      expect(find.text('Prioridad media'), findsOneWidget);
      expect(
        find.textContaining('Respuesta estimada antes del'),
        findsOneWidget,
      );
      expect(find.text('DESCRIPCIÓN DEL PROBLEMA'), findsOneWidget);
      expect(find.text('Soporte · Admin Cliniq'), findsOneWidget);
      expect(find.text('Ver adjunto'), findsOneWidget);
    });

    testWidgets('responder con la tecla «enviar» del teclado', (tester) async {
      await abrirTicket(tester);

      await tester.enterText(
        find.byKey(const Key('campo-mensaje')),
        'Ya borré la caché y sigue igual',
      );
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(api.ultimo('POST /soporte/tickets/t1/mensajes').data, {
        'texto': 'Ya borré la caché y sigue igual',
      });
      expect(find.text('Ya borré la caché y sigue igual'), findsOneWidget);
      final campo = tester.widget<TextField>(
        find.byKey(const Key('campo-mensaje')),
      );
      expect(campo.controller!.text, isEmpty);
    });

    testWidgets('un ticket cerrado no se puede responder', (tester) async {
      detalle = ticketJson(estado: 'CERRADO');

      await abrirTicket(tester);

      expect(find.byKey(const Key('campo-mensaje')), findsNothing);
      expect(find.byKey(const Key('ticket-cerrado')), findsOneWidget);
    });

    testWidgets('el adjunto se ve dentro de la aplicación', (tester) async {
      final archivos = ArchivosService(
        Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (pedido, manejador) => manejador.resolve(
                Response<List<int>>(
                  requestOptions: pedido,
                  statusCode: 200,
                  data: capturaPng().bytes,
                  headers: Headers.fromMap({
                    'content-type': ['image/png'],
                    'content-disposition': ['inline; filename="captura.png"'],
                  }),
                ),
              ),
            ),
          ),
      );

      await abrirTicket(tester, archivos: archivos);
      await tocar(tester, find.text('Ver adjunto'));

      expect(find.byType(VisorDeImagen), findsOneWidget);
      expect(find.text('captura.png'), findsOneWidget);
    });
  });
}

class _SelectorFalso implements SelectorDeArchivos {
  SeleccionDeArchivos get _captura =>
      SeleccionDeArchivos(archivos: [capturaPng()]);

  @override
  Future<SeleccionDeArchivos> tomarFoto(ReglasArchivos reglas) async =>
      _captura;

  @override
  Future<SeleccionDeArchivos> elegirFotos(ReglasArchivos reglas) async =>
      _captura;

  @override
  Future<SeleccionDeArchivos> elegirDocumentos(ReglasArchivos reglas) async =>
      _captura;
}
