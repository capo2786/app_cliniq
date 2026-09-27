// test/acceso_pacientes_test.dart

import 'package:app_cliniq/features/auth/data/auth_service.dart';
import 'package:app_cliniq/features/auth/data/errores_de_acceso.dart';
import 'package:app_cliniq/features/auth/data/models/usuario.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';

/// El acceso es solo para pacientes, y una cuenta del autorregistro tiene
/// que confirmar su correo antes de entrar.
void main() {
  group('Quién es paciente', () {
    Usuario con(List<String> permisos) => Usuario({'permisos': permisos});

    test('con «mis citas» es paciente', () {
      expect(con([Permisos.misCitas, Permisos.consultas]).esPaciente, isTrue);
    });

    test('el comodín del administrador no abre el portal del paciente', () {
      final administrador = con([Permisos.comodin]);

      expect(administrador.esPaciente, isFalse);
      // `puede` sigue abriendo todo lo demás, como siempre.
      expect(administrador.puede(Permisos.agendar), isTrue);
    });

    test('un médico o la recepción no son pacientes', () {
      expect(con(['agenda.atender', 'hce.ver']).esPaciente, isFalse);
      expect(con(const []).esPaciente, isFalse);
    });
  });

  group('Correo sin confirmar', () {
    test('403 con codigo CORREO_NO_VERIFICADO: se reconoce, con el texto '
        'del servidor', () {
      final error = errorDeAcceso(
        errorHttp(
          403,
          'Confirma tu correo para ingresar. Revisa tu bandeja o pide un '
          'nuevo enlace.',
          codigoCorreoNoVerificado,
        ),
      );

      expect(error.correoSinVerificar, isTrue);
      expect(error.bloqueada, isFalse);
      expect(error.mensaje, startsWith('Confirma tu correo'));
    });

    test('sin mensaje, se explica igual', () {
      final error = errorDeAcceso(
        errorHttp(403, null, codigoCorreoNoVerificado),
      );

      expect(error.correoSinVerificar, isTrue);
      expect(error.mensaje, mensajeCorreoNoVerificado);
    });

    test('un 403 cualquiera no es un correo sin confirmar', () {
      final error = errorDeAcceso(errorHttp(403, 'Cuenta desactivada'));

      expect(error.correoSinVerificar, isFalse);
      expect(error.mensaje, 'Cuenta desactivada');
    });

    test(
      'reenviar: POST /auth/registro/reenviar con el correo limpio',
      () async {
        final api = DioGrabador({
          'POST /auth/registro/reenviar': (_) => {
            'message':
                'Si el correo tiene una cuenta pendiente, te enviamos '
                'un enlace.',
          },
        });

        final mensaje = await AuthService(api.dio)
            .reenviarConfirmacion('  Ana@Correo.com ');

        expect(api.claves, ['POST /auth/registro/reenviar']);
        expect(api.pedidos.single.data, {'email': 'ana@correo.com'});
        expect(mensaje, startsWith('Si el correo tiene una cuenta pendiente'));
      },
    );

    test('reenviar sin mensaje del servidor: el neutral de siempre', () async {
      final api = DioGrabador({'POST /auth/registro/reenviar': (_) => {}});

      expect(
        await AuthService(api.dio).reenviarConfirmacion('ana@correo.com'),
        mensajeReenvioNeutral,
      );
    });
  });
}
