// lib/features/clinicas/data/empresas_service.dart

import 'package:dio/dio.dart';

import '../../../core/network/api_interceptor.dart';
import '../../auth/data/auth_service.dart';
import '../dominio/clinica.dart';

/// `GET /empresas/publica/:codigo`: la clínica de un código, pública.
///
/// Sirve para comprobar el código que alguien escribe (o que llega en el
/// enlace del registro) y enseñar su nombre y su logotipo antes de entrar.
class EmpresasService {
  static const String ruta = '/empresas/publica';

  final Dio _dio;

  EmpresasService(this._dio);

  /// La clínica de [codigo], o `null` si no existe (404). Un fallo de red o
  /// del servidor se propaga, para decir «revisa tu conexión» y no «ese
  /// código no existe».
  Future<Clinica?> buscar(String codigo) async {
    final limpio = limpiarCodigo(codigo);
    if (limpio.isEmpty) return null;

    try {
      final respuesta = await _dio.get<dynamic>(
        '$ruta/${Uri.encodeComponent(limpio)}',
        options: Options(extra: const {rutaPublica: true}),
      );

      final clinica = Clinica.desdeJson(respuesta.data);
      if (clinica == null) throw const RespuestaInesperada();

      return clinica;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
