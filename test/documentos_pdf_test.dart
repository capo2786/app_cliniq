// test/documentos_pdf_test.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app_cliniq/core/network/errores.dart';
import 'package:app_cliniq/core/presentacion/widgets/barra_de_accion.dart';
import 'package:app_cliniq/features/mi_salud/data/documentos_pdf_service.dart';
import 'package:app_cliniq/features/mi_salud/data/models/mi_salud.dart';
import 'package:app_cliniq/features/mi_salud/presentacion/visor_pdf_page.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/mi_salud.dart';
import 'dobles/pantalla.dart';
import 'dobles/pdf.dart';

String huellaDe(List<int> bytes) => sha256.convert(bytes).toString();

/// El PDF firmado de recetas y certificados: la descarga con la sesión, la
/// copia en el teléfono (por tipo, id y huella), sin red, la integridad, el
/// borrado al cerrar sesión y el visor dentro de la aplicación.
void main() {
  group('El servicio', () {
    late Directory raiz;
    late Directory documentos;
    late Directory temporal;
    late DioGrabador api;
    late bool hayRed;
    late Uint8List servido;

    setUp(() {
      raiz = Directory.systemTemp.createTempSync('cliniq_pdf_');
      documentos = Directory('${raiz.path}/documentos')..createSync();
      temporal = Directory('${raiz.path}/temporal')..createSync();
      hayRed = true;
      servido = pdfDePrueba();
      api = DioGrabador({
        'GET /portal/recetas/r1/pdf': (_) {
          if (!hayRed) throw errorDeRed();
          return servido;
        },
        'GET /portal/certificados/c1/pdf': (_) {
          if (!hayRed) throw errorDeRed();
          return pdfDePrueba('certificado firmado');
        },
        // La orden sin firma: el servidor arma la vista previa y lo dice.
        'GET /portal/ordenes/o1/pdf': (pedido) {
          if (!hayRed) throw errorDeRed();
          return Response<dynamic>(
            requestOptions: pedido,
            statusCode: 200,
            headers: Headers.fromMap({
              'x-firma-estado': ['SIN_FIRMA'],
            }),
            data: pdfDePrueba('orden sin firma'),
          );
        },
      });
    });

    tearDown(() {
      if (raiz.existsSync()) raiz.deleteSync(recursive: true);
    });

    DocumentosPdfService servicio() => DocumentosPdfService(
      api.dio,
      carpetaBase: () async => documentos,
      carpetaTemporal: () async => temporal,
    );

    Directory carpeta() => Directory(
      '${documentos.path}/${DocumentosPdfService.carpetaDeDocumentos}',
    );

    List<String> guardados() => carpeta().existsSync()
        ? (carpeta().listSync().map((e) => e.uri.pathSegments.last).toList()
            ..sort())
        : const [];

    test('lo baja con la sesión y lo guarda por tipo, id y huella', () async {
      final pdf = await servicio().obtener(TipoDocumentoFirmado.receta, 'r1');

      final pedido = api.ultimo('GET /portal/recetas/r1/pdf');
      expect(pedido.responseType, ResponseType.bytes);
      expect(pedido.headers['Accept'], 'application/pdf');

      final huella = huellaDe(servido);
      expect(pdf.sha256, huella);
      expect(pdf.bytes, servido);
      expect(pdf.sinConexion, isFalse);
      expect(guardados(), ['receta_r1_$huella.pdf']);
      expect(File(pdf.ruta).readAsBytesSync(), servido);

      final certificado = await servicio().obtener(
        TipoDocumentoFirmado.certificado,
        'c1',
      );
      expect(api.claves.last, 'GET /portal/certificados/c1/pdf');
      expect(
        certificado.ruta,
        endsWith('certificado_c1_${huellaDe(certificado.bytes)}.pdf'),
      );
    });

    test('la orden por su ruta; sin firma, la vista previa lo dice y también '
        'se guarda', () async {
      final orden = await servicio().obtener(TipoDocumentoFirmado.orden, 'o1');

      expect(api.claves.single, 'GET /portal/ordenes/o1/pdf');
      expect(orden.sinFirma, isTrue);
      expect(guardados(), ['orden_o1_${huellaDe(orden.bytes)}.pdf']);

      // La receta firmada no trae la cabecera: no es una vista previa.
      final receta = await servicio().obtener(
        TipoDocumentoFirmado.receta,
        'r1',
      );
      expect(receta.sinFirma, isFalse);

      // Sin red, la última vista previa guardada de esa orden.
      hayRed = false;
      final sinRed = await servicio().obtener(TipoDocumentoFirmado.orden, 'o1');
      expect(sinRed.sinConexion, isTrue);
      expect(sinRed.bytes, orden.bytes);
    });

    test('firmada después, la vista previa guardada no se hace pasar por la '
        'firmada', () async {
      await servicio().obtener(TipoDocumentoFirmado.orden, 'o1');
      hayRed = false;

      // Con la huella del PDF firmado no sirve la copia de la vista previa.
      await expectLater(
        servicio().obtener(
          TipoDocumentoFirmado.orden,
          'o1',
          sha256: huellaDePrueba,
        ),
        throwsA(isA<DioException>()),
      );
    });

    test('con la huella firmada, la copia se abre sin pedir nada', () async {
      final huella = huellaDe(servido);
      await servicio().obtener(
        TipoDocumentoFirmado.receta,
        'r1',
        sha256: huella,
      );
      expect(api.pedidos, hasLength(1));

      hayRed = false;
      final otraVez = await servicio().obtener(
        TipoDocumentoFirmado.receta,
        'r1',
        sha256: huella.toUpperCase(),
      );

      expect(api.pedidos, hasLength(1));
      expect(otraVez.bytes, servido);
      // No es «sin conexión»: es la copia buena, que no hacía falta bajar.
      expect(otraVez.sinConexion, isFalse);
    });

    test('sin red, la última copia y lo dice; sin copia, el error', () async {
      await servicio().obtener(TipoDocumentoFirmado.receta, 'r1');
      hayRed = false;

      final sinRed = await servicio().obtener(
        TipoDocumentoFirmado.receta,
        'r1',
      );
      expect(sinRed.sinConexion, isTrue);
      expect(sinRed.bytes, servido);

      await expectLater(
        servicio().obtener(TipoDocumentoFirmado.certificado, 'c1'),
        throwsA(isA<DioException>()),
      );
      // La copia de la receta no sirve para otro documento ni otro tipo.
      await expectLater(
        servicio().obtener(TipoDocumentoFirmado.certificado, 'r1'),
        throwsA(isA<DioException>()),
      );
    });

    test('lo bajado tiene que coincidir con la huella firmada', () async {
      await expectLater(
        servicio().obtener(
          TipoDocumentoFirmado.receta,
          'r1',
          sha256: 'cd' * 32,
        ),
        throwsA(
          isA<PdfNoValido>().having(
            (e) => e.mensaje,
            'mensaje',
            contains('no coincide con el documento firmado'),
          ),
        ),
      );
      expect(guardados(), isEmpty);
    });

    test('lo que no es un PDF no se guarda', () async {
      servido = Uint8List.fromList(utf8.encode('<html>portal cautivo</html>'));

      await expectLater(
        servicio().obtener(TipoDocumentoFirmado.receta, 'r1'),
        throwsA(isA<PdfNoValido>()),
      );
      expect(guardados(), isEmpty);
    });

    test('una copia dañada se borra y se vuelve a bajar', () async {
      final huella = huellaDe(servido);
      final pdf = await servicio().obtener(
        TipoDocumentoFirmado.receta,
        'r1',
        sha256: huella,
      );
      File(pdf.ruta).writeAsBytesSync(pdfDePrueba('alterado'));

      hayRed = false;
      expect(
        await servicio().copiaGuardada(TipoDocumentoFirmado.receta, 'r1'),
        isNull,
      );
      expect(guardados(), isEmpty);

      hayRed = true;
      final otraVez = await servicio().obtener(
        TipoDocumentoFirmado.receta,
        'r1',
        sha256: huella,
      );
      expect(api.pedidos, hasLength(2));
      expect(File(otraVez.ruta).readAsBytesSync(), servido);
    });

    test('la versión nueva reemplaza a la vieja de ese documento', () async {
      await servicio().obtener(TipoDocumentoFirmado.receta, 'r1');
      await servicio().obtener(TipoDocumentoFirmado.certificado, 'c1');

      servido = pdfDePrueba('otra versión');
      await servicio().obtener(TipoDocumentoFirmado.receta, 'r1');

      expect(guardados(), hasLength(2));
      expect(guardados(), contains('receta_r1_${huellaDe(servido)}.pdf'));
    });

    test(
      'al cerrar sesión se borra todo, también lo temporal del PDF',
      () async {
        await servicio().obtener(TipoDocumentoFirmado.receta, 'r1');
        for (final resto in [
          ...DocumentosPdfService.restosTemporales,
          'otra_cosa',
        ]) {
          File('${temporal.path}/$resto/x.pdf').createSync(recursive: true);
        }

        await servicio().borrarTodo();

        expect(carpeta().existsSync(), isFalse);
        expect(Directory('${temporal.path}/share_plus').existsSync(), isFalse);
        expect(
          Directory('${temporal.path}/pdf_renderer_cache').existsSync(),
          isFalse,
        );
        expect(
          Directory('${temporal.path}/cliniq_compartir').existsSync(),
          isFalse,
        );
        // Lo que no es del PDF se queda.
        expect(Directory('${temporal.path}/otra_cosa').existsSync(), isTrue);

        hayRed = false;
        await expectLater(
          servicio().obtener(TipoDocumentoFirmado.receta, 'r1'),
          throwsA(isA<DioException>()),
        );
      },
    );

    test('el error del servidor, que llega en bytes, se lee', () async {
      api.rutas['GET /portal/recetas/r1/pdf'] = (pedido) => throw DioException(
        requestOptions: pedido,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: pedido,
          statusCode: 404,
          data: utf8.encode(
            jsonEncode({
              'status': 404,
              'message': 'El documento todavía no está disponible.',
            }),
          ),
        ),
      );

      Object? error;
      try {
        await servicio().obtener(TipoDocumentoFirmado.receta, 'r1');
      } catch (e) {
        error = e;
      }

      expect(error, isA<DioException>());
      expect(
        mensajeDeError(error!),
        'El documento todavía no está disponible.',
      );
    });

    test('si la clínica entrega el PDF solo firmado, el mensaje del '
        'servidor', () async {
      api.rutas['GET /portal/ordenes/o1/pdf'] = (pedido) => throw DioException(
        requestOptions: pedido,
        type: DioExceptionType.badResponse,
        response: Response<dynamic>(
          requestOptions: pedido,
          statusCode: 409,
          data: utf8.encode(
            jsonEncode({
              'status': 409,
              'message': 'El PDF de este documento aún no está disponible.',
            }),
          ),
        ),
      );

      Object? error;
      try {
        await servicio().obtener(TipoDocumentoFirmado.orden, 'o1');
      } catch (e) {
        error = e;
      }

      expect(
        mensajeDeError(error!),
        'El PDF de este documento aún no está disponible.',
      );
      expect(guardados(), isEmpty);
    });

    test('un identificador raro no toca la red ni el disco', () async {
      await expectLater(
        servicio().obtener(TipoDocumentoFirmado.receta, '../../secreto'),
        throwsA(isA<PdfNoValido>()),
      );
      expect(api.pedidos, isEmpty);
    });
  });

  group('El nombre para guardar o compartir', () {
    test('el tipo y el código de verificación', () {
      expect(
        nombreDelPdf(
          TipoDocumentoFirmado.receta,
          Receta.desdeJson(recetaJson()),
        ),
        'Receta UC7F6DB5UU.pdf',
      );
      expect(
        nombreDelPdf(
          TipoDocumentoFirmado.certificado,
          CertificadoReposo.desdeJson(certificadoJson()),
        ),
        'Certificado de reposo CR7Q2MXK9P.pdf',
      );
      expect(
        nombreDelPdf(
          TipoDocumentoFirmado.orden,
          Orden.desdeJson(ordenJson(tipo: 'IMAGEN')),
        ),
        'Orden de imagen G2KKBTJTBK.pdf',
      );
      expect(
        nombreDelPdf(TipoDocumentoFirmado.receta, const Receta(id: 'r7')),
        'Receta r7.pdf',
      );
      expect(
        nombreDelDocumento(TipoDocumentoFirmado.orden),
        'Orden de exámenes',
      );
    });
  });

  group('El visor', () {
    late PdfFalso servicio;
    late SalidaFalsa salida;

    setUp(() {
      servicio = PdfFalso();
      salida = SalidaFalsa();
    });

    Future<void> montar(
      WidgetTester tester, {
      TipoDocumentoFirmado tipo = TipoDocumentoFirmado.receta,
      String id = 'r1',
      String nombre = 'Receta UC7F6DB5UU.pdf',
      bool firmado = true,
      bool asentar = true,
    }) async {
      await montarPantalla(
        tester,
        VisorPdfPage(
          tipo: tipo,
          id: id,
          sha256: firmado ? huellaDePrueba : null,
          firmado: firmado,
          nombreArchivo: nombre,
          servicio: servicio,
          salida: salida,
          pintor: const PintorFalso(),
        ),
      );
      // Mientras baja gira una rueda: ahí no hay nada que asentar.
      asentar ? await tester.pumpAndSettle() : await tester.pump();
    }

    testWidgets('pinta el PDF dentro de la aplicación, con guardar y '
        'compartir abajo', (tester) async {
      await montar(tester);

      expect(servicio.pedidos.single, (
        tipo: TipoDocumentoFirmado.receta,
        id: 'r1',
        sha256: huellaDePrueba,
      ));
      expect(find.text('Receta'), findsOneWidget);
      expect(find.text('PDF: /documentos/receta_r1.pdf'), findsOneWidget);
      expect(find.byType(BarraDeAccion), findsOneWidget);
      expect(find.text('Guardar en el teléfono'), findsOneWidget);
      expect(find.text('Compartir'), findsOneWidget);
      expect(find.textContaining('Sin conexión'), findsNothing);
      expect(find.byKey(const Key('aviso-vista-previa')), findsNothing);
    });

    testWidgets('sin firma, la vista previa lo dice arriba', (tester) async {
      await montar(
        tester,
        tipo: TipoDocumentoFirmado.orden,
        id: 'o1',
        nombre: 'Orden de laboratorio G2KKBTJTBK.pdf',
        firmado: false,
      );

      expect(find.text('Orden de exámenes'), findsOneWidget);
      expect(servicio.pedidos.single.sha256, isNull);
      expect(find.byKey(const Key('aviso-vista-previa')), findsOneWidget);
      expect(
        find.text(
          'Vista previa: el médico todavía no firmó electrónicamente este '
          'documento.',
        ),
        findsOneWidget,
      );
      expect(find.text('Guardar en el teléfono'), findsOneWidget);
    });

    testWidgets('si el servidor dice que es la vista previa, también', (
      tester,
    ) async {
      servicio.responder = (tipo, id) async => PdfGuardado(
        tipo: tipo,
        id: id,
        ruta: '/documentos/receta_r1.pdf',
        bytes: pdfDePrueba(),
        sha256: 'ab' * 32,
        sinFirma: true,
      );

      await montar(tester);

      expect(find.byKey(const Key('aviso-vista-previa')), findsOneWidget);
    });

    testWidgets('si el servidor no da el PDF, su mensaje', (tester) async {
      servicio.responder = (_, _) async => throw errorHttp(
        409,
        'El PDF de este documento aún no está disponible.',
      );

      await montar(tester, firmado: false);

      expect(
        find.text('El PDF de este documento aún no está disponible.'),
        findsOneWidget,
      );
      expect(find.byType(BarraDeAccion), findsNothing);
    });

    testWidgets('mientras baja, lo dice y todavía no ofrece guardar', (
      tester,
    ) async {
      final respuesta = Completer<PdfGuardado>();
      servicio.responder = (_, _) => respuesta.future;

      await montar(tester, asentar: false);
      expect(find.text('Descargando el PDF…'), findsOneWidget);
      expect(find.byType(BarraDeAccion), findsNothing);

      respuesta.complete(pdfGuardado());
      await tester.pumpAndSettle();
      expect(find.text('PDF: /documentos/receta_r1.pdf'), findsOneWidget);
    });

    testWidgets('«Guardar en el teléfono» abre el diálogo del sistema', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(find.byKey(const Key('boton-guardar-pdf')));
      await tester.pumpAndSettle();

      expect(salida.guardados.single, (
        ruta: '/documentos/receta_r1.pdf',
        nombre: 'Receta UC7F6DB5UU.pdf',
        mime: 'application/pdf',
      ));
      expect(find.text('Guardamos el PDF en tu teléfono.'), findsOneWidget);
    });

    testWidgets('cerrar el diálogo sin guardar no dice nada; un fallo, sí', (
      tester,
    ) async {
      await montar(tester);

      salida.guardar = false;
      await tester.tap(find.byKey(const Key('boton-guardar-pdf')));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);

      salida.error = Exception('sin espacio');
      await tester.tap(find.byKey(const Key('boton-guardar-pdf')));
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos guardar el PDF. Intenta de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('«Compartir» abre la hoja del sistema con el nombre legible', (
      tester,
    ) async {
      await montar(
        tester,
        tipo: TipoDocumentoFirmado.certificado,
        id: 'c1',
        nombre: 'Certificado de reposo CR7Q2MXK9P.pdf',
      );
      expect(find.text('Certificado de reposo'), findsOneWidget);

      await tester.tap(find.byKey(const Key('boton-compartir-pdf')));
      await tester.pumpAndSettle();

      final compartido = salida.compartidos.single;
      expect(compartido.ruta, '/documentos/certificado_c1.pdf');
      expect(compartido.nombre, 'Certificado de reposo CR7Q2MXK9P.pdf');
      expect(compartido.mime, 'application/pdf');
      expect(compartido.asunto, 'Certificado de reposo');
      // El rectángulo del botón, para la hoja del iPad.
      expect(compartido.origen, isNotNull);
      expect(find.byType(SnackBar), findsNothing);

      salida.error = Exception('nadie con quien compartir');
      await tester.tap(find.byKey(const Key('boton-compartir-pdf')));
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos compartir el PDF. Intenta de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('sin conexión, la copia guardada y el aviso', (tester) async {
      servicio.responder = (tipo, id) async =>
          pdfGuardado(tipo: tipo, id: id, sinConexion: true);

      await montar(tester);

      expect(
        find.text('Sin conexión: es la copia guardada en este teléfono.'),
        findsOneWidget,
      );
      expect(find.text('PDF: /documentos/receta_r1.pdf'), findsOneWidget);
    });

    testWidgets('sin red ni copia: el error y «Reintentar»', (tester) async {
      var intentos = 0;
      servicio.responder = (tipo, id) async {
        if (intentos++ == 0) throw errorDeRed();
        return pdfGuardado(tipo: tipo, id: id);
      };

      await montar(tester);
      expect(
        find.text('Sin conexión con el servidor. Revisa tu Internet.'),
        findsOneWidget,
      );
      expect(find.byType(BarraDeAccion), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('PDF: /documentos/receta_r1.pdf'), findsOneWidget);
      expect(servicio.pedidos, hasLength(2));
    });

    testWidgets('un PDF que no es el firmado lo explica', (tester) async {
      servicio.responder = (_, _) async => throw const PdfNoValido(
        'El PDF que llegó no coincide con el documento firmado. Intenta de '
        'nuevo más tarde.',
      );

      await montar(tester);

      expect(
        find.textContaining('no coincide con el documento firmado'),
        findsOneWidget,
      );
      expect(find.byType(BarraDeAccion), findsNothing);
    });
  });
}
