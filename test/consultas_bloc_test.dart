// test/consultas_bloc_test.dart

import 'package:app_cliniq/features/consultas/data/consultas_service.dart';
import 'package:app_cliniq/features/consultas/data/models/consulta.dart';
import 'package:app_cliniq/features/consultas/providers/consultas_bloc.dart';
import 'package:app_cliniq/features/consultas/providers/consultas_event.dart';
import 'package:app_cliniq/features/consultas/providers/consultas_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/consultas.dart';
import 'dobles/dobles.dart';

/// La lista de consultas en línea: lo guardado primero, la del servidor
/// después, los borradores y lo que cambia en otras pantallas.
void main() {
  late ConsultasFalso servicio;

  ConsultaResumen resumen(String id, {String estado = 'ENVIADA'}) =>
      ConsultaResumen.desdeJson(consultaJson(id: id, estado: estado));

  setUp(() => servicio = ConsultasFalso());

  blocTest<ConsultasBloc, ConsultasState>(
    'sin nada guardado: cargando y la lista del servidor',
    setUp: () => servicio.lista = [resumen('c1'), resumen('c2')],
    build: () => ConsultasBloc(servicio),
    act: (bloc) => bloc.add(const ConsultasSolicitadas('u1')),
    expect: () => [
      const ConsultasState(carga: CargaConsultas.cargando),
      ConsultasState(
        carga: CargaConsultas.lista,
        consultas: [resumen('c1'), resumen('c2')],
      ),
    ],
    verify: (_) => expect(servicio.llamadas, ['listar:u1']),
  );

  blocTest<ConsultasBloc, ConsultasState>(
    'con una copia guardada: se enseña al instante y después la nueva',
    setUp: () {
      servicio
        ..guardadas = ResultadoConsultas(
          consultas: [resumen('vieja')],
          desdeCache: true,
          guardadasEn: DateTime(2026, 9, 28, 8),
        )
        ..lista = [resumen('nueva')];
    },
    build: () => ConsultasBloc(servicio),
    act: (bloc) => bloc.add(const ConsultasSolicitadas('u1')),
    expect: () => [
      isA<ConsultasState>()
          .having((s) => s.desdeCache, 'desdeCache', isTrue)
          .having((s) => s.consultas.single.id, 'consulta', 'vieja'),
      isA<ConsultasState>().having((s) => s.cargando, 'cargando', isTrue),
      isA<ConsultasState>()
          .having((s) => s.carga, 'carga', CargaConsultas.lista)
          .having((s) => s.consultas.single.id, 'consulta', 'nueva'),
    ],
  );

  blocTest<ConsultasBloc, ConsultasState>(
    'si falla y no hay nada: el error; si había algo, se queda con aviso',
    setUp: () => servicio.errores['listar'] = [errorHttp(500), errorHttp(500)],
    build: () => ConsultasBloc(servicio),
    act: (bloc) async {
      bloc.add(const ConsultasSolicitadas('u1'));
      await bloc.stream.firstWhere((s) => s.carga == CargaConsultas.error);

      bloc
        ..add(ConsultaActualizada(resumen('c1')))
        ..add(const ConsultasSolicitadas('u1'));
    },
    skip: 3,
    expect: () => [
      isA<ConsultasState>().having((s) => s.cargando, 'cargando', isTrue),
      isA<ConsultasState>()
          .having((s) => s.carga, 'carga', CargaConsultas.lista)
          .having((s) => s.consultas, 'consultas', hasLength(1))
          .having((s) => s.error, 'error', contains('servidor')),
    ],
  );

  blocTest<ConsultasBloc, ConsultasState>(
    'una consulta nueva va arriba; una conocida se reemplaza',
    build: () => ConsultasBloc(servicio),
    seed: () =>
        ConsultasState(carga: CargaConsultas.lista, consultas: [resumen('c1')]),
    act: (bloc) => bloc
      ..add(ConsultaActualizada(resumen('c2', estado: 'BORRADOR')))
      ..add(ConsultaActualizada(resumen('c1', estado: 'RESPONDIDA'))),
    expect: () => [
      isA<ConsultasState>().having(
        (s) => s.consultas.map((c) => c.id),
        'orden',
        ['c2', 'c1'],
      ),
      isA<ConsultasState>().having(
        (s) => s.consultas.last.estado,
        'estado',
        EstadoConsulta.respondida,
      ),
    ],
  );

  blocTest<ConsultasBloc, ConsultasState>(
    'eliminar un borrador: DELETE y fuera de la lista',
    build: () => ConsultasBloc(servicio),
    seed: () => ConsultasState(
      carga: CargaConsultas.lista,
      consultas: [
        resumen('b1', estado: 'BORRADOR'),
        resumen('c1'),
      ],
    ),
    act: (bloc) =>
        bloc.add(ConsultaBorradorEliminado(resumen('b1', estado: 'BORRADOR'))),
    expect: () => [
      isA<ConsultasState>().having((s) => s.eliminandoId, 'eliminando', 'b1'),
      isA<ConsultasState>()
          .having((s) => s.eliminandoId, 'eliminando', isNull)
          .having((s) => s.consultas.map((c) => c.id), 'quedan', ['c1'])
          .having((s) => s.aviso?.exito, 'aviso', isTrue),
    ],
    verify: (_) => expect(servicio.llamadas, ['eliminar:b1']),
  );

  blocTest<ConsultasBloc, ConsultasState>(
    'una consulta enviada no se elimina desde aquí',
    build: () => ConsultasBloc(servicio),
    act: (bloc) => bloc.add(ConsultaBorradorEliminado(resumen('c1'))),
    expect: () => <ConsultasState>[],
    verify: (_) => expect(servicio.llamadas, isEmpty),
  );

  blocTest<ConsultasBloc, ConsultasState>(
    'si no se puede eliminar, se queda y se avisa',
    setUp: () => servicio.errores['eliminar'] = [errorDeRed()],
    build: () => ConsultasBloc(servicio),
    seed: () => ConsultasState(consultas: [resumen('b1', estado: 'BORRADOR')]),
    act: (bloc) =>
        bloc.add(ConsultaBorradorEliminado(resumen('b1', estado: 'BORRADOR'))),
    skip: 1,
    expect: () => [
      isA<ConsultasState>()
          .having((s) => s.consultas, 'consultas', hasLength(1))
          .having((s) => s.aviso?.exito, 'aviso', isFalse),
    ],
  );

  blocTest<ConsultasBloc, ConsultasState>(
    'un borrador borrado en otra pantalla sale; al cerrar sesión, todo',
    build: () => ConsultasBloc(servicio),
    seed: () => ConsultasState(
      carga: CargaConsultas.lista,
      consultas: [
        resumen('b1', estado: 'BORRADOR'),
        resumen('c1'),
      ],
    ),
    act: (bloc) => bloc
      ..add(const ConsultaQuitada('b1'))
      ..add(const ConsultasVaciadas()),
    expect: () => [
      ConsultasState(carga: CargaConsultas.lista, consultas: [resumen('c1')]),
      const ConsultasState(),
    ],
  );
}
