// test/errores_test.dart

import 'package:app_cliniq/core/network/api_interceptor.dart';
import 'package:app_cliniq/core/network/errores.dart';
import 'package:app_cliniq/core/red/estado_de_la_red.dart';
import 'package:app_cliniq/features/auth/data/errores_de_acceso.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dobles.dart';

/// La traducción de errores: la API responde `{status, message}` y `message`
/// puede ser un texto o una lista (las validaciones de NestJS).
void main() {
  group('mensajeDeError', () {
    test('el texto del servidor gana a cualquier genérico', () {
      expect(
        mensajeDeError(errorHttp(409, 'Ese horario ya está ocupado.')),
        'Ese horario ya está ocupado.',
      );
    });

    test('una lista de validaciones se junta en líneas', () {
      expect(
        mensajeDeError(
          errorHttp(400, [
            'start debe tener el formato YYYY-MM-DDTHH:mm:ss',
            'Seleccione un médico',
          ]),
        ),
        'start debe tener el formato YYYY-MM-DDTHH:mm:ss\nSeleccione un médico',
      );
    });

    test('sin mensaje, uno por código', () {
      expect(mensajeDeError(errorHttp(403)), contains('permiso'));
      expect(mensajeDeError(errorHttp(423)), contains('15 minutos'));
      expect(mensajeDeError(errorHttp(503)), contains('servidor'));
    });

    test('sin red o sin respuesta a tiempo', () {
      expect(mensajeDeError(errorDeRed()), contains('Sin conexión'));
      expect(
        mensajeDeError(
          DioException.receiveTimeout(
            timeout: const Duration(seconds: 1),
            requestOptions: RequestOptions(path: '/x'),
          ),
        ),
        contains('tardó demasiado'),
      );
    });

    test('lo que no es un error HTTP cae en el genérico', () {
      expect(mensajeDeError(StateError('x'), generico: 'Ups'), 'Ups');
    });

    test('mensajes vacíos o raros se descartan', () {
      expect(mensajeDelServidor(errorHttp(400, '   ')), isNull);
      expect(mensajeDelServidor(errorHttp(400, <String>[])), isNull);
      expect(mensajeDelServidor(errorHttp(400, 42)), isNull);
    });

    test('esFaltaDeRed distingue la red de una respuesta mala', () {
      expect(esFaltaDeRed(errorDeRed()), isTrue);
      expect(esFaltaDeRed(errorHttp(500)), isFalse);
      expect(estadoDe(errorHttp(404)), 404);
    });
  });

  group('Errores del acceso', () {
    test('401 son credenciales equivocadas, no una sesión vencida', () {
      final error = errorDeAcceso(
        errorHttp(401, 'Correo o contraseña incorrectos'),
      );

      expect(error.mensaje, mensajeCredencialesIncorrectas);
      expect(error.bloqueada, isFalse);
    });

    test('401 en el paso del código dice que el código no vale', () {
      final error = errorDeAcceso(
        errorHttp(401, 'Código incorrecto o vencido'),
        esCodigo: true,
      );

      expect(error.mensaje, mensajeCodigoIncorrecto);
    });

    test('423 es la cuenta bloqueada, con el texto del servidor', () {
      final error = errorDeAcceso(
        errorHttp(
          423,
          'Cuenta bloqueada temporalmente por varios intentos fallidos. '
          'Intenta de nuevo en 15 minutos.',
        ),
      );

      expect(error.bloqueada, isTrue);
      expect(error.mensaje, contains('15 minutos'));
    });

    test('423 sin texto se explica igual', () {
      final error = errorDeAcceso(errorHttp(423));

      expect(error.bloqueada, isTrue);
      expect(error.mensaje, mensajeCuentaBloqueada);
    });

    test('sin red se dice que no hay conexión', () {
      expect(errorDeAcceso(errorDeRed()).mensaje, contains('Sin conexión'));
    });
  });

  group('Qué 401 vence la sesión', () {
    test('las rutas del acceso no vencen nada', () {
      expect(esRutaDeAcceso('/auth/login'), isTrue);
      expect(esRutaDeAcceso('/auth/login/2fa'), isTrue);
      expect(esRutaDeAcceso('/auth/password/olvido'), isTrue);
      expect(esRutaDeAcceso('/auth/me'), isFalse);
      expect(esRutaDeAcceso('/portal/citas'), isFalse);
    });
  });

  group('Qué dice la red', () {
    Response<dynamic> respuesta(
      int codigo, {
      String tipo = 'application/json',
      Object? cuerpo,
    }) {
      return Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        statusCode: codigo,
        data: cuerpo,
        headers: Headers.fromMap({
          'content-type': [tipo],
        }),
      );
    }

    test('el saludo de la API es conexión; un portal cautivo, no', () {
      expect(
        clasificarRespuesta(
          respuesta(
            200,
            tipo: 'text/html',
            cuerpo: 'Hello World! Bienvenido a CliniQ API Gateway',
          ),
        ),
        MotivoDeRed.conectado,
      );
      expect(
        clasificarRespuesta(
          respuesta(
            200,
            tipo: 'text/html',
            cuerpo: '<html>Acepta las condiciones</html>',
          ),
        ),
        MotivoDeRed.sinSalida,
      );
    });

    test('un 5xx es el servidor caído y un 4xx es conexión', () {
      expect(clasificarRespuesta(respuesta(503)), MotivoDeRed.servidorCaido);
      expect(clasificarRespuesta(respuesta(401)), MotivoDeRed.conectado);
    });

    test('sin llegar al servidor', () {
      expect(clasificarFallo(errorDeRed()), MotivoDeRed.sinRed);
    });
  });
}
