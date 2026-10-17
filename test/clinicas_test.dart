// test/clinicas_test.dart

import 'dart:convert';

import 'package:app_cliniq/core/network/interceptor_de_empresa.dart';
import 'package:app_cliniq/core/storage/almacen_claves.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/auth/data/errores_de_acceso.dart';
import 'package:app_cliniq/features/auth/data/models/usuario.dart';
import 'package:app_cliniq/features/clinicas/data/almacen_de_clinica.dart';
import 'package:app_cliniq/features/clinicas/data/empresas_service.dart';
import 'package:app_cliniq/features/clinicas/dominio/clinica.dart';
import 'package:app_cliniq/features/clinicas/providers/clinica_cubit.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/adaptador_http.dart';
import 'dobles/clinicas.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';

/// La clínica de la aplicación: cómo se lee, cómo se guarda, qué va en
/// `X-Empresa` y cuándo cambia.
void main() {
  tearDown(() => EmpresaDeLasPeticiones.codigo = null);

  group('La clínica', () {
    test('se lee de la API con su marca, y sin código no es una clínica', () {
      final clinica = Clinica.desdeJson({
        'codigo': ' demo ',
        'nombre': 'Clínica Demo',
        'logoUrl': '/api/configuracion/logo?e=demo',
        'colorPrimario': '#123456',
        'colorAcento': 'rojo',
      })!;

      expect(clinica.codigo, 'demo');
      expect(clinica.nombre, 'Clínica Demo');
      expect(clinica.colorPrimario, '#123456');
      expect(clinica.colorAcento, isNull);
      expect(Clinica.desdeJson({'nombre': 'Sin código'}), isNull);
      expect(Clinica.desdeJson('Empresa del paciente'), isNull);
      // Sin nombre, el código.
      expect(Clinica.desdeJson({'codigo': 'x1'})!.nombre, 'x1');
      // Ida y vuelta por el JSON guardado.
      expect(Clinica.desdeJson(clinica.aJson()), clinica);
    });

    test('el código: sin espacios, y lo que no puede ser uno se dice', () {
      expect(limpiarCodigo(' cli nica '), 'clinica');
      expect(errorDeCodigo(''), 'Escribe el código que te dio tu clínica.');
      expect(errorDeCodigo('ab/c'), contains('letras, números y guiones'));
      expect(errorDeCodigo('a' * 41), contains('largo'));
      expect(errorDeCodigo('Clinica-Andina_2'), isNull);
      expect(mismoCodigo('Demo', 'demo'), isTrue);
      expect(mismoCodigo('demo', null), isFalse);
    });

    test('las iniciales para cuando no hay logotipo', () {
      expect(clinicaAndina.iniciales, 'CA');
      expect(clinicaDelSur.iniciales, 'CM');
      expect(const Clinica(codigo: 'x', nombre: 'Vida').iniciales, 'VI');
      expect(const Clinica(codigo: 'x', nombre: '  ').iniciales, '?');
    });

    test(
      'la dirección del logotipo: absoluta tal cual, relativa con la API',
      () {
        const api = 'https://api.cliniq.ec/api';
        Uri? logo(String? url) => direccionDelLogo(
          Clinica(codigo: 'demo', nombre: 'Demo', logoUrl: url),
          api,
        );

        expect(
          logo('https://cdn.ec/logo.png').toString(),
          'https://cdn.ec/logo.png',
        );
        expect(
          logo('/api/configuracion/logo?e=demo').toString(),
          'https://api.cliniq.ec/api/configuracion/logo?e=demo',
        );
        expect(
          logo('configuracion/logo').toString(),
          'https://api.cliniq.ec/api/configuracion/logo',
        );
        expect(logo(null), isNull);
        expect(logo('ftp://x/logo.png'), isNull);
        expect(logo('data:image/png;base64,AAAA'), isNull);
      },
    );

    test('la clínica del token, para cuando el perfil no la trae', () {
      String token(Map<String, dynamic> carga) =>
          'cabecera.${base64Url.encode(utf8.encode(jsonEncode(carga))).replaceAll('=', '')}.firma';

      expect(
        clinicaDelToken(token({'sub': 'u1', 'empresaCodigo': 'demo'})),
        const Clinica(codigo: 'demo', nombre: 'demo'),
      );
      expect(clinicaDelToken(token({'sub': 'u1'})), isNull);
      expect(clinicaDelToken('no-es-un-jwt'), isNull);
      expect(clinicaDelToken(null), isNull);
    });

    test('el usuario: la clínica de la sesión es empresaSesion, y la '
        '«empresa» de texto (su empleador) no se toma por clínica', () {
      final conSesion = Usuario.desdeJson({
        'uid': 'u1',
        'empresa': 'Banco del Pichincha',
        'empresaSesion': {'id': 'e2', 'codigo': 'demo', 'nombre': 'Demo'},
      });
      final empleador = Usuario.desdeJson({
        'uid': 'u1',
        'empresa': 'Banco del Pichincha',
      });
      final comoObjeto = Usuario.desdeJson({
        'uid': 'u1',
        'empresa': {'id': 'e2', 'codigo': 'demo', 'nombre': 'Demo'},
      });

      expect(conSesion.clinicaDeLaSesion?.codigo, 'demo');
      expect(conSesion.datos['empresa'], 'Banco del Pichincha');
      expect(empleador.clinicaDeLaSesion, isNull);
      expect(comoObjeto.clinicaDeLaSesion?.nombre, 'Demo');
    });

    test('el 409 EMPRESA_AMBIGUA trae las clínicas para elegir', () {
      expect(
        clinicasParaElegir(errorEmpresaAmbigua([clinicaAndina, clinicaDelSur])),
        [
          clinicaAndina,
          Clinica(
            codigo: 'sur',
            nombre: clinicaDelSur.nombre,
            logoUrl: clinicaDelSur.logoUrl,
            colorPrimario: clinicaDelSur.colorPrimario,
            colorAcento: clinicaDelSur.colorAcento,
          ),
        ],
      );
      expect(clinicasParaElegir(errorEmpresaAmbigua([])), isNull);
      expect(clinicasParaElegir(errorHttp(409, 'Choca')), isNull);
      expect(clinicasParaElegir(errorHttp(401)), isNull);
      expect(clinicasParaElegir(Exception('x')), isNull);
    });
  });

  group('La cabecera X-Empresa', () {
    test('solo sin sesión, y sin pisar la que ya trae la petición', () {
      expect(empresaParaLaPeticion(cabeceras: {}, guardada: 'demo'), 'demo');
      expect(empresaParaLaPeticion(cabeceras: {}, guardada: null), isNull);
      expect(empresaParaLaPeticion(cabeceras: {}, guardada: ' '), isNull);
      expect(
        empresaParaLaPeticion(
          cabeceras: {'Authorization': 'Bearer t'},
          guardada: 'demo',
        ),
        isNull,
      );
      expect(
        empresaParaLaPeticion(
          cabeceras: {'x-empresa': 'sur'},
          guardada: 'demo',
        ),
        isNull,
      );
    });

    test('el interceptor la pone en lo público y no con el token', () async {
      final adaptador = AdaptadorHttpFalso({
        'GET /configuracion/publica': (_) => (estado: 200, cuerpo: {}),
        'GET /portal/mis-citas': (_) => (estado: 200, cuerpo: []),
      });
      final cabeceras = <String, Map<String, dynamic>>{};
      final dio = Dio(BaseOptions(baseUrl: 'https://api.ec/api'))
        ..httpClientAdapter = adaptador
        ..interceptors.add(InterceptorDeEmpresa(leerCodigo: () => 'demo'))
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (o, h) {
              cabeceras[o.path] = Map.of(o.headers);
              h.next(o);
            },
          ),
        );

      await dio.get<dynamic>('/configuracion/publica');
      await dio.get<dynamic>(
        '/portal/mis-citas',
        options: Options(headers: {'Authorization': 'Bearer t'}),
      );

      expect(cabeceras['/configuracion/publica']![cabeceraEmpresa], 'demo');
      expect(
        cabeceras['/portal/mis-citas']!.containsKey(cabeceraEmpresa),
        isFalse,
      );
    });
  });

  group('Guardar y buscar', () {
    test('el almacén guarda la clínica y lee nada si está dañada', () async {
      final llavero = AlmacenClavesEnMemoria();
      final almacen = AlmacenDeClinica(llavero);

      expect(await almacen.leer(), isNull);
      await almacen.guardar(clinicaDelSur);
      expect(await almacen.leer(), clinicaDelSur);

      llavero.valores[AlmacenDeClinica.clave] = '{no es json';
      expect(await almacen.leer(), isNull);

      await almacen.borrar();
      expect(llavero.valores, isEmpty);
    });

    test('el servicio: la clínica del código, null con 404 y el error de '
        'red se propaga', () async {
      final api = DioGrabador({
        'GET /empresas/publica/demo': (_) => {
          'codigo': 'demo',
          'nombre': 'Clínica Demo',
          'colorPrimario': '#112233',
          'colorAcento': '#445566',
        },
        'GET /empresas/publica/caida': (_) => throw errorDeRed(),
        'GET /empresas/publica/cerrada': (_) =>
            throw errorClinicaNoDisponible(),
      });
      final servicio = EmpresasService(api.dio);

      expect((await servicio.buscar(' demo '))?.nombre, 'Clínica Demo');
      expect(api.pedidos.single.extra['cliniq.rutaPublica'], isTrue);
      expect(await servicio.buscar('nadie'), isNull);
      expect(await servicio.buscar(''), isNull);
      await expectLater(servicio.buscar('caida'), throwsA(isA<DioException>()));
      // Suspendida: existe, pero no está disponible (403, antes 404).
      await expectLater(
        servicio.buscar('cerrada'),
        throwsA(isA<ClinicaNoDisponible>()),
      );
    });
  });

  group('El cubit de la clínica', () {
    test('arranca con la guardada y la pone en la cabecera', () {
      final prueba = clinicaCubitDePrueba(inicial: clinicaAndina);
      addTearDown(prueba.cubit.close);

      expect(prueba.cubit.clinica, clinicaAndina);
      expect(EmpresaDeLasPeticiones.codigo, 'andina');
    });

    test('buscar no elige; elegir otra guarda, olvida lo de la anterior y '
        'avisa el cambio', () async {
      final cache = CacheEnMemoria();
      await cache.guardar('configuracion:publica', {'de': 'andina'});
      await cache.guardar('citas:u1', []);

      final prueba = clinicaCubitDePrueba(
        inicial: clinicaAndina,
        olvidarDatos: cache.vaciarDatosDeLaClinica,
      );
      final cubit = prueba.cubit;
      addTearDown(cubit.close);

      final resultado = await cubit.buscar('sur');
      expect(resultado, isA<CodigoEncontrado>());
      expect(cubit.clinica, clinicaAndina);

      await cubit.elegir((resultado as CodigoEncontrado).clinica);

      expect(cubit.state.cambios, 1);
      expect(cubit.clinica?.codigo, 'sur');
      expect(EmpresaDeLasPeticiones.codigo, 'sur');
      expect(await cache.leer('configuracion:publica'), isNull);
      expect(await cache.leer('citas:u1'), isNotNull);
      expect(await AlmacenDeClinica(prueba.llavero).leer(), cubit.clinica);
    });

    test('la misma clínica no es un cambio: solo se refresca su marca, con '
        'el código del servidor', () async {
      var olvidos = 0;
      final prueba = clinicaCubitDePrueba(
        inicial: clinicaAndina,
        olvidarDatos: () async => olvidos++,
      );
      addTearDown(prueba.cubit.close);

      await prueba.cubit.elegir(
        const Clinica(codigo: 'ANDINA', nombre: 'Clínica Andina S.A.'),
      );

      expect(prueba.cubit.state.cambios, 0);
      expect(olvidos, 0);
      expect(prueba.cubit.clinica?.codigo, 'ANDINA');
      expect(prueba.cubit.clinica?.nombre, 'Clínica Andina S.A.');
      // Lo que no llegó se conserva.
      expect(prueba.cubit.clinica?.colorPrimario, '#1E5AA8');
    });

    test('un código desconocido o sin red se dice con su mensaje', () async {
      final prueba = clinicaCubitDePrueba();
      addTearDown(prueba.cubit.close);

      final desconocido = await prueba.cubit.buscar('nadie');
      expect(desconocido, isA<CodigoDesconocido>());
      expect(
        mensajeDeBusqueda(desconocido, ' nadie'),
        'No encontramos ninguna clínica con el código «nadie». Revísalo con '
        'tu clínica.',
      );

      prueba.api.rutas['GET /empresas/publica/caida'] = (_) =>
          throw errorDeRed();
      final sinRed = await prueba.cubit.buscar('caida');
      expect(sinRed, isA<CodigoSinRespuesta>());
      expect(mensajeDeBusqueda(sinRed, 'caida'), contains('Sin conexión'));
      expect(prueba.cubit.clinica, isNull);
    });

    test('una clínica suspendida (403) tiene su propio mensaje, y no es «sin '
        'conexión» ni «no tienes permiso»', () async {
      final prueba = clinicaCubitDePrueba();
      addTearDown(prueba.cubit.close);

      final resultado = await prueba.cubit.buscar(' cerrada ');

      expect(resultado, isA<CodigoNoDisponible>());
      expect(
        mensajeDeBusqueda(resultado, ' cerrada '),
        'La clínica «cerrada» no está disponible por ahora. Consulta con tu '
        'clínica.',
      );
      expect(prueba.cubit.clinica, isNull);
    });

    test('olvidar quita la cabecera y la guardada; al entrar manda la de la '
        'cuenta', () async {
      final prueba = clinicaCubitDePrueba(inicial: clinicaAndina);
      final cubit = prueba.cubit;
      addTearDown(cubit.close);

      await cubit.olvidar();
      expect(cubit.clinica, isNull);
      expect(cubit.state.cambios, 1);
      expect(EmpresaDeLasPeticiones.codigo, isNull);
      expect(prueba.llavero.valores, isEmpty);

      await cubit.alEntrar(null);
      expect(cubit.clinica, isNull);

      await cubit.alEntrar(const Clinica(codigo: 'sur', nombre: 'Del Sur'));
      expect(cubit.clinica?.codigo, 'sur');
      expect(EmpresaDeLasPeticiones.codigo, 'sur');
    });

    test('la marca de la configuración se copia en la guardada', () async {
      final prueba = clinicaCubitDePrueba(
        inicial: const Clinica(codigo: 'sur', nombre: 'sur'),
      );
      addTearDown(prueba.cubit.close);

      await prueba.cubit.actualizarMarca(
        nombre: 'Centro Médico del Sur',
        logoUrl: 'https://api.ec/api/configuracion/logo?v=1',
        colorPrimario: '#2E7D32',
        colorAcento: 'no',
      );

      final guardada = await AlmacenDeClinica(prueba.llavero).leer();
      expect(guardada?.nombre, 'Centro Médico del Sur');
      expect(guardada?.colorPrimario, '#2E7D32');
      expect(guardada?.colorAcento, isNull);
      expect(prueba.cubit.state.cambios, 0);
    });

    test('cargar lee la guardada si no arrancó con una', () async {
      final prueba = clinicaCubitDePrueba();
      addTearDown(prueba.cubit.close);
      await AlmacenDeClinica(prueba.llavero).guardar(clinicaDelSur);

      await prueba.cubit.cargar();

      expect(prueba.cubit.clinica, clinicaDelSur);
      expect(EmpresaDeLasPeticiones.codigo, 'sur');
    });
  });
}
