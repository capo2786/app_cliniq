// test/auth_bloc_test.dart

import 'dart:async';

import 'package:app_cliniq/core/storage/almacen_claves.dart';
import 'package:app_cliniq/core/storage/credenciales_service.dart';
import 'package:app_cliniq/features/auth/data/almacen_de_sesion.dart';
import 'package:app_cliniq/features/auth/data/auth_service.dart';
import 'package:app_cliniq/features/auth/data/errores_de_acceso.dart';
import 'package:app_cliniq/features/auth/data/models/usuario.dart';
import 'package:app_cliniq/features/auth/providers/auth_bloc.dart';
import 'package:app_cliniq/features/auth/providers/auth_event.dart';
import 'package:app_cliniq/features/auth/providers/auth_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dobles.dart';

/// El acceso: contraseña, segundo factor, credenciales equivocadas, cuenta
/// bloqueada, sesión guardada y sesión vencida.
void main() {
  late AuthServiceFalso servicio;
  late AlmacenClavesEnMemoria llavero;
  late CredencialesService credenciales;
  late AlmacenDeSesion almacen;
  late String? token;
  late int limpiezas;
  final ahora = DateTime(2026, 9, 28, 9);

  setUp(() {
    servicio = AuthServiceFalso();
    llavero = AlmacenClavesEnMemoria();
    credenciales = CredencialesService(llavero);
    almacen = AlmacenDeSesion(llavero);
    token = null;
    limpiezas = 0;
  });

  AuthBloc crear({bool restaurar = false, Stream<void>? vencida}) => AuthBloc(
    servicio: servicio,
    almacen: almacen,
    credenciales: credenciales,
    fijarToken: (t) => token = t,
    sesionVencida: vencida,
    limpiarDatosLocales: () async => limpiezas++,
    reloj: () => ahora,
    restaurarAlCrear: restaurar,
  );

  group('Entrar con correo y contraseña', () {
    blocTest<AuthBloc, AuthState>(
      'acceso correcto: guarda la sesión, pone el token y recuerda las '
      'credenciales para la huella',
      setUp: () {
        servicio.alEntrar = (email, password) async => AccesoConcedido(
          token: 'jwt-1',
          expiraEnSegundos: 3600,
          usuario: usuarioDePrueba(),
        );
      },
      build: crear,
      act: (bloc) => bloc.add(
        const AuthLoginSolicitado(
          email: '  Ana@Correo.com ',
          password: 'secreta1',
        ),
      ),
      expect: () => [const AuthCargando(), AuthAutenticado(usuarioDePrueba())],
      verify: (_) async {
        expect(servicio.llamadas, ['login:ana@correo.com']);
        expect(token, 'jwt-1');

        final sesion = await almacen.leer();
        expect(sesion?.token, 'jwt-1');
        expect(
          sesion?.venceEn?.isAtSameMomentAs(
            ahora.add(const Duration(hours: 1)),
          ),
          isTrue,
        );

        final guardadas = await credenciales.leer();
        expect(guardadas?.email, 'ana@correo.com');
        expect(guardadas?.password, 'secreta1');
      },
    );

    blocTest<AuthBloc, AuthState>(
      '401: credenciales incorrectas, sin tocar nada guardado',
      setUp: () {
        servicio.alEntrar = (_, _) async =>
            throw errorHttp(401, 'Correo o contraseña incorrectos');
      },
      build: crear,
      act: (bloc) => bloc.add(
        const AuthLoginSolicitado(email: 'ana@correo.com', password: 'mala'),
      ),
      expect: () => [
        const AuthCargando(),
        const AuthError(mensajeCredencialesIncorrectas),
      ],
      verify: (_) async {
        expect(token, isNull);
        expect(
          await credenciales.leer(),
          isNull,
          reason: 'una contraseña rechazada nunca se guarda',
        );
        expect(await almacen.leer(), isNull);
      },
    );

    blocTest<AuthBloc, AuthState>(
      '423: cuenta bloqueada, con el mensaje del servidor',
      setUp: () {
        servicio.alEntrar = (_, _) async => throw errorHttp(
          423,
          'Cuenta bloqueada temporalmente por varios intentos fallidos. '
          'Intenta de nuevo en 15 minutos.',
        );
      },
      build: crear,
      act: (bloc) => bloc.add(
        const AuthLoginSolicitado(email: 'ana@correo.com', password: 'mala'),
      ),
      expect: () => [
        const AuthCargando(),
        isA<AuthError>()
            .having((e) => e.bloqueada, 'bloqueada', isTrue)
            .having((e) => e.mensaje, 'mensaje', contains('15 minutos')),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'sin red: lo dice, no culpa a la contraseña',
      setUp: () {
        servicio.alEntrar = (_, _) async => throw errorDeRed();
      },
      build: crear,
      act: (bloc) => bloc.add(
        const AuthLoginSolicitado(email: 'ana@correo.com', password: 'x'),
      ),
      expect: () => [
        const AuthCargando(),
        isA<AuthError>()
            .having((e) => e.bloqueada, 'bloqueada', isFalse)
            .having((e) => e.mensaje, 'mensaje', contains('Sin conexión')),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'con la huella apagada en el perfil no se guarda la contraseña',
      setUp: () async {
        await credenciales.fijarBiometriaActiva(false);
        servicio.alEntrar = (_, _) async =>
            AccesoConcedido(token: 'jwt', usuario: usuarioDePrueba());
      },
      build: crear,
      act: (bloc) => bloc.add(
        const AuthLoginSolicitado(
          email: 'ana@correo.com',
          password: 'secreta1',
        ),
      ),
      verify: (_) async => expect(await credenciales.leer(), isNull),
    );
  });

  group('Verificación en dos pasos', () {
    blocTest<AuthBloc, AuthState>(
      'pide el código, lo verifica y recién entonces entra y guarda',
      setUp: () {
        servicio.alEntrar = (_, _) async => const SegundoFactorRequerido(
          desafio: 'des-1',
          destino: 'a***@correo.com',
        );
        servicio.alVerificar = (desafio, codigo) async => AccesoConcedido(
          token: 'jwt-2fa',
          usuario: usuarioDePrueba(dosFactores: true),
        );
      },
      build: crear,
      act: (bloc) async {
        bloc.add(
          const AuthLoginSolicitado(
            email: 'ana@correo.com',
            password: 'secreta1',
          ),
        );
        await bloc.stream.firstWhere((s) => s is AuthRequiere2fa);

        expect(
          await credenciales.leer(),
          isNull,
          reason: 'sin el código, el acceso no está concedido',
        );

        bloc.add(const AuthCodigoEnviado(' 123456 '));
      },
      expect: () => [
        const AuthCargando(),
        const AuthRequiere2fa(desafio: 'des-1', destino: 'a***@correo.com'),
        const AuthRequiere2fa(
          desafio: 'des-1',
          destino: 'a***@correo.com',
          enviando: true,
        ),
        AuthAutenticado(usuarioDePrueba(dosFactores: true)),
      ],
      verify: (_) async {
        expect(servicio.llamadas.last, '2fa:des-1: 123456 ');
        expect(token, 'jwt-2fa');
        expect((await credenciales.leer())?.password, 'secreta1');
      },
    );

    blocTest<AuthBloc, AuthState>(
      'un código equivocado se dice dentro del mismo paso',
      setUp: () {
        servicio.alEntrar = (_, _) async => const SegundoFactorRequerido(
          desafio: 'des-1',
          destino: 'a***@c.com',
        );
        servicio.alVerificar = (_, _) async =>
            throw errorHttp(401, 'Código incorrecto o vencido');
      },
      build: crear,
      act: (bloc) async {
        bloc.add(
          const AuthLoginSolicitado(email: 'ana@correo.com', password: 'x'),
        );
        await bloc.stream.firstWhere((s) => s is AuthRequiere2fa);
        bloc.add(const AuthCodigoEnviado('000000'));
      },
      skip: 2,
      expect: () => [
        const AuthRequiere2fa(
          desafio: 'des-1',
          destino: 'a***@c.com',
          enviando: true,
        ),
        const AuthRequiere2fa(
          desafio: 'des-1',
          destino: 'a***@c.com',
          error: mensajeCodigoIncorrecto,
        ),
      ],
      verify: (_) => expect(token, isNull),
    );

    blocTest<AuthBloc, AuthState>(
      'volver del código deja el formulario limpio',
      setUp: () {
        servicio.alEntrar = (_, _) async =>
            const SegundoFactorRequerido(desafio: 'd', destino: 'x');
      },
      build: crear,
      act: (bloc) async {
        bloc.add(
          const AuthLoginSolicitado(email: 'ana@correo.com', password: 'x'),
        );
        await bloc.stream.firstWhere((s) => s is AuthRequiere2fa);
        bloc.add(const AuthCodigoCancelado());
      },
      skip: 2,
      expect: () => [const AuthNoAutenticado()],
    );
  });

  group('Sesión guardada', () {
    blocTest<AuthBloc, AuthState>(
      'sin sesión guardada, al acceso',
      build: () => crear(restaurar: true),
      expect: () => [const AuthNoAutenticado()],
    );

    blocTest<AuthBloc, AuthState>(
      'con sesión vigente se confirma con el servidor y se entra',
      setUp: () async {
        await almacen.guardar(
          SesionGuardada(
            token: 'jwt-guardado',
            venceEn: ahora.add(const Duration(hours: 3)),
            usuario: usuarioDePrueba(),
          ),
        );
        servicio.alPedirPerfil = () async =>
            usuarioDePrueba(legalPendientes: ['PRIVACIDAD']);
      },
      build: () => crear(restaurar: true),
      expect: () => [
        AuthAutenticado(
          usuarioDePrueba(legalPendientes: ['PRIVACIDAD']),
          restaurada: true,
        ),
      ],
      verify: (_) => expect(token, 'jwt-guardado'),
    );

    blocTest<AuthBloc, AuthState>(
      'sin red se entra igual con el perfil guardado',
      setUp: () async {
        await almacen.guardar(
          SesionGuardada(token: 'jwt', usuario: usuarioDePrueba()),
        );
        servicio.alPedirPerfil = () async => throw errorDeRed();
      },
      build: () => crear(restaurar: true),
      expect: () => [
        AuthAutenticado(usuarioDePrueba(), restaurada: true, sinConexion: true),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'vencida según su fecha: al acceso con el aviso, sin preguntar',
      setUp: () async {
        await almacen.guardar(
          SesionGuardada(
            token: 'jwt',
            venceEn: ahora.subtract(const Duration(minutes: 1)),
            usuario: usuarioDePrueba(),
          ),
        );
      },
      build: () => crear(restaurar: true),
      expect: () => [const AuthNoAutenticado(aviso: avisoSesionVencida)],
      verify: (_) async {
        expect(servicio.llamadas, isEmpty);
        expect(await almacen.leer(), isNull);
        expect(limpiezas, 1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'el servidor responde 401 al restaurar: sesión vencida',
      setUp: () async {
        await almacen.guardar(
          SesionGuardada(token: 'jwt', usuario: usuarioDePrueba()),
        );
        servicio.alPedirPerfil = () async => throw errorHttp(401);
      },
      build: () => crear(restaurar: true),
      expect: () => [const AuthNoAutenticado(aviso: avisoSesionVencida)],
      verify: (_) => expect(token, isNull),
    );
  });

  group('Vencer y salir', () {
    late StreamController<void> vencimientos;

    setUp(() => vencimientos = StreamController<void>.broadcast());
    tearDown(() => vencimientos.close());

    blocTest<AuthBloc, AuthState>(
      'un 401 con la sesión abierta lleva al acceso con el aviso',
      setUp: () {
        servicio.alEntrar = (_, _) async =>
            AccesoConcedido(token: 'jwt', usuario: usuarioDePrueba());
      },
      build: () => crear(vencida: vencimientos.stream),
      act: (bloc) async {
        bloc.add(
          const AuthLoginSolicitado(email: 'ana@correo.com', password: 'x'),
        );
        await bloc.stream.firstWhere((s) => s is AuthAutenticado);
        vencimientos.add(null);
      },
      skip: 2,
      expect: () => [const AuthNoAutenticado(aviso: avisoSesionVencida)],
      verify: (_) async {
        expect(token, isNull);
        expect(limpiezas, 1);
        expect(
          await credenciales.leer(),
          isNotNull,
          reason: 'la huella sigue lista para volver a entrar',
        );
      },
    );

    blocTest<AuthBloc, AuthState>(
      'un 401 durante el acceso no es una sesión vencida',
      build: () => crear(vencida: vencimientos.stream),
      act: (bloc) => vencimientos.add(null),
      expect: () => <AuthState>[],
    );

    blocTest<AuthBloc, AuthState>(
      'cerrar sesión borra la sesión y lo de la persona, no la huella',
      setUp: () {
        servicio.alEntrar = (_, _) async =>
            AccesoConcedido(token: 'jwt', usuario: usuarioDePrueba());
      },
      build: crear,
      act: (bloc) async {
        bloc.add(
          const AuthLoginSolicitado(email: 'ana@correo.com', password: 'x'),
        );
        await bloc.stream.firstWhere((s) => s is AuthAutenticado);
        bloc.add(const AuthCierreSolicitado());
      },
      skip: 2,
      expect: () => [const AuthNoAutenticado()],
      verify: (_) async {
        expect(token, isNull);
        expect(await almacen.leer(), isNull);
        expect(limpiezas, 1);
        expect(await credenciales.leer(), isNotNull);
      },
    );
  });

  group('Solo pacientes', () {
    Usuario delPersonal() => Usuario({
      'uid': 'm1',
      'nombre': 'Luis Mora',
      'email': 'luis@clinica.com',
      'role': 2,
      'permisos': ['agenda.atender', 'consultas.atender'],
      'legalPendientes': <String>[],
    });

    blocTest<AuthBloc, AuthState>(
      'una cuenta del personal no entra: ni sesión, ni token, ni '
      'credenciales guardadas',
      setUp: () {
        servicio.alEntrar = (_, _) async =>
            AccesoConcedido(token: 'jwt-medico', usuario: delPersonal());
      },
      build: crear,
      act: (bloc) => bloc.add(
        const AuthLoginSolicitado(
          email: 'luis@clinica.com',
          password: 'secreta1',
        ),
      ),
      expect: () => [const AuthCargando(), const AuthCuentaDelPersonal()],
      verify: (_) async {
        expect(token, isNull);
        expect(await almacen.leer(), isNull);
        expect(await credenciales.leer(), isNull);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'el administrador tampoco: su comodín no abre el portal del paciente',
      setUp: () {
        servicio.alEntrar = (_, _) async => AccesoConcedido(
          token: 'jwt-admin',
          usuario: Usuario({
            'uid': 'a1',
            'permisos': ['*'],
          }),
        );
      },
      build: crear,
      act: (bloc) => bloc.add(
        const AuthLoginSolicitado(email: 'admin@clinica.com', password: 'x'),
      ),
      expect: () => [const AuthCargando(), const AuthCuentaDelPersonal()],
      verify: (_) => expect(token, isNull),
    );

    blocTest<AuthBloc, AuthState>(
      'una sesión guardada del personal se cierra al restaurar',
      setUp: () async {
        await almacen.guardar(
          SesionGuardada(token: 'jwt', usuario: delPersonal()),
        );
        servicio.alPedirPerfil = () async => delPersonal();
      },
      build: () => crear(restaurar: true),
      expect: () => [const AuthCuentaDelPersonal()],
      verify: (_) async {
        expect(servicio.llamadas, ['me']);
        expect(await almacen.leer(), isNull);
        expect(token, isNull);
        expect(limpiezas, 1);
      },
    );

    blocTest<AuthBloc, AuthState>(
      'sin red, la sesión guardada del personal tampoco abre',
      setUp: () async {
        await almacen.guardar(
          SesionGuardada(token: 'jwt', usuario: delPersonal()),
        );
        servicio.alPedirPerfil = () async => throw errorDeRed();
      },
      build: () => crear(restaurar: true),
      expect: () => [const AuthCuentaDelPersonal()],
      verify: (_) async => expect(await almacen.leer(), isNull),
    );
  });

  group('Correo sin confirmar', () {
    blocTest<AuthBloc, AuthState>(
      '403 CORREO_NO_VERIFICADO: el error lo dice y guarda el correo para '
      'reenviar el enlace',
      setUp: () {
        servicio.alEntrar = (_, _) async => throw errorHttp(
          403,
          'Confirma tu correo para ingresar.',
          'CORREO_NO_VERIFICADO',
        );
      },
      build: crear,
      act: (bloc) => bloc.add(
        const AuthLoginSolicitado(email: ' Ana@Correo.com ', password: 'x'),
      ),
      expect: () => [
        const AuthCargando(),
        const AuthError(
          'Confirma tu correo para ingresar.',
          correoSinVerificar: true,
          correo: 'ana@correo.com',
        ),
      ],
      verify: (_) async {
        expect(token, isNull);
        expect(await credenciales.leer(), isNull);
      },
    );
  });
}
