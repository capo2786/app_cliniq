// test/dobles/clinicas.dart

/// Clínicas de prueba y lo que hace falta para montar su cubit sin red.
library;

import 'package:app_cliniq/core/storage/almacen_claves.dart';
import 'package:app_cliniq/features/clinicas/data/almacen_de_clinica.dart';
import 'package:app_cliniq/features/clinicas/data/empresas_service.dart';
import 'package:app_cliniq/features/clinicas/dominio/clinica.dart';
import 'package:app_cliniq/features/clinicas/providers/clinica_cubit.dart';
import 'package:dio/dio.dart';

import 'dio_grabador.dart';

const Clinica clinicaAndina = Clinica(
  codigo: 'andina',
  nombre: 'Clínica Andina',
  colorPrimario: '#1E5AA8',
);

const Clinica clinicaDelSur = Clinica(
  codigo: 'sur',
  nombre: 'Centro Médico del Sur',
  logoUrl: 'https://api.ejemplo.ec/api/configuracion/logo?e=sur',
  colorPrimario: '#2E7D32',
  colorAcento: '#F9A825',
);

/// El 409 del acceso cuando el correo está en varias clínicas.
DioException errorEmpresaAmbigua(List<Clinica> clinicas) {
  final opciones = RequestOptions(path: '/auth/login');

  return DioException(
    requestOptions: opciones,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: opciones,
      statusCode: 409,
      data: {
        'status': 409,
        'codigo': 'EMPRESA_AMBIGUA',
        'message': 'Tu correo está en varias clínicas.',
        'empresas': [for (final c in clinicas) c.aJson()],
      },
    ),
  );
}

/// El cuerpo del 403 de una clínica suspendida, como lo manda el gateway
/// (en `/empresas/publica/:codigo` y en lo que lleva su `X-Empresa`).
const Map<String, Object> cuerpoClinicaNoDisponible = {
  'status': 403,
  'message': 'Esta clínica no está disponible',
  'codigo': 'EMPRESA_NO_DISPONIBLE',
};

/// El 403 de una clínica suspendida, para lanzarlo desde un [DioGrabador].
DioException errorClinicaNoDisponible([String ruta = '/prueba']) {
  final opciones = RequestOptions(path: ruta);

  return DioException(
    requestOptions: opciones,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: opciones,
      statusCode: 403,
      data: cuerpoClinicaNoDisponible,
    ),
  );
}

/// `GET /empresas/publica/:codigo` que conoce estas clínicas; las de
/// [suspendidas] responden 403.
DioGrabador empresasConocidas(
  List<Clinica> clinicas, {
  List<String> suspendidas = const [],
}) => DioGrabador({
  for (final c in clinicas)
    'GET ${EmpresasService.ruta}/${c.codigo}': (_) => c.aJson(),
  for (final codigo in suspendidas)
    'GET ${EmpresasService.ruta}/$codigo': (_) =>
        throw errorClinicaNoDisponible(),
});

/// Un [ClinicaCubit] con el llavero en memoria y las clínicas dadas.
({ClinicaCubit cubit, AlmacenClavesEnMemoria llavero, DioGrabador api})
clinicaCubitDePrueba({
  Clinica? inicial,
  List<Clinica> conocidas = const [clinicaAndina, clinicaDelSur],
  List<String> suspendidas = const ['cerrada'],
  Future<void> Function()? olvidarDatos,
}) {
  final llavero = AlmacenClavesEnMemoria();
  final api = empresasConocidas(conocidas, suspendidas: suspendidas);

  return (
    cubit: ClinicaCubit(
      almacen: AlmacenDeClinica(llavero),
      empresas: EmpresasService(api.dio),
      olvidarDatosDeLaClinica: olvidarDatos,
      inicial: inicial,
    ),
    llavero: llavero,
    api: api,
  );
}
