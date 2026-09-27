// test/registro_test.dart

import 'dart:async';

import 'package:app_cliniq/core/network/api_interceptor.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/auth/data/auth_service.dart';
import 'package:app_cliniq/features/auth/dominio/registro.dart';
import 'package:app_cliniq/features/auth/providers/registro_bloc.dart';
import 'package:app_cliniq/features/dependientes/dominio/validaciones.dart';
import 'package:app_cliniq/features/legal/data/legal_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/registro.dart';

void main() {
  final hoy = DateTime(2026, 9, 28);

  group('Las reglas del formulario (las del panel, con sus mensajes)', () {
    test('nombres y apellidos: obligatorio, de 3 a 120 caracteres', () {
      expect(errorDeNombreRegistro(''), 'Escribe tus nombres y apellidos.');
      expect(errorDeNombreRegistro('   '), 'Escribe tus nombres y apellidos.');
      expect(errorDeNombreRegistro(' a '), 'Debe tener al menos 3 caracteres.');
      expect(errorDeNombreRegistro('a' * 121), 'Máximo 120 caracteres.');
      expect(errorDeNombreRegistro('Ana María Torres'), isNull);
    });

    test('correo: obligatorio, con forma de correo y un dominio con punto', () {
      expect(errorDeCorreoRegistro(''), 'Escribe tu correo.');
      expect(errorDeCorreoRegistro('ana'), 'Ese correo no parece válido.');
      expect(errorDeCorreoRegistro('ana@'), 'Ese correo no parece válido.');
      expect(
        errorDeCorreoRegistro('ana@clinica'),
        'Ese correo no parece válido.',
        reason: 'el API (isEmail) exige el punto que Angular deja pasar',
      );
      expect(errorDeCorreoRegistro('ana @correo.com'), isNotNull);
      expect(
        errorDeCorreoRegistro('${'a' * 110}@correo.com'),
        'Máximo 120 caracteres.',
      );
      expect(errorDeCorreoRegistro(' ana.torres+citas@correo.com.ec '), isNull);
    });

    test('teléfono: opcional, de 7 a 15 dígitos', () {
      expect(errorDeTelefono(''), isNull);
      expect(errorDeTelefono('099'), 'Escribe un teléfono de 7 a 15 dígitos.');
      expect(errorDeTelefono('+593 99 123 4567'), isNull);
    });

    test('documento: obligatorio; la cédula con el módulo 10 si la clínica '
        'lo pide (general.validarCedula)', () {
      expect(
        errorDeDocumentoRegistro('', 'CEDULA', validarCedula: true),
        'Escribe el número de tu documento.',
      );
      expect(
        errorDeDocumentoRegistro('1710034065', 'CEDULA', validarCedula: true),
        isNull,
      );
      expect(
        errorDeDocumentoRegistro('1710034066', 'CEDULA', validarCedula: true),
        'La cédula no es válida. Revisa los diez dígitos.',
      );
      expect(
        errorDeDocumentoRegistro('1710034066', 'CEDULA', validarCedula: false),
        isNull,
        reason: 'sin la validación, bastan diez dígitos',
      );
      expect(
        errorDeDocumentoRegistro('171003', 'CEDULA', validarCedula: false),
        'La cédula no es válida. Revisa los diez dígitos.',
      );
      expect(
        errorDeDocumentoRegistro('A12', 'PASAPORTE', validarCedula: true),
        'El pasaporte debe tener entre 5 y 20 letras o números.',
      );
      expect(
        errorDeDocumentoRegistro('AB12345', 'PASAPORTE', validarCedula: true),
        isNull,
      );
    });

    test('fecha de nacimiento: obligatoria y no futura', () {
      expect(errorDeFechaRegistro(null, hoy), 'Indica tu fecha de nacimiento.');
      expect(
        errorDeFechaRegistro('2026-09-29', hoy),
        'La fecha no puede estar en el futuro.',
      );
      expect(errorDeFechaRegistro('2026-09-28', hoy), isNull);
      expect(errorDeFechaRegistro('1990-05-17', hoy), isNull);
    });

    test('contraseña: el mínimo de la clínica y el máximo del API', () {
      expect(errorDeContrasenaRegistro('', minimo: 8), 'Crea una contraseña.');
      expect(
        errorDeContrasenaRegistro('corta', minimo: 8),
        'Debe tener al menos 8 caracteres.',
      );
      expect(
        errorDeContrasenaRegistro('corta12', minimo: 12),
        'Debe tener al menos 12 caracteres.',
      );
      expect(errorDeContrasenaRegistro('suficiente', minimo: 8), isNull);
      expect(
        errorDeContrasenaRegistro('x' * 129, minimo: 8),
        'La contraseña no puede superar 128 caracteres.',
      );
    });

    test('confirmación: obligatoria e igual', () {
      expect(errorDeConfirmacion('', 'Clave-1'), 'Repite la contraseña.');
      expect(
        errorDeConfirmacion('Clave-2', 'Clave-1'),
        'Las contraseñas no coinciden.',
      );
      expect(errorDeConfirmacion('Clave-1', 'Clave-1'), isNull);
    });
  });

  group('La fortaleza de la contraseña (la barra del panel)', () {
    test('el puntaje suma el mínimo, cuatro más, mayúsculas, números y '
        'símbolos, hasta 4', () {
      expect(puntajeDeContrasena('', 8), 0);
      expect(puntajeDeContrasena('abc', 8), 0);
      expect(puntajeDeContrasena('abcdefgh', 8), 1);
      expect(puntajeDeContrasena('abcdefghijkl', 8), 2);
      expect(puntajeDeContrasena('Abcdefghijkl', 8), 3);
      expect(puntajeDeContrasena('Abcdefghijk1!', 8), 4);
      expect(puntajeDeContrasena('Abcdefgh1', 12), 2);
    });

    test('las pistas dicen qué falta, con el mínimo de la clínica', () {
      expect(pistaDeContrasena(0, 8), 'Muy débil');
      expect(pistaDeContrasena(1, 10), 'Débil: usa al menos 10 caracteres');
      expect(
        pistaDeContrasena(2, 8),
        'Aceptable: combina mayúsculas, números o símbolos',
      );
      expect(pistaDeContrasena(3, 8), 'Buena');
      expect(pistaDeContrasena(4, 8), 'Muy buena');
    });
  });

  group('Los documentos legales del registro', () {
    test('los que acepta el registro (términos y privacidad, en ese orden) y '
        'los demás de los pacientes; nada de los médicos', () {
      final reparto = repartirDocumentosDelPaciente(
        interpretarDocumentos(documentosVigentesJson()),
      );

      expect(
        [for (final d in reparto.alRegistrarse) d.clave],
        ['TERMINOS', 'PRIVACIDAD'],
      );
      expect(
        [for (final d in reparto.alEntrar) d.clave],
        ['AVISO_LEGAL', 'CONSENTIMIENTO_TELEMEDICINA'],
      );
    });

    test('un documento que no es de pacientes no se pide', () {
      final reparto = repartirDocumentosDelPaciente(
        interpretarDocumentos([
          {
            'clave': 'TERMINOS',
            'slug': 'terminos',
            'version': '2.0',
            'titulo': 'Términos',
            'tipos': [2],
          },
        ]),
      );

      expect(reparto.alRegistrarse, isEmpty);
      expect(reparto.alEntrar, isEmpty);
    });
  });

  group('Lo que se envía', () {
    test('POST /auth/registro, pública, arreglado como el panel y con '
        'aceptaTerminos', () async {
      final api = DioGrabador({
        'POST /auth/registro': (_) => {'message': 'ok'},
      });

      await AuthService(api.dio)
          .registrar(datosDePrueba(telefono: ' 0991234567 ', sexo: 'F'));

      final pedido = api.ultimo('POST /auth/registro');
      expect(pedido.extra[rutaPublica], isTrue);
      expect(pedido.data, {
        'nombre': 'Ana María Torres',
        'email': 'ana.torres@correo.com',
        'telefono': '0991234567',
        'tipoDocumento': 'PASAPORTE',
        'cedula': 'AB12345',
        'fechaNacimiento': '1990-05-17',
        'sexo': 'F',
        'password': 'Clave-segura-1',
        'aceptaTerminos': true,
      });
    });

    test('sin teléfono ni sexo, esos campos no van', () {
      final cuerpo = datosDePrueba().aJson();

      expect(cuerpo.containsKey('telefono'), isFalse);
      expect(cuerpo.containsKey('sexo'), isFalse);
    });
  });

  group('El bloc del registro', () {
    late AuthServiceFalso servicio;
    late DioGrabador api;
    late StreamController<void> reloj;
    late int segundos;

    setUp(() {
      servicio = AuthServiceFalso();
      api = DioGrabador({
        'GET /legal/documentos': (_) => documentosVigentesJson(),
      });
      reloj = StreamController<void>.broadcast();
      segundos = 60;
    });

    tearDown(() => reloj.close());

    RegistroBloc crear() => RegistroBloc(
      servicio: servicio,
      legal: LegalService(api.dio, CacheEnMemoria()),
      segundosEntreEnlaces: () => segundos,
      reloj: () => reloj.stream,
    );

    Future<RegistroBloc> listo() async {
      final bloc = crear()..add(const RegistroDocumentosPedidos());
      await bloc.stream.firstWhere((s) => !s.cargandoDocumentos);
      return bloc;
    }

    Future<void> aceptarTodo(RegistroBloc bloc) async {
      for (final clave in clavesAceptadasAlRegistrarse) {
        bloc.add(RegistroDocumentoMarcado(clave, aceptado: true));
      }
      await bloc.stream.firstWhere((s) => s.todoAceptado);
    }

    test('trae los documentos de la clínica y pide aceptar los dos del '
        'registro', () async {
      final bloc = await listo();
      addTearDown(bloc.close);

      expect(bloc.state.casillas, ['TERMINOS', 'PRIVACIDAD']);
      expect(
        bloc.state.documentos.first.titulo,
        'Términos y condiciones de uso',
      );
      expect(bloc.state.documentosAlEntrar, hasLength(2));
      expect(bloc.state.todoAceptado, isFalse);

      bloc.add(const RegistroDocumentoMarcado('TERMINOS', aceptado: true));
      await bloc.stream.first;
      expect(bloc.state.todoAceptado, isFalse);

      bloc.add(const RegistroDocumentoMarcado('PRIVACIDAD', aceptado: true));
      await bloc.stream.first;
      expect(bloc.state.todoAceptado, isTrue);

      bloc.add(const RegistroDocumentoMarcado('TERMINOS', aceptado: false));
      await bloc.stream.first;
      expect(bloc.state.todoAceptado, isFalse);
    });

    test('sin documentos ni copia: lo dice, y no se puede enviar', () async {
      api.rutas['GET /legal/documentos'] = (_) => throw errorDeRed();
      final bloc = await listo();
      addTearDown(bloc.close);

      expect(
        bloc.state,
        const RegistroState(
          cargandoDocumentos: false,
          errorDocumentos: 'Sin conexión con el servidor. Revisa tu Internet.',
        ),
      );
      expect(bloc.state.casillas, isEmpty);

      bloc.add(RegistroEnviado(datosDePrueba()));
      await pumpEventQueue();
      expect(servicio.registros, isEmpty);

      // «Reintentar», ya con red.
      api.rutas['GET /legal/documentos'] = (_) => documentosVigentesJson();
      bloc.add(const RegistroDocumentosPedidos());
      await bloc.stream.firstWhere(
        (s) => !s.cargandoDocumentos && s.errorDocumentos == null,
      );
      expect(bloc.state.casillas, ['TERMINOS', 'PRIVACIDAD']);
    });

    test('la clínica sin términos ni privacidad vigentes: una sola casilla, '
        'como el panel', () async {
      api.rutas['GET /legal/documentos'] = (_) => <Object>[];
      final bloc = await listo();
      addTearDown(bloc.close);

      expect(bloc.state.casillas, [casillaSinDocumentos]);

      bloc.add(
        const RegistroDocumentoMarcado(casillaSinDocumentos, aceptado: true),
      );
      await bloc.stream.first;
      expect(bloc.state.todoAceptado, isTrue);
    });

    test('sin aceptar los documentos, no se envía', () async {
      final bloc = await listo();
      addTearDown(bloc.close);

      bloc.add(RegistroEnviado(datosDePrueba()));
      await pumpEventQueue();

      expect(servicio.registros, isEmpty);
      expect(bloc.state.enviando, isFalse);
    });

    test('creada la cuenta: «Revisa tu correo» con el correo y la espera de '
        'la clínica, que cuenta de a un segundo', () async {
      segundos = 3;
      final bloc = await listo();
      addTearDown(bloc.close);
      await aceptarTodo(bloc);

      bloc.add(RegistroEnviado(datosDePrueba()));
      await bloc.stream.firstWhere((s) => s.registrado && s.espera == 3);

      expect(servicio.registros, [datosDePrueba()]);
      expect(bloc.state.correoRegistrado, 'ana.torres@correo.com');
      expect(bloc.state.puedeReenviar, isFalse);

      for (final quedan in [2, 1, 0]) {
        reloj.add(null);
        await bloc.stream.firstWhere((s) => s.espera == quedan);
      }

      expect(bloc.state.puedeReenviar, isTrue);
      expect(reloj.hasListener, isFalse, reason: 'la cuenta termina sola');
    });

    test(
      'reenviar: el mismo correo, el aviso del panel y otra espera',
      () async {
        segundos = 1;
        final bloc = await listo();
        addTearDown(bloc.close);
        await aceptarTodo(bloc);
        bloc.add(RegistroEnviado(datosDePrueba()));
        await bloc.stream.firstWhere((s) => s.registrado && s.espera == 1);

        // Mientras se espera, reenviar no hace nada.
        bloc.add(const RegistroReenvioPedido());
        await pumpEventQueue();
        expect(
          servicio.llamadas.where((l) => l.startsWith('reenviar')),
          isEmpty,
        );

        reloj.add(null);
        await bloc.stream.firstWhere((s) => s.puedeReenviar);

        segundos = 5;
        bloc.add(const RegistroReenvioPedido());
        await bloc.stream.firstWhere((s) => s.avisoReenvio != null);

        expect(servicio.llamadas.last, 'reenviar:ana.torres@correo.com');
        expect(bloc.state.avisoReenvio, avisoEnlaceReenviado);
        expect(bloc.state.espera, 5);
      },
    );

    test('si reenviar falla, se dice y se puede volver a intentar', () async {
      segundos = 0;
      servicio.errorAlReenviar = errorDeRed();
      final bloc = await listo();
      addTearDown(bloc.close);
      await aceptarTodo(bloc);
      bloc.add(RegistroEnviado(datosDePrueba()));
      await bloc.stream.firstWhere((s) => s.registrado);

      bloc.add(const RegistroReenvioPedido());
      await bloc.stream.firstWhere((s) => s.errorReenvio != null);

      expect(
        bloc.state.errorReenvio,
        'Sin conexión con el servidor. Revisa tu Internet.',
      );
      expect(bloc.state.puedeReenviar, isTrue);
    });

    test('409: el mensaje del servidor, una vez, y el formulario sigue ahí; '
        'el siguiente intento lo borra', () async {
      servicio.errorAlRegistrar = errorHttp(
        409,
        'Ya existe una cuenta con ese correo. Inicia sesión o recupera tu '
        'contraseña.',
      );
      final bloc = await listo();
      addTearDown(bloc.close);
      await aceptarTodo(bloc);

      final estados = <RegistroState>[];
      final escucha = bloc.stream.listen(estados.add);
      addTearDown(escucha.cancel);

      bloc.add(RegistroEnviado(datosDePrueba()));
      await bloc.stream.firstWhere((s) => !s.enviando && s.error != null);

      expect(bloc.state.registrado, isFalse);
      expect(
        bloc.state.error,
        'Ya existe una cuenta con ese correo. Inicia sesión o recupera tu '
        'contraseña.',
      );
      expect(estados.map((s) => s.enviando), [true, false]);

      servicio.errorAlRegistrar = null;
      bloc.add(RegistroEnviado(datosDePrueba()));
      await bloc.stream.firstWhere((s) => s.enviando);
      expect(bloc.state.error, isNull);
      await bloc.stream.firstWhere((s) => s.registrado);
    });

    test('un segundo toque mientras se envía no manda dos registros', () async {
      servicio.registroPendiente = Completer<void>();
      final bloc = await listo();
      addTearDown(bloc.close);
      await aceptarTodo(bloc);

      bloc
        ..add(RegistroEnviado(datosDePrueba()))
        ..add(RegistroEnviado(datosDePrueba()));
      await bloc.stream.firstWhere((s) => s.enviando);
      servicio.registroPendiente!.complete();
      await bloc.stream.firstWhere((s) => s.registrado);

      expect(servicio.registros, hasLength(1));
    });
  });
}
