// test/logo_clinica_test.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:app_cliniq/core/configuracion/config_publica.dart';
import 'package:app_cliniq/core/configuracion/logo_clinica_service.dart';
import 'package:app_cliniq/core/network/api_interceptor.dart';
import 'package:app_cliniq/core/presentacion/widgets/logo_clinica.dart';
import 'package:app_cliniq/core/presentacion/widgets/logo_cliniq.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/esperas.dart';

/// Un PNG de 1×1.
final Uint8List png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const String dataUrl =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAA'
    'DUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

const String direccion =
    'https://api.clinica.test/api/configuracion/logo?v=3fa9c1d2';
const String direccionNueva =
    'https://api.clinica.test/api/configuracion/logo?v=77b0e4aa';

/// El logotipo de la clínica ahora llega como dirección (sale de MinIO):
/// cómo se lee, cómo se baja y se guarda, qué pasa sin red y cómo se
/// pinta. El data URL de un servidor anterior se sigue aceptando.
void main() {
  group('La dirección del logotipo', () {
    test('una dirección absoluta se baja; un data URL se pinta', () {
      expect(OrigenDelLogo.desde(direccion), LogoEnLaRed(Uri.parse(direccion)));
      expect(OrigenDelLogo.desde('  $direccion  ')!.texto, direccion);
      expect(
        OrigenDelLogo.desde('http://192.168.1.10:3000/api/configuracion/logo'),
        isA<LogoEnLaRed>(),
      );
      expect(OrigenDelLogo.desde(dataUrl), const LogoEnDataUrl(dataUrl));
    });

    test('lo demás no es un logotipo: queda el de marca', () {
      for (final valor in [
        null,
        '',
        '   ',
        '/api/configuracion/logo?v=1',
        'configuracion/logo',
        'ftp://api.clinica.test/logo.png',
        'javascript:alert(1)',
        'https:///sin-servidor.png',
        'data:text/html;base64,PGgxPkhvbGE8L2gxPg==',
      ]) {
        expect(OrigenDelLogo.desde(valor), isNull, reason: '$valor');
      }
    });

    test('la configuración lo lee sin descartar el resto', () {
      final conUrl = configDePrueba(clinica: {'logo': direccion});
      expect(conUrl.clinica.logo, direccion);
      expect(conUrl.clinica.origenDelLogo, LogoEnLaRed(Uri.parse(direccion)));

      final conDataUrl = configDePrueba(clinica: {'logo': dataUrl});
      expect(conDataUrl.clinica.origenDelLogo, isA<LogoEnDataUrl>());

      final relativa = configDePrueba(
        clinica: {'logo': '/api/configuracion/logo'},
      );
      expect(relativa.clinica.logo, isNull);
      expect(relativa.clinica.nombre, 'Clínica Andina');

      expect(configDePrueba().clinica.origenDelLogo, isNull);

      // Lo que ni siquiera es texto sigue siendo una respuesta mal formada.
      expect(
        () => configDePrueba(clinica: {'logo': 42}),
        throwsFormatException,
      );
    });
  });

  group('El servicio', () {
    late CacheLocal cache;
    late DioGrabador api;
    late bool hayRed;
    late Object? servido;

    setUp(() {
      cache = CacheEnMemoria();
      hayRed = true;
      servido = png;
      Object? responder(_) {
        if (!hayRed) throw errorDeRed();
        return servido;
      }

      api = DioGrabador({
        'GET $direccion': responder,
        'GET $direccionNueva': responder,
      });
    });

    LogoClinicaService servicio() => LogoClinicaService(api.dio, cache);

    test('se baja sin la sesión y se guarda como dato de la clínica', () async {
      final imagen = await servicio().obtener(Uri.parse(direccion));

      expect(imagen, ImagenDeLogo('image/png', png));
      final pedido = api.ultimo('GET $direccion');
      expect(pedido.extra[rutaPublica], isTrue);
      expect(pedido.headers['Accept'], 'image/*');

      // Sobrevive al cierre de sesión, como la configuración.
      await cache.vaciarDatosPersonales();
      expect(await cache.leer(LogoClinicaService.claveCache), isNotNull);
    });

    test('la misma dirección no se vuelve a pedir: sale de la copia', () async {
      await servicio().obtener(Uri.parse(direccion));
      hayRed = false;

      // Otro arranque de la aplicación: sin nada en memoria.
      final otraVez = await servicio().obtener(Uri.parse(direccion));

      expect(otraVez!.bytes, png);
      expect(api.pedidos, hasLength(1));
    });

    test(
      'una dirección nueva (otro ?v=) se baja y reemplaza la copia',
      () async {
        await servicio().obtener(Uri.parse(direccion));

        final svg = utf8.encode(
          '<?xml version="1.0"?><svg xmlns="http://www.w3.org/2000/svg"/>',
        );
        servido = Uint8List.fromList(svg);
        final nueva = await servicio().obtener(Uri.parse(direccionNueva));

        expect(api.claves.last, 'GET $direccionNueva');
        // Reconocido por su contenido: el servidor de prueba no manda tipo.
        expect(nueva!.esSvg, isTrue);
        final copia = await cache.leer(LogoClinicaService.claveCache) as Map;
        expect(copia['url'], direccionNueva);
      },
    );

    test('sin red, la copia anterior aunque sea de otra dirección', () async {
      await servicio().obtener(Uri.parse(direccion));
      hayRed = false;

      final sinRed = servicio();
      final imagen = await sinRed.obtener(Uri.parse(direccionNueva));
      expect(imagen!.bytes, png);

      // Queda en memoria: no se insiste en cada pantalla.
      await sinRed.obtener(Uri.parse(direccionNueva));
      expect(api.claves.where((c) => c == 'GET $direccionNueva'), hasLength(1));
    });

    test('sin red ni copia, ninguno: se verá el de marca', () async {
      hayRed = false;

      expect(await servicio().obtener(Uri.parse(direccion)), isNull);
    });

    test('lo que no es una imagen no se guarda', () async {
      servido = Uint8List.fromList(utf8.encode('<html>portal cautivo</html>'));

      expect(await servicio().obtener(Uri.parse(direccion)), isNull);
      expect(await cache.leer(LogoClinicaService.claveCache), isNull);
    });

    test('varias pantallas a la vez comparten la petición', () async {
      final uno = servicio();
      final url = Uri.parse(direccion);

      final resultados = await Future.wait([
        uno.obtener(url),
        uno.obtener(url),
      ]);

      expect(resultados.every((i) => i != null), isTrue);
      expect(api.pedidos, hasLength(1));
      expect(uno.enMemoria(url), isNotNull);
    });

    test('el tipo: el del servidor si es de imagen; si no, el contenido', () {
      expect(tipoDeImagen(png, 'image/png'), 'image/png');
      expect(tipoDeImagen(png, 'application/octet-stream'), 'image/png');
      expect(
        tipoDeImagen(Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]), null),
        'image/jpeg',
      );
      expect(
        tipoDeImagen(Uint8List.fromList(utf8.encode('hola')), null),
        isNull,
      );
    });
  });

  group('El logotipo en pantalla', () {
    late DioGrabador api;
    late bool hayRed;
    late LogoClinicaService servicio;

    setUp(() {
      hayRed = true;
      api = DioGrabador({
        'GET $direccion': (_) {
          if (!hayRed) throw errorDeRed();
          return png;
        },
      });
      servicio = LogoClinicaService(api.dio, CacheEnMemoria());
    });

    Future<void> montar(WidgetTester tester, {String? logo}) {
      return tester.pumpWidget(
        conDatosDeLaClinica(
          config: configDePrueba(clinica: {'logo': logo}),
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: LogoDeLaClinica(
                  tamano: 96,
                  insignia: true,
                  servicio: servicio,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('con dirección, se baja y reemplaza al de marca', (
      tester,
    ) async {
      await montar(tester, logo: direccion);

      // Mientras baja, el hueco del mismo tamaño (no el de marca un instante).
      expect(find.byKey(const Key('logo-bajando')), findsOneWidget);
      expect(find.byType(InsigniaCliniq), findsNothing);

      await esperarHasta(
        tester,
        () => find.byType(Image).evaluate().isNotEmpty,
      );

      expect(find.byType(InsigniaCliniq), findsNothing);
      expect(api.claves, ['GET $direccion']);
    });

    testWidgets('ya bajado, se pinta desde el primer cuadro', (tester) async {
      await tester.runAsync(() => servicio.obtener(Uri.parse(direccion)));

      await montar(tester, logo: direccion);

      expect(find.byType(Image), findsOneWidget);
      expect(find.byKey(const Key('logo-bajando')), findsNothing);
    });

    testWidgets('sin red ni copia, el de marca', (tester) async {
      hayRed = false;
      await montar(tester, logo: direccion);

      await esperarHasta(
        tester,
        () => find.byType(InsigniaCliniq).evaluate().isNotEmpty,
      );
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('el data URL de un servidor anterior se pinta sin pedir nada', (
      tester,
    ) async {
      await montar(tester, logo: dataUrl);

      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(InsigniaCliniq), findsNothing);
      expect(api.pedidos, isEmpty);
    });

    testWidgets('sin logotipo, el de marca y ninguna petición', (tester) async {
      await montar(tester);

      expect(find.byType(InsigniaCliniq), findsOneWidget);
      expect(api.pedidos, isEmpty);
    });
  });
}
