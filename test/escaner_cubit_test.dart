// test/escaner_cubit_test.dart
//
// El cubit del escáner con una fuente de cuadros falsa: el aviso, medir,
// guardar, enviar al médico, sin red, el 409, la calidad baja, el
// permiso y salir de la aplicación a mitad.

import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/mediciones/data/cola_mediciones.dart';
import 'package:app_cliniq/features/mediciones/data/mediciones_service.dart';
import 'package:app_cliniq/features/mediciones/data/models/medicion.dart';
import 'package:app_cliniq/features/mediciones/dominio/destinos_medico.dart';
import 'package:app_cliniq/features/mediciones/escaner/analizador_de_medicion.dart';
import 'package:app_cliniq/features/mediciones/escaner/aviso_experimental.dart';
import 'package:app_cliniq/features/mediciones/escaner/escaner_cubit.dart';
import 'package:app_cliniq/features/mediciones/escaner/fuente_de_cuadros.dart';
import 'package:app_cliniq/features/mediciones/escaner/motor_signos_camara.dart';
import 'package:app_cliniq/features/mediciones/escaner/serie_senal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/mediciones.dart';
import 'dobles/senales.dart';

/// Una imagen de un solo color en el formato pedido.

void main() {
  group('El cubit, con una fuente falsa', () {
    late FuenteFalsa fuente;
    late CacheLocal cache;
    late DioGrabador api;
    late Object? Function(RequestOptions) alGuardar;

    setUp(() {
      fuente = FuenteFalsa();
      cache = CacheEnMemoria();
      alGuardar = (_) => {'mediciones': <Object>[]};
      api = DioGrabador({
        'POST /portal/mediciones': (pedido) => alGuardar(pedido),
      });
    });

    EscanerCubit nuevo({int segundos = 20}) => EscanerCubit(
      fuente: fuente,
      motor: const MotorInterno(),
      analizador: const AnalizadorDeMedicion(
        local: MotorInterno(),
        hayRed: _sinRed,
      ),
      cola: ColaMediciones(cache, MedicionesService(api.dio, cache)),
      aviso: AvisoDelEscaner(cache),
      uid: 'u1',
      segundos: segundos,
      ahora: () => DateTime.utc(2026, 10, 3, 15, 20),
    );

    test('la primera vez, el aviso; después, recordado en la caché', () async {
      final cubit = nuevo();
      await cubit.iniciar();
      expect(cubit.state.paso, PasoEscaner.aviso);
      await cubit.aceptarAviso();
      expect(cubit.state.paso, PasoEscaner.modo);
      await cubit.close();

      final otra = nuevo();
      await otra.iniciar();
      expect(otra.state.paso, PasoEscaner.modo);
      await otra.close();
    });

    test(
      'mide, cuenta hacia atrás con los cuadros, analiza y guarda',
      () async {
        final cubit = nuevo();
        await cubit.iniciar();
        cubit.elegirModo(ModoEscaner.dedo);
        await cubit.empezar();
        expect(cubit.state.paso, PasoEscaner.midiendo);
        expect(fuente.abiertas, [ModoEscaner.dedo]);

        final cuadros = cuadrosDeDedo(
          Sintetizador(10).dedo(lpm: 72, segundos: 21, respiracionRpm: 15),
        );
        fuente.emitir(cuadros.take(300).toList());
        expect(cubit.state.segundosRestantes, inInclusiveRange(9, 11));
        expect(cubit.state.lectura.onda, isNotEmpty);

        fuente.emitir(cuadros.skip(300).toList());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.paso, PasoEscaner.resultado);
        expect(cubit.state.resultado!.fc, closeTo(72, 3));
        expect(
          fuente.abierta,
          isFalse,
          reason: 'la cámara se suelta al terminar',
        );

        cubit.elegirContexto(ContextoMedicion.reposo);
        await cubit.guardar();
        expect(cubit.state.paso, PasoEscaner.guardado);
        expect(cubit.state.registro, isA<RegistroEnviado>());

        final cuerpo = api.ultimo('POST /portal/mediciones').data as Map;
        final mediciones = cuerpo['mediciones'] as List;
        expect(mediciones.first['tipo'], 'FC');
        expect(mediciones.first['metodo'], 'CAMARA_DEDO');
        expect(mediciones.first['contexto'], 'REPOSO');
        expect(mediciones.first['notas'], 'motor: interno-ppg v1');
        expect(mediciones.first['medidoEn'], '2026-10-03T15:20:00.000Z');
        expect(mediciones.first['calidad'], greaterThan(0.7));
        // Nunca presión, saturación, temperatura ni glucosa desde la cámara.
        expect(
          mediciones.every((m) => m['tipo'] == 'FC' || m['tipo'] == 'FR'),
          isTrue,
        );
        await cubit.close();
      },
    );

    test('«Enviar a mi médico» lo adjunta a la cita elegida', () async {
      final cubit = nuevo();
      await cubit.iniciar();
      cubit.elegirModo(ModoEscaner.dedo);
      await cubit.empezar();
      fuente.emitir(
        cuadrosDeDedo(Sintetizador(11).dedo(lpm: 60, segundos: 21)),
      );
      await Future<void>.delayed(Duration.zero);

      await cubit.guardar(
        destino: const DestinoMedico.cita('cita9', titulo: 'Cita'),
      );
      final medicion =
          ((api.ultimo('POST /portal/mediciones').data as Map)['mediciones']
                  as List)
              .first;
      expect(medicion['citaId'], 'cita9');
      expect(cubit.state.enviadaA?.citaId, 'cita9');
      await cubit.close();
    });

    test('sin red al guardar: queda pendiente en el teléfono', () async {
      alGuardar = (_) => throw errorDeRed();
      final cubit = nuevo();
      await cubit.iniciar();
      cubit.elegirModo(ModoEscaner.dedo);
      await cubit.empezar();
      fuente.emitir(
        cuadrosDeDedo(Sintetizador(12).dedo(lpm: 110, segundos: 21)),
      );
      await Future<void>.delayed(Duration.zero);

      await cubit.guardar();
      expect(cubit.state.registro, isA<RegistroPendiente>());
      expect(cache.leer('mediciones-pendientes:u1'), completion(isNotNull));
      await cubit.close();
    });

    test('el administrador apagó la cámara: el 409 se enseña', () async {
      alGuardar = (_) => throw errorHttp(
        409,
        'El escáner con la cámara está desactivado en esta clínica.',
      );
      final cubit = nuevo();
      await cubit.iniciar();
      cubit.elegirModo(ModoEscaner.dedo);
      await cubit.empezar();
      fuente.emitir(
        cuadrosDeDedo(Sintetizador(12).dedo(lpm: 72, segundos: 21)),
      );
      await Future<void>.delayed(Duration.zero);

      await cubit.guardar();
      expect(cubit.state.paso, PasoEscaner.resultado);
      expect(cubit.state.errorAlGuardar, contains('desactivado'));
      await cubit.close();
    });

    test('con la calidad baja sostenida, se detiene con un consejo', () async {
      final cubit = nuevo(segundos: 30);
      await cubit.iniciar();
      cubit.elegirModo(ModoEscaner.dedo);
      await cubit.empezar();
      fuente.emitir(
        cuadrosDeDedo(
          Sintetizador(13).dedo(lpm: 72, segundos: 30),
          cobertura: 0.2,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.paso, PasoEscaner.fallo);
      expect(cubit.state.fallo, contains('cubre bien la cámara'));
      expect(fuente.abierta, isFalse);
      await cubit.close();
    });

    test('el permiso de la cámara bloqueado: «Abrir ajustes»', () async {
      fuente.errorAlAbrir = const ErrorDeCamara(
        MotivoErrorCamara.permisoBloqueado,
      );
      final cubit = nuevo();
      await cubit.iniciar();
      cubit.elegirModo(ModoEscaner.dedo);
      await cubit.empezar();

      expect(cubit.state.paso, PasoEscaner.fallo);
      expect(cubit.state.fallaPorPermiso, isTrue);
      await cubit.abrirAjustes();
      expect(fuente.ajustes, 1);
      await cubit.close();
    });

    test(
      'al salir de la aplicación a mitad, se interrumpe y suelta la cámara',
      () async {
        final cubit = nuevo();
        await cubit.iniciar();
        cubit.elegirModo(ModoEscaner.rostro);
        await cubit.empezar();
        expect(fuente.abiertas, [ModoEscaner.rostro]);

        await cubit.interrumpir();
        expect(cubit.state.paso, PasoEscaner.fallo);
        expect(fuente.abierta, isFalse);
        await cubit.close();
      },
    );
  });
}

bool _sinRed() => false;
