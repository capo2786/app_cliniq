// test/citas_bloc_test.dart

import 'package:app_cliniq/core/fechas/fecha_local.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/citas/data/citas_service.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/citas/providers/citas_bloc.dart';
import 'package:app_cliniq/features/citas/providers/citas_event.dart';
import 'package:app_cliniq/features/citas/providers/citas_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dobles.dart';

/// Un Dio que contesta desde una función, para probar el servicio real con
/// su caché.
Dio dioFalso(Future<Response<dynamic>> Function(RequestOptions) responder) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (opciones, manejador) async {
        try {
          manejador.resolve(await responder(opciones));
        } on DioException catch (error) {
          manejador.reject(error);
        }
      },
    ),
  );
  return dio;
}

void main() {
  final reloj = RelojClinica.fijo(DateTime(2026, 9, 28, 9));

  Map<String, dynamic> citaJson(
    String id,
    String inicio, {
    String estado = 'PROGRAMADA',
  }) => {
    '_id': id,
    'start': '${inicio}T09:00:00.000Z',
    'end': '${inicio}T09:30:00.000Z',
    'type': 'PRESENCIAL',
    'status': estado,
    'doctorId': 'doc',
    'doctorName': 'Ana Pérez',
  };

  group('Mis citas, con la copia en el teléfono', () {
    late CacheLocal cache;
    late bool hayRed;
    late ProgramadorFalso programador;

    setUp(() {
      cache = CacheEnMemoria();
      hayRed = true;
      programador = ProgramadorFalso();
    });

    CitasBloc crear() {
      final dio = dioFalso((opciones) async {
        if (!hayRed) {
          throw DioException.connectionError(
            requestOptions: opciones,
            reason: 'sin red',
          );
        }
        return Response<dynamic>(
          requestOptions: opciones,
          statusCode: 200,
          data: [
            citaJson('c1', '2026-10-01'),
            citaJson('c2', '2026-09-01', estado: 'ATENDIDA'),
          ],
        );
      });

      return CitasBloc(
        citas: CitasService(dio, cache),
        portal: PortalFalso(),
        recordatorios: programador,
        reloj: reloj,
      );
    }

    // Estas pruebas esperan el estado final y no un tiempo fijo: con los
    // archivos de prueba en paralelo, unos milisegundos a veces no alcanzaban.
    test(
      'con red: trae, guarda la copia y reprograma los recordatorios',
      () async {
        final bloc = crear()..add(const CitasSolicitadas('u1'));
        final s = await bloc.stream.firstWhere(
          (s) => s.carga == CargaCitas.lista,
        );

        expect(s.citas, hasLength(2));
        expect(s.desdeCache, isFalse);
        expect(programador.programados.single, hasLength(2));
        expect(await cache.leer('citas:u1'), isNotNull);

        await bloc.close();
      },
    );

    test('sin red: enseña lo guardado y lo dice', () async {
      final primero = crear()..add(const CitasSolicitadas('u1'));
      await primero.stream.firstWhere((s) => s.carga == CargaCitas.lista);
      await primero.close();

      hayRed = false;
      final bloc = crear()..add(const CitasSolicitadas('u1'));
      final s = await bloc.stream.firstWhere(
        (s) => s.carga == CargaCitas.lista,
      );

      expect(s.desdeCache, isTrue);
      expect(s.citas.map((c) => c.id), ['c1', 'c2']);
      expect(s.citas.first.inicio, DateTime(2026, 10, 1, 9));
      expect(
        programador.programados,
        hasLength(1),
        reason: 'sin sincronizar no se reprograma nada',
      );

      await bloc.close();
    });

    test('sin red y sin copia: error, con su mensaje', () async {
      hayRed = false;
      final bloc = crear()..add(const CitasSolicitadas('u1'));
      final s = await bloc.stream.firstWhere(
        (s) => s.carga == CargaCitas.error,
      );

      expect(s.error, contains('Sin conexión'));

      await bloc.close();
    });

    blocTest<CitasBloc, CitasState>(
      'al cerrar sesión se vacía',
      build: crear,
      act: (bloc) async {
        bloc.add(const CitasSolicitadas('u1'));
        await bloc.stream.firstWhere((s) => s.carga == CargaCitas.lista);
        bloc.add(const CitasVaciadas());
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) => expect(bloc.state, const CitasState()),
    );
  });

  group('Cancelar', () {
    final cita = Cita(
      id: 'c1',
      inicio: DateTime(2026, 10, 1, 9),
      fin: DateTime(2026, 10, 1, 9, 30),
      tipo: TipoCita.presencial,
      estado: EstadoCita.programada,
      doctorId: 'doc',
    );

    test('manda el motivo, marca la cita y avisa', () async {
      final bloc = CitasBloc(
        citas: CitasService(
          dioFalso(
            (o) async => Response(requestOptions: o, statusCode: 200, data: []),
          ),
          CacheEnMemoria(),
        ),
        portal: PortalFalso(),
        recordatorios: ProgramadorFalso(),
        reloj: reloj,
      )..emit(CitasState(carga: CargaCitas.lista, citas: [cita]));

      bloc.add(
        CitaCancelacionSolicitada(cita: cita, motivo: 'Emergencia médica'),
      );
      final s = await bloc.stream.firstWhere((s) => s.accion != null);

      expect(s.accion?.exito, isTrue);
      expect(s.cancelandoId, isNull);

      await bloc.close();
    });
  });
}
