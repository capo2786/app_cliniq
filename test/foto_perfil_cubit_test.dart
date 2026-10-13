// test/foto_perfil_cubit_test.dart

import 'package:app_cliniq/features/dependientes/data/models/dependiente.dart';
import 'package:app_cliniq/features/dependientes/providers/dependientes_bloc.dart';
import 'package:app_cliniq/features/fotos_perfil/data/selector_de_foto.dart';
import 'package:app_cliniq/features/fotos_perfil/providers/foto_perfil_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dobles.dart';
import 'dobles/fotos_perfil.dart';

/// Elegir, recortar, guardar y quitar la foto, con la cámara, el recorte y
/// la API de mentira.
void main() {
  final elegida = Uint8List.fromList([1, 2, 3]);
  late SelectorDeFotoFalso selector;
  late FotosPerfilFalso fotos;

  setUp(() {
    selector = SelectorDeFotoFalso(foto: elegida);
    fotos = FotosPerfilFalso(versionNueva: 5);
  });

  FotoPerfilCubit cubit({
    String? uid,
    Future<Uint8List> Function(Uint8List)? recortar,
  }) => FotoPerfilCubit(
    fotos: fotos,
    selector: selector,
    recortar: recortar ?? (_) async => jpegFalso,
    uid: uid,
    uidPropio: uid == null ? 'u1' : null,
  );

  blocTest<FotoPerfilCubit, FotoPerfilState>(
    'elegir de la galería: se recorta y queda en vista previa',
    build: cubit,
    act: (c) => c.elegir(OrigenFoto.galeria),
    expect: () => [
      const FotoPerfilState(fase: FaseFoto.procesando),
      FotoPerfilState(fase: FaseFoto.vistaPrevia, nueva: jpegFalso),
    ],
    verify: (_) => expect(selector.pedidos, [OrigenFoto.galeria]),
  );

  blocTest<FotoPerfilCubit, FotoPerfilState>(
    'si se arrepiente, nada cambia',
    setUp: () => selector.foto = null,
    build: cubit,
    act: (c) => c.elegir(OrigenFoto.camara),
    expect: () => const <FotoPerfilState>[],
  );

  blocTest<FotoPerfilCubit, FotoPerfilState>(
    'sin permiso de cámara: lo dice',
    setUp: () =>
        selector.error = PlatformException(code: 'camera_access_denied'),
    build: cubit,
    act: (c) => c.elegir(OrigenFoto.camara),
    expect: () => [
      isA<FotoPerfilState>()
          .having((s) => s.fase, 'fase', FaseFoto.eligiendo)
          .having((s) => s.error, 'error', contains('cámara')),
    ],
  );

  blocTest<FotoPerfilCubit, FotoPerfilState>(
    'una imagen que no se puede leer: lo dice y sigue eligiendo',
    build: () => cubit(
      recortar: (_) async => throw const FormatException('no es imagen'),
    ),
    act: (c) => c.elegir(OrigenFoto.galeria),
    expect: () => [
      const FotoPerfilState(fase: FaseFoto.procesando),
      const FotoPerfilState(
        fase: FaseFoto.eligiendo,
        error: 'No pudimos leer esa imagen. Prueba con otra foto.',
      ),
    ],
  );

  blocTest<FotoPerfilCubit, FotoPerfilState>(
    'guardar la propia: sube a /auth/me/foto y termina con la versión',
    build: cubit,
    seed: () => FotoPerfilState(fase: FaseFoto.vistaPrevia, nueva: jpegFalso),
    act: (c) => c.guardar(),
    expect: () => [
      FotoPerfilState(fase: FaseFoto.guardando, nueva: jpegFalso),
      const FotoPerfilState(fase: FaseFoto.listo, version: 5),
    ],
    verify: (_) => expect(fotos.llamadas, ['subir:me']),
  );

  blocTest<FotoPerfilCubit, FotoPerfilState>(
    'guardar la de un dependiente: a /auth/:id/foto',
    build: () => cubit(uid: 'd1'),
    seed: () => FotoPerfilState(fase: FaseFoto.vistaPrevia, nueva: jpegFalso),
    act: (c) => c.guardar(),
    skip: 1,
    expect: () => [const FotoPerfilState(fase: FaseFoto.listo, version: 5)],
    verify: (_) => expect(fotos.llamadas, ['subir:d1']),
  );

  blocTest<FotoPerfilCubit, FotoPerfilState>(
    'si la API la rechaza, vuelve a la vista previa con su mensaje',
    setUp: () => fotos.error = errorHttp(400, 'La imagen pesa más de 1 MB.'),
    build: cubit,
    seed: () => FotoPerfilState(fase: FaseFoto.vistaPrevia, nueva: jpegFalso),
    act: (c) => c.guardar(),
    skip: 1,
    expect: () => [
      isA<FotoPerfilState>()
          .having((s) => s.fase, 'fase', FaseFoto.vistaPrevia)
          .having((s) => s.nueva, 'nueva', jpegFalso)
          .having((s) => s.error, 'error', isNotNull),
    ],
  );

  blocTest<FotoPerfilCubit, FotoPerfilState>(
    'sin foto nueva, guardar no hace nada',
    build: cubit,
    act: (c) => c.guardar(),
    expect: () => const <FotoPerfilState>[],
  );

  blocTest<FotoPerfilCubit, FotoPerfilState>(
    'quitar: termina avisando que se quitó',
    build: cubit,
    act: (c) => c.quitar(),
    expect: () => [
      const FotoPerfilState(fase: FaseFoto.quitando),
      const FotoPerfilState(fase: FaseFoto.listo, quitada: true),
    ],
    verify: (_) => expect(fotos.llamadas, ['quitar:me']),
  );

  blocTest<FotoPerfilCubit, FotoPerfilState>(
    'quitar sin red: lo dice',
    setUp: () => fotos.error = errorDeRed(),
    build: cubit,
    act: (c) => c.quitar(),
    skip: 1,
    expect: () => [
      isA<FotoPerfilState>()
          .having((s) => s.fase, 'fase', FaseFoto.eligiendo)
          .having((s) => s.error, 'error', contains('conexión')),
    ],
  );

  group('Mensajes de la API al guardar', () {
    test('413 y 415, con palabras propias; 400, el de la API', () {
      expect(
        mensajeAlGuardarFoto(errorHttp(413, 'File too large')),
        contains('1 MB'),
      );
      expect(
        mensajeAlGuardarFoto(errorHttp(415, 'Unsupported')),
        contains('JPEG, PNG o WebP'),
      );
      expect(
        mensajeAlGuardarFoto(
          errorHttp(400, 'La imagen debe medir al menos 128 px.'),
        ),
        'La imagen debe medir al menos 128 px.',
      );
    });
  });

  group('Dependientes', () {
    const sofia = Dependiente(uid: 'd1', nombre: 'Sofía');
    const pedro = Dependiente(uid: 'd2', nombre: 'Pedro');

    blocTest<DependientesBloc, DependientesState>(
      'la foto nueva de un dependiente se ve al instante',
      build: () => DependientesBloc(DependientesFalso()),
      seed: () => const DependientesState(
        carga: CargaDependientes.lista,
        lista: [pedro, sofia],
      ),
      act: (b) => b.add(const DependienteFotoCambiada('d1', 3)),
      expect: () => [
        isA<DependientesState>().having(
          (s) => [for (final d in s.lista) d.fotoVersion],
          'versiones',
          [null, 3],
        ),
      ],
    );

    blocTest<DependientesBloc, DependientesState>(
      'y después se relee la lista del servidor',
      build: () =>
          DependientesBloc(DependientesFalso([pedro, sofia.conFotoVersion(3)])),
      act: (b) async {
        b.add(const DependientesSolicitados('u1'));
        await Future<void>.delayed(Duration.zero);
        b.add(const DependienteFotoCambiada('d1', 3));
      },
      wait: const Duration(milliseconds: 10),
      verify: (b) =>
          expect([for (final d in b.state.lista) d.fotoVersion], [null, 3]),
    );
  });
}
