// test/dobles/adaptador_http.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Una respuesta programada: código y cuerpo.
typedef Respuesta = ({int estado, Object? cuerpo});

/// Un adaptador HTTP que contesta desde una tabla de rutas.
///
/// Se enchufa en `ApiClient().dio` para que la aplicación entera —con sus
/// servicios de verdad, sus interceptores y su caché— hable con una API de
/// mentira sin salir a la red.
class AdaptadorHttpFalso implements HttpClientAdapter {
  /// `'GET /agenda/paciente/mis-citas'` → respuesta. El método y la ruta,
  /// sin la base ni la consulta.
  final Map<String, Respuesta Function(RequestOptions opciones)> rutas;

  final List<String> pedidas = [];

  AdaptadorHttpFalso(this.rutas);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final ruta = Uri.parse(options.uri.toString()).path
        .replaceFirst('/api', '');
    final clave = '${options.method} ${ruta.isEmpty ? '/' : ruta}';
    pedidas.add(clave);

    final responder = rutas[clave];
    final respuesta =
        responder?.call(options) ??
        (estado: 404, cuerpo: {'status': 404, 'message': 'No existe $clave'});

    final cuerpo = respuesta.cuerpo;
    final esTexto = cuerpo is String;

    return ResponseBody.fromString(
      esTexto ? cuerpo : jsonEncode(cuerpo),
      respuesta.estado,
      headers: {
        Headers.contentTypeHeader: [
          esTexto ? 'text/html; charset=utf-8' : 'application/json',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
