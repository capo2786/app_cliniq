// test/turnos_portal_test.dart

import 'package:app_cliniq/core/network/errores.dart';
import 'package:app_cliniq/features/agendar/data/models/medico_portal.dart';
import 'package:app_cliniq/features/agendar/data/models/turnos.dart';
import 'package:app_cliniq/features/agendar/data/portal_service.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';

/// Las rutas de turnos del portal, con las formas del contrato: qué se
/// pide y cómo se lee lo que vuelve. Las fechas llegan en hora local de la
/// clínica sin zona y se leen tal cual.
void main() {
  late DioGrabador api;
  late PortalService portal;

  setUp(() {
    api = DioGrabador();
    portal = PortalService(api.dio);
  });

  Map<String, dynamic> medicoJson(
    String uid, {
    String? especialidad = 'Pediatría',
    Map<String, dynamic>? proximo,
  }) => {
    'uid': uid,
    'nombre': 'Médico $uid',
    'especialidad': ?especialidad,
    'ciudad': 'Quito',
    'modalidades': ['PRESENCIAL', 'TELEMEDICINA'],
    'horariosAtencion': [],
    'configAgenda': {'duraciones': {}, 'margenMinutos': 0, 'limiteDiario': 0},
    'bloqueos': [],
    'proximo': ?proximo,
  };

  group('GET /portal/proximos-turnos', () {
    Map<String, dynamic> respuesta() => {
      'especialidades': [
        {
          'nombre': 'Medicina Familiar',
          'medicos': 3,
          'proximo': {
            'inicio': '2026-09-28T15:30:00',
            'fin': '2026-09-28T16:00:00',
            'doctorId': 'b',
            'modalidad': 'PRESENCIAL',
          },
        },
        {'nombre': 'Pediatría', 'medicos': 1},
        {'nombre': '  ', 'medicos': 2},
        'mal',
      ],
      'medicos': [
        medicoJson(
          'b',
          proximo: {
            'inicio': '2026-09-28T15:30:00.000Z',
            'fin': '2026-09-28T16:00:00.000Z',
            'modalidad': 'presencial',
          },
        ),
        medicoJson(
          'a',
          proximo: {
            'inicio': '2026-09-29T08:00:00',
            'fin': '2026-09-29T08:20:00',
            'modalidad': 'TELEMEDICINA',
          },
        ),
        {'nombre': 'Sin identificador'},
        7,
      ],
    };

    test('sin filtros no manda ninguno', () async {
      api.rutas['GET /portal/proximos-turnos'] = (_) => respuesta();

      await portal.proximosTurnos();

      expect(api.claves, ['GET /portal/proximos-turnos']);
      expect(
        api.ultimo('GET /portal/proximos-turnos').queryParameters,
        isEmpty,
      );
    });

    test('manda la especialidad, la ciudad y la modalidad que haya', () async {
      api.rutas['GET /portal/proximos-turnos'] = (_) => respuesta();

      await portal.proximosTurnos(
        especialidad: 'Pediatría',
        ciudad: '',
        modalidad: TipoCita.telemedicina,
      );

      expect(api.ultimo('GET /portal/proximos-turnos').queryParameters, {
        'especialidad': 'Pediatría',
        'modalidad': 'TELEMEDICINA',
      });
    });

    test('lee las especialidades en su orden, con cuántos médicos y el '
        'primer turno disponible', () async {
      api.rutas['GET /portal/proximos-turnos'] = (_) => respuesta();

      final proximos = await portal.proximosTurnos();

      expect(proximos.especialidades, [
        EspecialidadDisponible(
          nombre: 'Medicina Familiar',
          medicos: 3,
          proximo: ProximoTurno(
            inicio: DateTime(2026, 9, 28, 15, 30),
            fin: DateTime(2026, 9, 28, 16),
            modalidad: TipoCita.presencial,
            doctorId: 'b',
          ),
        ),
        const EspecialidadDisponible(nombre: 'Pediatría', medicos: 1),
      ], reason: 'sin nombre o ilegible, se descarta');
    });

    test('lee los médicos como los de /portal/medicos, con su próximo turno, '
        'en el orden de la API (del más cercano al más lejano)', () async {
      api.rutas['GET /portal/proximos-turnos'] = (_) => respuesta();

      final medicos = (await portal.proximosTurnos()).medicos;

      expect(medicos.map((m) => m.uid), ['b', 'a']);
      expect(medicos.first.especialidad, 'Pediatría');
      expect(medicos.first.modalidadesOfrecidas, [
        TipoCita.presencial,
        TipoCita.telemedicina,
      ]);
      expect(
        medicos.first.proximo,
        ProximoTurno(
          inicio: DateTime(2026, 9, 28, 15, 30),
          fin: DateTime(2026, 9, 28, 16),
          modalidad: TipoCita.presencial,
        ),
        reason: 'la zona se descarta: la hora es la de la clínica',
      );
      expect(medicos.last.proximo?.modalidad, TipoCita.telemedicina);
    });

    test('una respuesta que no es de la API es un error, no una lista '
        'vacía', () async {
      api.rutas['GET /portal/proximos-turnos'] = (_) => '<html>';

      expect(portal.proximosTurnos(), throwsA(isA<FormatException>()));
    });

    test('un error del servidor llega tal cual', () async {
      api.rutas['GET /portal/proximos-turnos'] = (_) => throw errorHttp(500);

      await expectLater(
        portal.proximosTurnos(),
        throwsA(
          isA<DioException>().having(
            (e) => e.response?.statusCode,
            'estado',
            500,
          ),
        ),
      );
    });
  });

  group('GET /portal/turnos/:doctorId', () {
    Map<String, dynamic> respuesta() => {
      'doctorId': 'doc1',
      'modalidad': 'PRESENCIAL',
      'duracion': 30,
      'turnos': [
        {'inicio': '2026-09-28T09:00:00', 'fin': '2026-09-28T09:30:00'},
        {'inicio': '2026-09-28T08:00:00', 'fin': '2026-09-28T08:30:00'},
        {'inicio': '2026-09-28T08:00:00', 'fin': '2026-09-28T08:30:00'},
        {'inicio': '2026-09-28T10:00:00', 'fin': '2026-09-28T09:30:00'},
        {'inicio': '2026-02-30T08:00:00', 'fin': '2026-02-30T08:30:00'},
        {'inicio': '2026-09-28T11:00:00'},
        'mal',
      ],
    };

    test('pide la modalidad y, si se pasan, el rango y la cita que se '
        'reprograma', () async {
      api.rutas['GET /portal/turnos/doc1'] = (_) => respuesta();

      await portal.turnos('doc1', TipoCita.presencial);
      expect(api.ultimo('GET /portal/turnos/doc1').queryParameters, {
        'modalidad': 'PRESENCIAL',
      }, reason: 'sin rango, la API usa de hoy al horizonte');

      await portal.turnos(
        'doc1',
        TipoCita.telemedicina,
        desde: DateTime(2026, 9, 28, 15),
        hasta: DateTime(2026, 10, 5),
        excluirCita: 'c9',
      );
      expect(api.ultimo('GET /portal/turnos/doc1').queryParameters, {
        'modalidad': 'TELEMEDICINA',
        'desde': '2026-09-28',
        'hasta': '2026-10-05',
        'excluirCita': 'c9',
      });
    });

    test('lee la duración y los turnos en orden, sin repetidos ni '
        'ilegibles', () async {
      api.rutas['GET /portal/turnos/doc1'] = (_) => respuesta();

      final turnos = await portal.turnos('doc1', TipoCita.presencial);

      expect(turnos.doctorId, 'doc1');
      expect(turnos.modalidad, TipoCita.presencial);
      expect(turnos.duracion, 30);
      expect(turnos.turnos, [
        Turno(
          inicio: DateTime(2026, 9, 28, 8),
          fin: DateTime(2026, 9, 28, 8, 30),
        ),
        Turno(
          inicio: DateTime(2026, 9, 28, 9),
          fin: DateTime(2026, 9, 28, 9, 30),
        ),
      ]);
    });

    test('sin duración, la del primer turno; el médico y la modalidad, los '
        'pedidos', () async {
      api.rutas['GET /portal/turnos/doc1'] = (_) => {
        'doctorId': '64f0c0ffee',
        'turnos': [
          {'inicio': '2026-09-28T08:00:00', 'fin': '2026-09-28T08:20:00'},
        ],
      };

      final turnos = await portal.turnos('doc1', TipoCita.telemedicina);

      expect(turnos.doctorId, 'doc1');
      expect(turnos.modalidad, TipoCita.telemedicina);
      expect(turnos.duracion, 20);
    });

    test('sin turnos, la lista vacía', () async {
      api.rutas['GET /portal/turnos/doc1'] = (_) => {
        'doctorId': 'doc1',
        'modalidad': 'ASINCRONA',
        'duracion': 15,
        'turnos': [],
      };

      final turnos = await portal.turnos('doc1', TipoCita.asincrona);

      expect(turnos.turnos, isEmpty);
      expect(turnos.duracion, 15);
    });

    test(
      'el 404 o 409 del médico llega con el mensaje de la reserva',
      () async {
        api.rutas['GET /portal/turnos/doc1'] = (_) =>
            throw errorHttp(409, 'El médico no ofrece esa modalidad.');

        await expectLater(
          portal.turnos('doc1', TipoCita.asincrona),
          throwsA(
            isA<DioException>()
                .having((e) => e.response?.statusCode, 'estado', 409)
                .having(
                  mensajeDelServidor,
                  'mensaje',
                  'El médico no ofrece esa modalidad.',
                ),
          ),
        );
      },
    );

    test('una respuesta que no es de la API es un error', () async {
      api.rutas['GET /portal/turnos/doc1'] = (_) => <Object>[];

      expect(
        portal.turnos('doc1', TipoCita.presencial),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Modelos', () {
    test('un próximo turno con una modalidad desconocida no se lee: no se '
        'puede reservar como presencial', () {
      expect(
        ProximoTurno.desdeJson({
          'inicio': '2026-09-28T08:00:00',
          'fin': '2026-09-28T08:30:00',
          'modalidad': 'DOMICILIO',
        }),
        isNull,
      );
      expect(modalidadDeCodigo(' asincrona '), TipoCita.asincrona);
      expect(modalidadDeCodigo(null), isNull);
    });

    test('un médico de /portal/medicos, sin próximo, se sigue leyendo', () {
      final m = MedicoPortal.desdeJson(medicoJson('x', especialidad: null));

      expect(m.uid, 'x');
      expect(m.especialidad, isNull);
      expect(m.proximo, isNull);
    });
  });
}
