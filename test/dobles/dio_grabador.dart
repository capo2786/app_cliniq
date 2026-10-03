// test/dobles/dio_grabador.dart

import 'package:dio/dio.dart';

/// Un Dio que anota cada petición y contesta desde una tabla de rutas.
///
/// La clave es el método y la ruta tal como la arma el servicio
/// (`'POST /portal/consultas/c1/enviar'`), sin la consulta. La respuesta
/// es el cuerpo que devolvería la API, o un `Response` entero si importan
/// sus cabeceras; para simular un error, la función lanza un
/// `DioException` (ver `errorHttp` y `errorDeRed` en `dobles.dart`).
class DioGrabador {
  final Map<String, Object? Function(RequestOptions pedido)> rutas;
  final List<RequestOptions> pedidos = [];
  late final Dio dio;

  DioGrabador([Map<String, Object? Function(RequestOptions pedido)>? rutas])
    : rutas = rutas ?? {} {
    dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (pedido, manejador) {
          pedidos.add(pedido);

          final responder = this.rutas['${pedido.method} ${pedido.path}'];

          if (responder == null) {
            manejador.reject(
              DioException(
                requestOptions: pedido,
                type: DioExceptionType.badResponse,
                response: Response<dynamic>(
                  requestOptions: pedido,
                  statusCode: 404,
                  data: {'status': 404, 'message': 'No existe'},
                ),
              ),
            );
            return;
          }

          try {
            final respuesta = responder(pedido);
            manejador.resolve(
              Response<dynamic>(
                requestOptions: pedido,
                statusCode: respuesta is Response
                    ? respuesta.statusCode
                    : (pedido.method == 'POST' ? 201 : 200),
                headers: respuesta is Response ? respuesta.headers : null,
                data: respuesta is Response ? respuesta.data : respuesta,
              ),
            );
          } on DioException catch (error) {
            manejador.reject(
              DioException(
                requestOptions: pedido,
                type: error.type,
                response: error.response == null
                    ? null
                    : Response<dynamic>(
                        requestOptions: pedido,
                        statusCode: error.response!.statusCode,
                        data: error.response!.data,
                      ),
                error: error.error,
              ),
            );
          }
        },
      ),
    );
  }

  /// Las peticiones como `'MÉTODO /ruta'`, en orden.
  List<String> get claves => [for (final p in pedidos) '${p.method} ${p.path}'];

  /// La última petición a esa clave.
  RequestOptions ultimo(String clave) =>
      pedidos.lastWhere((p) => '${p.method} ${p.path}' == clave);
}
