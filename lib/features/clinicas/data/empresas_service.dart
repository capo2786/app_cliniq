// lib/features/clinicas/data/empresas_service.dart

import 'package:dio/dio.dart';

import '../../../core/network/api_interceptor.dart';
import '../../../core/network/interceptor_de_empresa.dart';
import '../../auth/data/auth_service.dart';
import '../dominio/clinica.dart';

/// La clínica del código existe pero no está disponible (suspendida): la API
/// responde 403 «Esta clínica no está disponible».
class ClinicaNoDisponible implements Exception {
  const ClinicaNoDisponible();

  @override
  String toString() => 'ClinicaNoDisponible';
}

/// `GET /empresas/publica/:codigo`: la clínica de un código, pública.
///
/// Sirve para comprobar el código que alguien escribe (o que llega en el
/// enlace del registro) y enseñar su nombre y su logotipo antes de entrar.
class EmpresasService {
  static const String ruta = '/empresas/publica';

  final Dio _dio;

  EmpresasService(this._dio);

  /// La clínica de [codigo], o `null` si no existe (404). Si existe pero
  /// está suspendida (403), [ClinicaNoDisponible]. Un fallo de red o del
  /// servidor se propaga, para decir «revisa tu conexión» y no «ese código
  /// no existe».
  Future<Clinica?> buscar(String codigo) async {
    final limpio = limpiarCodigo(codigo);
    if (limpio.isEmpty) return null;

    try {
      final respuesta = await _dio.get<dynamic>(
        '$ruta/${Uri.encodeComponent(limpio)}',
        // Sin `X-Empresa`: la clínica es la del código, no la guardada.
        options: Options(extra: const {rutaPublica: true, sinEmpresa: true}),
      );

      final clinica = Clinica.desdeJson(respuesta.data);
      if (clinica == null) throw const RespuestaInesperada();

      return clinica;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      // Esta ruta es pública: su 403 no es de permisos, es la clínica.
      if (error.response?.statusCode == 403) throw const ClinicaNoDisponible();
      rethrow;
    }
  }
}
