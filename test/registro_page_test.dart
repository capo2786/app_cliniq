// test/registro_page_test.dart

import 'package:app_cliniq/core/configuracion/config_publica.dart';
import 'package:app_cliniq/core/network/api_client.dart';
import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/auth/data/models/datos_registro.dart';
import 'package:app_cliniq/features/auth/dominio/registro.dart';
import 'package:app_cliniq/features/auth/presentacion/registro_page.dart';
import 'package:app_cliniq/features/legal/data/legal_service.dart';
import 'package:app_cliniq/features/legal/presentacion/documento_legal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/adaptador_http.dart';
import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/navegador_falso.dart';
import 'dobles/registro.dart';

/// El registro de pacientes dentro de la aplicación: el del panel web, con
/// el diseño de la aplicación. Nada abre el navegador.
void main() {
  late AuthServiceFalso servicio;
  late DioGrabador legalApi;

  setUp(() {
    sondeoConRed();
    servicio = AuthServiceFalso();
    legalApi = DioGrabador({
      'GET /legal/documentos': (_) => documentosVigentesJson(),
    });

    // El lector de documentos que abre «Leer» (por el enrutador) usa los
    // servicios de la aplicación.
    Servicios.cacheParaPruebas = CacheEnMemoria();
    ApiClient().dio.httpClientAdapter = AdaptadorHttpFalso({
      'GET /legal/documentos/terminos': (_) => (
        estado: 200,
        cuerpo: {
          'clave': 'TERMINOS',
          'slug': 'terminos',
          'version': '1.0',
          'titulo': 'Términos y condiciones de uso',
          'contenido': 'Estas son las reglas para usar la aplicación.',
        },
      ),
    });
  });

  /// Abre el registro desde una pantalla de acceso de mentira y devuelve lo
  /// que el registro le entrega al cerrarse.
  Future<List<String?>> montar(
    WidgetTester tester, {
    ConfigPublica? config,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final devuelto = <String?>[];

    await tester.pumpWidget(
      conDatosDeLaClinica(
        config: config,
        MaterialApp(
          theme: temaCliniq(),
          locale: const Locale('es'),
          supportedLocales: const [Locale('es')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => devuelto.add(
                    await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => RegistroPage(
                          servicio: servicio,
                          legal: LegalService(legalApi.dio, CacheEnMemoria()),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Acceso'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Acceso'));
    await tester.pumpAndSettle();

    return devuelto;
  }

  Future<void> tocar(WidgetTester tester, Finder objetivo) async {
    await tester.ensureVisible(objetivo);
    await tester.pumpAndSettle();
    await tester.tap(objetivo);
    await tester.pumpAndSettle();
  }

  Future<void> escribir(WidgetTester tester, String clave, String texto) async {
    final campo = find.byKey(Key(clave));
    await tester.ensureVisible(campo);
    await tester.enterText(campo, texto);
    await tester.pump();
  }

  /// La fecha que queda al elegir el 17 en el selector, que abre en enero de
  /// hace 30 años.
  String fechaElegida() {
    final hoy = Servicios.reloj.hoy();
    return '${hoy.year - 30}-01-17';
  }

  Future<void> elegirFecha(WidgetTester tester) async {
    await tocar(tester, find.byKey(const Key('registro-nacimiento')));
    await tester.tap(find.text('17'));
    await tester.pump();
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
  }

  Future<void> llenarTodo(WidgetTester tester) async {
    await escribir(tester, 'registro-nombre', '  Ana   María Torres ');
    await escribir(tester, 'registro-correo', 'Ana.Torres@Correo.com');
    await escribir(tester, 'registro-telefono', '0991234567');
    await escribir(tester, 'registro-documento', '1710034065');
    await elegirFecha(tester);
    await tocar(tester, find.byKey(const Key('registro-sexo')));
    await tester.tap(find.text('Femenino').last);
    await tester.pumpAndSettle();
    await escribir(tester, 'registro-contrasena', 'Clave-segura-1');
    await escribir(tester, 'registro-confirmar', 'Clave-segura-1');
    await tocar(tester, find.byKey(const Key('aceptar-registro-TERMINOS')));
    await tocar(tester, find.byKey(const Key('aceptar-registro-PRIVACIDAD')));
  }

  Finder boton(String clave) => find.descendant(
    of: find.byKey(Key(clave)),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
  );

  bool habilitado(WidgetTester tester, String clave) =>
      tester.widget<ButtonStyleButton>(boton(clave)).onPressed != null;

  testWidgets('pide lo mismo que el panel: tus datos, el documento y el sexo '
      'de los catálogos, la contraseña y los documentos de la clínica', (
    tester,
  ) async {
    final navegador = NavegadorFalso()..instalar();
    await montar(tester);

    expect(find.text('Crea tu cuenta'), findsOneWidget);
    for (final rotulo in [
      'Nombres y apellidos *',
      'Correo electrónico *',
      'Teléfono',
      'Documento *',
      'Número de cédula *',
      'Fecha de nacimiento *',
      'Sexo',
      'Contraseña *',
      'Repite la contraseña *',
    ]) {
      expect(find.text(rotulo), findsOneWidget, reason: rotulo);
    }
    expect(find.text('Cédula'), findsOneWidget);
    expect(find.text('Pasaporte'), findsOneWidget);
    expect(find.text('Prefiero no decirlo'), findsWidgets);
    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);

    // Los dos que se aceptan al registrarse, con su casilla…
    expect(find.text('Términos y condiciones de uso'), findsOneWidget);
    expect(
      find.text('Política de privacidad y protección de datos'),
      findsOneWidget,
    );
    expect(find.text('He leído y acepto este documento'), findsNWidgets(2));
    // …y los demás de los pacientes, para leerlos (se aceptan al entrar).
    expect(find.text('Aviso legal'), findsOneWidget);
    expect(
      find.text('Consentimiento informado para telemedicina'),
      findsOneWidget,
    );
    expect(find.text('Condiciones para médicos'), findsNothing);
    expect(navegador.abiertas, isEmpty);
  });

  testWidgets('sin llenar: cada campo dice qué falta con los mensajes del '
      'panel, y no se envía nada', (tester) async {
    await montar(tester);

    await tocar(tester, find.byKey(const Key('boton-crear-mi-cuenta')));

    for (final mensaje in [
      'Escribe tus nombres y apellidos.',
      'Escribe tu correo.',
      'Escribe el número de tu documento.',
      'Indica tu fecha de nacimiento.',
      'Crea una contraseña.',
      'Repite la contraseña.',
      mensajeFaltaAceptar,
    ]) {
      expect(find.text(mensaje), findsOneWidget, reason: mensaje);
    }
    expect(servicio.registros, isEmpty);
  });

  testWidgets('la cédula se revisa como la clínica lo pida; el pasaporte, de '
      '5 a 20 letras o números', (tester) async {
    await montar(tester);

    await escribir(tester, 'registro-documento', '1710034066');
    await tocar(tester, find.byKey(const Key('boton-crear-mi-cuenta')));
    expect(
      find.text('La cédula no es válida. Revisa los diez dígitos.'),
      findsOneWidget,
    );

    await tocar(tester, find.text('Pasaporte'));
    expect(find.text('Número de pasaporte *'), findsOneWidget);

    await escribir(tester, 'registro-documento', 'A12');
    expect(
      find.text('El pasaporte debe tener entre 5 y 20 letras o números.'),
      findsOneWidget,
    );

    await escribir(tester, 'registro-documento', 'AB12345');
    expect(
      find.text('El pasaporte debe tener entre 5 y 20 letras o números.'),
      findsNothing,
    );
  });

  testWidgets('la contraseña: las pistas del panel con el mínimo de la '
      'clínica, y la confirmación tiene que coincidir', (tester) async {
    await montar(
      tester,
      config: configDePrueba(seguridad: {'passwordMinimo': 10}),
    );

    expect(find.text('Mínimo 10 caracteres'), findsOneWidget);

    await escribir(tester, 'registro-contrasena', 'abcdefghij');
    expect(find.text('Débil: usa al menos 10 caracteres'), findsOneWidget);

    await escribir(tester, 'registro-contrasena', 'Abcdefghijklm1!');
    expect(find.text('Muy buena'), findsOneWidget);

    await escribir(tester, 'registro-contrasena', 'corta');
    await escribir(tester, 'registro-confirmar', 'otra');
    await tocar(tester, find.byKey(const Key('boton-crear-mi-cuenta')));

    expect(find.text('Debe tener al menos 10 caracteres.'), findsOneWidget);
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
  });

  testWidgets('«Leer» abre el documento con el lector de la aplicación, por '
      'el enrutador', (tester) async {
    final navegador = NavegadorFalso()..instalar();
    await montar(tester);

    await tocar(tester, find.byKey(const Key('leer-registro-TERMINOS')));

    expect(find.byType(DocumentoLegalPage), findsOneWidget);
    expect(
      find.textContaining('Estas son las reglas para usar la aplicación.'),
      findsOneWidget,
    );
    expect(navegador.abiertas, isEmpty);
  });

  testWidgets('sin los documentos no se puede aceptar: lo dice con '
      '«Reintentar»', (tester) async {
    legalApi.rutas['GET /legal/documentos'] = (_) => throw errorDeRed();
    await montar(tester);

    expect(find.text('No pudimos cargar esto'), findsOneWidget);

    legalApi.rutas['GET /legal/documentos'] = (_) => documentosVigentesJson();
    await tocar(tester, find.text('Reintentar'));

    expect(find.text('Términos y condiciones de uso'), findsOneWidget);
  });

  testWidgets('con todo bien: POST /auth/registro como el panel, «Revisa tu '
      'correo» con la espera de la clínica, «Reenviar enlace» y «Volver a '
      'ingresar» con el correo', (tester) async {
    final devuelto = await montar(
      tester,
      config: configDePrueba(seguridad: {'reenvioSegundos': 45}),
    );

    await llenarTodo(tester);
    await tocar(tester, find.byKey(const Key('boton-crear-mi-cuenta')));

    expect(servicio.registros, [
      DatosRegistro(
        nombre: '  Ana   María Torres ',
        email: 'Ana.Torres@Correo.com',
        telefono: '0991234567',
        tipoDocumento: 'CEDULA',
        cedula: '1710034065',
        fechaNacimiento: fechaElegida(),
        sexo: 'F',
        password: 'Clave-segura-1',
      ),
    ]);
    expect(servicio.registros.single.aJson(), {
      'nombre': 'Ana María Torres',
      'email': 'ana.torres@correo.com',
      'telefono': '0991234567',
      'tipoDocumento': 'CEDULA',
      'cedula': '1710034065',
      'fechaNacimiento': fechaElegida(),
      'sexo': 'F',
      'password': 'Clave-segura-1',
      'aceptaTerminos': true,
    });

    expect(
      find.text('Revisa tu correo para confirmar tu cuenta'),
      findsOneWidget,
    );
    expect(find.textContaining('ana.torres@correo.com'), findsOneWidget);
    expect(find.text('Reenviar en 45 s'), findsOneWidget);
    expect(habilitado(tester, 'boton-reenviar-registro'), isFalse);

    // El reloj de la prueba avanza solo en la pantalla, sin esperar de
    // verdad.
    await tester.pump(const Duration(seconds: 44));
    expect(find.text('Reenviar en 1 s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Reenviar enlace'), findsOneWidget);
    expect(habilitado(tester, 'boton-reenviar-registro'), isTrue);

    await tocar(tester, find.byKey(const Key('boton-reenviar-registro')));
    expect(servicio.llamadas.last, 'reenviar:ana.torres@correo.com');
    expect(
      find.text(
        'Te enviamos un enlace nuevo. Revisa también la carpeta de correo no '
        'deseado.',
      ),
      findsOneWidget,
    );
    expect(find.text('Reenviar en 45 s'), findsOneWidget);

    await tocar(tester, find.byKey(const Key('boton-volver-a-ingresar')));

    expect(find.byType(RegistroPage), findsNothing);
    expect(devuelto, ['ana.torres@correo.com']);
  });

  testWidgets('si el servidor no crea la cuenta, su mensaje se ve una sola '
      'vez, sobre el botón, y el formulario queda como estaba', (tester) async {
    const motivo =
        'Ya existe una cuenta con ese número de documento. Si es tuya, '
        'inicia sesión o recupera tu contraseña.';
    servicio.errorAlRegistrar = errorHttp(409, motivo);
    await montar(tester);

    await llenarTodo(tester);
    await tocar(tester, find.byKey(const Key('boton-crear-mi-cuenta')));

    expect(find.text(motivo), findsOneWidget);
    expect(find.byKey(const Key('error-registro')), findsOneWidget);
    expect(
      find.text('Revisa tu correo para confirmar tu cuenta'),
      findsNothing,
    );
    expect(find.text('Ana.Torres@Correo.com'), findsOneWidget);

    // Otro intento borra el mensaje anterior.
    servicio.errorAlRegistrar = null;
    await tocar(tester, find.byKey(const Key('boton-crear-mi-cuenta')));
    expect(find.text(motivo), findsNothing);
    expect(
      find.text('Revisa tu correo para confirmar tu cuenta'),
      findsOneWidget,
    );
  });
}
