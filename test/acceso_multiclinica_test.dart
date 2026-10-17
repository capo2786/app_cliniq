// test/acceso_multiclinica_test.dart

import 'package:app_cliniq/core/network/interceptor_de_empresa.dart';
import 'package:app_cliniq/core/storage/almacen_claves.dart';
import 'package:app_cliniq/core/storage/credenciales_service.dart';
import 'package:app_cliniq/features/auth/data/almacen_de_sesion.dart';
import 'package:app_cliniq/features/auth/data/auth_service.dart';
import 'package:app_cliniq/features/auth/data/models/datos_registro.dart';
import 'package:app_cliniq/features/auth/providers/auth_bloc.dart';
import 'package:app_cliniq/features/auth/providers/auth_event.dart';
import 'package:app_cliniq/features/auth/providers/auth_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinicas.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';

/// Entrar cuando el correo tiene cuenta en varias clínicas, y la clínica en
/// lo que se manda al acceso y al registro.
void main() {
  late AuthServiceFalso servicio;
  late AlmacenClavesEnMemoria llavero;

  setUp(() {
    servicio = AuthServiceFalso();
    llavero = AlmacenClavesEnMemoria();
  });

  AuthBloc crear() => AuthBloc(
    servicio: servicio,
    almacen: AlmacenDeSesion(llavero),
    credenciales: CredencialesService(llavero),
    fijarToken: (_) {},
    reloj: () => DateTime(2026, 10, 17, 9),
    restaurarAlCrear: false,
  );

  AccesoConcedido concedido() =>
      AccesoConcedido(token: 'jwt', usuario: usuarioDePrueba());

  group('El correo está en varias clínicas', () {
    blocTest<AuthBloc, AuthState>(
      'el 409 pide elegir; con la elegida se vuelve a intentar con su código',
      setUp: () {
        servicio.alEntrar = (email, password) async {
          if (servicio.empresas.last == null) {
            throw errorEmpresaAmbigua([clinicaAndina, clinicaDelSur]);
          }
          return concedido();
        };
      },
      build: crear,
      act: (bloc) async {
        bloc.add(const AuthLoginSolicitado(email: 'ana@c.ec', password: 'x1'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AuthClinicaElegida(clinicaDelSur));
      },
      expect: () => [
        const AuthCargando(),
        isA<AuthEligeClinica>().having(
          (s) => s.clinicas.map((c) => c.codigo),
          'clínicas',
          ['andina', 'sur'],
        ),
        const AuthCargando(),
        AuthAutenticado(usuarioDePrueba()),
      ],
      verify: (_) {
        expect(servicio.llamadas, ['login:ana@c.ec', 'login:ana@c.ec']);
        expect(servicio.empresas, [null, 'sur']);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'con la clínica elegida, el código de dos pasos va con ella',
      setUp: () {
        servicio.alEntrar = (email, password) async {
          if (servicio.empresas.last == null) {
            throw errorEmpresaAmbigua([clinicaAndina, clinicaDelSur]);
          }
          return const SegundoFactorRequerido(desafio: 'd1', destino: 'a***');
        };
        servicio.alVerificar = (desafio, codigo) async => concedido();
      },
      build: crear,
      act: (bloc) async {
        bloc.add(const AuthLoginSolicitado(email: 'ana@c.ec', password: 'x1'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AuthClinicaElegida(clinicaAndina));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AuthCodigoEnviado('123456'));
      },
      skip: 5,
      expect: () => [AuthAutenticado(usuarioDePrueba())],
      verify: (_) => expect(servicio.empresas, [null, 'andina', 'andina']),
    );

    blocTest<AuthBloc, AuthState>(
      'cerrar la hoja sin elegir vuelve al formulario',
      setUp: () =>
          servicio.alEntrar = (_, _) async =>
              throw errorEmpresaAmbigua([clinicaAndina, clinicaDelSur]),
      build: crear,
      act: (bloc) async {
        bloc.add(const AuthLoginSolicitado(email: 'ana@c.ec', password: 'x1'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AuthEleccionDeClinicaCancelada());
        // Ya sin la contraseña en espera, elegir no hace nada.
        bloc.add(const AuthClinicaElegida(clinicaAndina));
      },
      expect: () => [
        const AuthCargando(),
        isA<AuthEligeClinica>(),
        const AuthNoAutenticado(),
      ],
      verify: (_) => expect(servicio.llamadas, hasLength(1)),
    );

    blocTest<AuthBloc, AuthState>(
      'si con la clínica elegida vuelve el 409, es un error y no otra hoja',
      setUp: () =>
          servicio.alEntrar = (_, _) async =>
              throw errorEmpresaAmbigua([clinicaAndina, clinicaDelSur]),
      build: crear,
      act: (bloc) async {
        bloc.add(const AuthLoginSolicitado(email: 'ana@c.ec', password: 'x1'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const AuthClinicaElegida(clinicaAndina));
      },
      skip: 3,
      expect: () => [const AuthError('Tu correo está en varias clínicas.')],
    );
  });

  group('Lo que se manda', () {
    test('el acceso con la clínica elegida la lleva en el cuerpo y en '
        'X-Empresa; sin elegir, en ninguno', () async {
      final api = DioGrabador({
        'POST /auth/login': (_) => {
          'access_token': 'jwt',
          'user': {'uid': 'u1'},
        },
        'POST /auth/login/2fa': (_) => {
          'access_token': 'jwt',
          'user': {'uid': 'u1'},
        },
      });
      final auth = AuthService(api.dio);

      await auth.iniciarSesion(email: 'A@c.ec', password: 'x', empresa: 'sur');
      await auth.iniciarSesion(email: 'a@c.ec', password: 'x');
      await auth.verificarCodigo(desafio: 'd', codigo: '1', empresa: 'sur');

      final [elegida, sinElegir, codigo] = api.pedidos;
      expect(elegida.data, {
        'email': 'a@c.ec',
        'password': 'x',
        'empresa': 'sur',
      });
      expect(elegida.headers[cabeceraEmpresa], 'sur');
      expect((sinElegir.data as Map).containsKey('empresa'), isFalse);
      expect(sinElegir.headers.containsKey(cabeceraEmpresa), isFalse);
      expect((codigo.data as Map)['empresa'], 'sur');
      expect(codigo.headers[cabeceraEmpresa], 'sur');
    });

    test('el registro lleva la clínica en X-Empresa y nunca como «empresa» '
        'del cuerpo, que es el empleador del paciente', () async {
      final api = DioGrabador({'POST /auth/registro': (_) => {}});
      const datos = DatosRegistro(
        nombre: 'Ana Pérez',
        email: 'ana@c.ec',
        tipoDocumento: 'CEDULA',
        cedula: '1710034065',
        fechaNacimiento: '1990-01-01',
        password: 'secreta1',
        empresa: 'sur',
      );

      await AuthService(api.dio).registrar(datos);
      await AuthService(api.dio).registrar(
        DatosRegistro(
          nombre: datos.nombre,
          email: datos.email,
          tipoDocumento: datos.tipoDocumento,
          cedula: datos.cedula,
          fechaNacimiento: datos.fechaNacimiento,
          password: datos.password,
        ),
      );

      final [conClinica, sinClinica] = api.pedidos;
      expect((conClinica.data as Map).containsKey('empresa'), isFalse);
      expect(conClinica.headers[cabeceraEmpresa], 'sur');
      expect(sinClinica.headers.containsKey(cabeceraEmpresa), isFalse);
    });
  });
}
