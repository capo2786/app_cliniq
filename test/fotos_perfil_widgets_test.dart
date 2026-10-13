// test/fotos_perfil_widgets_test.dart

import 'package:app_cliniq/core/servicios.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/fotos_perfil/presentacion/avatar_editable.dart';
import 'package:app_cliniq/features/fotos_perfil/presentacion/avatar_usuario.dart';
import 'package:app_cliniq/features/fotos_perfil/presentacion/hoja_foto_perfil.dart';
import 'package:app_cliniq/features/fotos_perfil/providers/foto_perfil_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/fotos_perfil.dart';

/// El avatar (foto o iniciales) y la hoja para poner, cambiar o quitar la
/// foto, con la cámara, el recorte y la API de mentira.
void main() {
  final png = pngDePrueba(16, 16);
  late FotosPerfilFalso fotos;
  late SelectorDeFotoFalso selector;

  setUp(() {
    sondeoConRed();
    fotos = FotosPerfilFalso(fotos: {'u1@3': png}, versionNueva: 4);
    selector = SelectorDeFotoFalso(foto: png);
    Servicios.fotosPerfilParaPruebas = fotos;
  });

  Future<void> montar(WidgetTester tester, Widget hijo) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: temaCliniq(),
        home: Scaffold(body: Center(child: hijo)),
      ),
    );
    await tester.pump();
  }

  group('AvatarUsuario', () {
    testWidgets('sin versión: las iniciales, sin pedir nada', (tester) async {
      await montar(
        tester,
        AvatarUsuario(uid: 'u1', nombre: 'Ana María', servicio: fotos),
      );

      expect(find.text('AM'), findsOneWidget);
      expect(find.byKey(const Key('avatar-foto')), findsNothing);
      expect(fotos.llamadas, isEmpty);
    });

    testWidgets('con versión: la foto de esa versión', (tester) async {
      await montar(
        tester,
        AvatarUsuario(
          uid: 'u1',
          nombre: 'Ana María',
          fotoVersion: 3,
          servicio: fotos,
        ),
      );

      expect(fotos.llamadas, ['obtener:u1@3']);
      expect(find.byKey(const Key('avatar-foto')), findsOneWidget);
      expect(find.text('AM'), findsNothing);
    });

    testWidgets('si no llega (404, sin red): se quedan las iniciales', (
      tester,
    ) async {
      await montar(
        tester,
        AvatarUsuario(
          uid: 'u2',
          nombre: 'Luis Mora',
          fotoVersion: 1,
          servicio: fotos,
        ),
      );

      expect(find.text('LM'), findsOneWidget);
      expect(find.byKey(const Key('avatar-foto')), findsNothing);
    });

    testWidgets('el médico sin versión: se pide la vigente', (tester) async {
      fotos.fotos['m1@vigente'] = png;

      await montar(
        tester,
        AvatarUsuario(
          uid: 'm1',
          nombre: 'Luis Mora',
          buscarSinVersion: true,
          servicio: fotos,
        ),
      );

      expect(fotos.llamadas, ['vigente:m1']);
      expect(find.byKey(const Key('avatar-foto')), findsOneWidget);
    });

    testWidgets('al cambiar la versión se pide la nueva', (tester) async {
      fotos.fotos['u1@4'] = png;
      Widget avatar(int? v) => AvatarUsuario(
        uid: 'u1',
        nombre: 'Ana',
        fotoVersion: v,
        servicio: fotos,
      );

      await montar(tester, avatar(3));
      await montar(tester, avatar(4));
      expect(fotos.llamadas, ['obtener:u1@3', 'obtener:u1@4']);

      // Quitada: vuelven las iniciales.
      await montar(tester, avatar(null));
      expect(find.text('A'), findsOneWidget);
    });
  });

  group('La hoja de la foto', () {
    /// Abre la hoja y devuelve cómo leer lo que devolvió al cerrarse.
    Future<FotoPerfilState? Function()> abrir(
      WidgetTester tester, {
      int? fotoVersion,
      bool propia = true,
    }) async {
      FotoPerfilState? resultado;
      final duenio = DuenioDeFoto(
        uid: propia ? 'u1' : 'd1',
        nombre: propia ? 'Ana María' : 'Sofía',
        fotoVersion: fotoVersion,
        propia: propia,
      );

      await montar(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              resultado = await mostrarHojaFotoPerfil(
                context,
                duenio,
                crearCubit: () => FotoPerfilCubit(
                  fotos: fotos,
                  selector: selector,
                  recortar: (_) async => png,
                  uid: propia ? null : duenio.uid,
                  uidPropio: propia ? duenio.uid : null,
                ),
              );
            },
            child: const Text('abrir'),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      return () => resultado;
    }

    testWidgets('sin foto: cámara o galería, y no se ofrece quitar', (
      tester,
    ) async {
      await abrir(tester);

      expect(find.text('Tu foto de perfil'), findsOneWidget);
      expect(find.text('Tomar una foto'), findsOneWidget);
      expect(find.text('Elegir de la galería'), findsOneWidget);
      expect(find.text('Quitar'), findsNothing);
    });

    testWidgets('elegir, ver la vista previa y guardar', (tester) async {
      final resultado = await abrir(tester);

      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('foto-vista-previa')), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
      expect(find.text('Cambiar'), findsOneWidget);

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(fotos.llamadas, contains('subir:me'));
      expect(find.text('Guardar'), findsNothing);
      expect(resultado()?.fase, FaseFoto.listo);
      expect(resultado()?.version, 4);
    });

    testWidgets('«Cambiar» vuelve a preguntar de dónde sacarla', (
      tester,
    ) async {
      await abrir(tester);
      await tester.tap(find.text('Tomar una foto'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir de la galería').last);
      await tester.pumpAndSettle();

      expect(selector.pedidos.map((o) => o.name), ['camara', 'galeria']);
      expect(find.byKey(const Key('foto-vista-previa')), findsOneWidget);
    });

    testWidgets('quitar la de un dependiente pide confirmación', (
      tester,
    ) async {
      await abrir(tester, fotoVersion: 3, propia: false);

      expect(find.text('Foto de perfil de Sofía'), findsOneWidget);
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Quitar la foto de Sofía?'), findsOneWidget);
      await tester.tap(find.text('Quitar').last);
      await tester.pumpAndSettle();

      expect(fotos.llamadas, contains('quitar:d1'));
      expect(find.text('Foto de perfil de Sofía'), findsNothing);
    });

    testWidgets('un error de la API se lee dentro de la hoja', (tester) async {
      fotos.error = Exception('rechazada');
      await abrir(tester);

      await tester.tap(find.text('Elegir de la galería'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(
        find.text('No pudimos guardar la foto. Intenta de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Guardar'), findsOneWidget);
    });
  });

  testWidgets('el avatar editable abre la hoja y avisa del cambio', (
    tester,
  ) async {
    Servicios.selectorDeFotoParaPruebas = selector;
    FotoPerfilState? cambio;

    await montar(
      tester,
      AvatarEditable(
        duenio: const DuenioDeFoto(
          uid: 'u1',
          nombre: 'Ana María',
          fotoVersion: 3,
          propia: true,
        ),
        alCambiar: (r) => cambio = r,
      ),
    );

    await tester.tap(find.byKey(const Key('avatar-editable-u1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar').last);
    await tester.pumpAndSettle();

    expect(cambio?.quitada, isTrue);
    expect(fotos.llamadas, contains('quitar:me'));
  });
}
