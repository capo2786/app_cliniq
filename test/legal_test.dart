// test/legal_test.dart

import 'package:app_cliniq/core/network/api_interceptor.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/legal/data/legal_service.dart';
import 'package:app_cliniq/features/legal/providers/legal_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';

/// Los documentos legales salen de la API: títulos, versiones y nombres
/// cortos; la aplicación no guarda ninguno escrito.
void main() {
  late CacheLocal cache;
  late bool hayRed;
  late DioGrabador api;
  late Map<String, dynamic> misAceptaciones;

  final documentos = [
    {
      'clave': 'TERMINOS',
      'slug': 'terminos-de-uso',
      'version': '2.0',
      'titulo': 'Términos de uso de la clínica',
      'resumen': 'Lo básico',
      'tipos': ['3', '2'],
      'vigenteDesde': '2026-09-01',
    },
    {
      'clave': 'CONTRATO_MEDICO',
      'slug': 'contrato-medico',
      'version': '1.0',
      'titulo': 'Condiciones para profesionales',
      'tipos': ['2'],
    },
    {'clave': 'SIN_SLUG', 'titulo': 'Se descarta'},
  ];

  setUp(() {
    cache = CacheEnMemoria();
    hayRed = true;
    misAceptaciones = {
      'aceptaciones': [
        // Sin título ni slug: salen de la lista de documentos.
        {'clave': 'TERMINOS', 'version': '2.0'},
        // Una clave que la lista no tiene: su clave, sin enlace.
        {'clave': 'VIEJO', 'version': '1.0'},
      ],
      'pendientes': <Object?>[],
    };
    api = DioGrabador({
      'GET /legal/documentos': (_) {
        if (!hayRed) throw errorDeRed();
        return documentos;
      },
      'GET /legal/mis-aceptaciones': (_) => misAceptaciones,
    });
  });

  LegalService servicio() => LegalService(api.dio, cache);

  test('GET /legal/documentos es pública y trae clave, slug, versión, '
      'título y a quién aplica', () async {
    final lista = await servicio().documentos();

    final pedido = api.ultimo('GET /legal/documentos');
    expect(pedido.extra[rutaPublica], isTrue);
    expect(lista.map((d) => d.clave), ['TERMINOS', 'CONTRATO_MEDICO']);
    expect(lista.first.slug, 'terminos-de-uso');
    expect(lista.first.titulo, 'Términos de uso de la clínica');
    expect(
      lista.first.url,
      'https://cliniq.gcaicedo-proyectos.com/legal/terminos-de-uso',
    );
    expect(lista.first.aplicaA(3), isTrue);
    expect(lista.last.aplicaA(3), isFalse);
  });

  test('sin red, la última lista guardada; sin copia, el error', () async {
    await servicio().documentos();
    hayRed = false;

    expect(await servicio().documentos(), hasLength(2));

    await cache.guardar(LegalService.claveCache, null);
    await expectLater(servicio().documentos(), throwsA(anything));
  });

  test('lo que mis-aceptaciones no trae se completa con la lista; lo que '
      'nadie sabe queda con su clave y sin enlace', () async {
    final lista = await servicio().documentos();
    final datos = await servicio().misAceptaciones(documentos: lista);

    final terminos = datos.aceptaciones.first;
    expect(terminos.titulo, 'Términos de uso de la clínica');
    expect(terminos.slug, 'terminos-de-uso');

    final viejo = datos.aceptaciones.last;
    expect(viejo.titulo, 'VIEJO');
    expect(viejo.url, isNull);
  });

  test('el bloc carga la lista y las aceptaciones; sin lista, sigue', () async {
    final bloc = LegalBloc(servicio())..add(const LegalSolicitado());
    final s = await bloc.stream.firstWhere((s) => !s.cargando);

    expect(s.documentos, hasLength(2));
    expect(s.aceptaciones.first.slug, 'terminos-de-uso');
    expect(s.completo, isTrue);
    await bloc.close();

    hayRed = false;
    cache = CacheEnMemoria();
    final sinLista = LegalBloc(servicio())..add(const LegalSolicitado());
    final t = await sinLista.stream.firstWhere((s) => !s.cargando);

    expect(t.documentos, isEmpty);
    expect(t.error, isNull);
    expect(t.aceptaciones.first.titulo, 'TERMINOS');
    await sinLista.close();
  });
}
