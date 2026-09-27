// test/consultas_servicio_test.dart

import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/consultas/data/consultas_service.dart';
import 'package:app_cliniq/features/consultas/data/models/campo_formulario.dart';
import 'package:app_cliniq/features/consultas/data/models/consulta.dart';
import 'package:app_cliniq/features/consultas/data/models/opciones_consulta.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/consultas.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';

/// Las rutas del paciente de `/portal/consultas`, con los nombres de campo
/// del contrato.
void main() {
  late DioGrabador api;
  late CacheEnMemoria cache;
  late ConsultasService servicio;

  setUp(() {
    api = DioGrabador();
    cache = CacheEnMemoria();
    servicio = ConsultasService(api.dio, cache);
  });

  group('Leer lo que manda la API', () {
    test('una consulta entera, con sus instantes en UTC', () {
      final detalle = ConsultaDetalle.desdeJson(
        consultaJson(
          estado: 'RESPONDIDA',
          puedeEscribir: true,
          ultimoEsMedico: true,
          respuestas: [
            {
              'clave': 'pica',
              'etiqueta': '¿Pica?',
              'tipo': 'siNo',
              'valor': true,
            },
            {
              'clave': 'tamano',
              'etiqueta': 'Tamaño',
              'tipo': 'numero',
              'valor': 2.5,
            },
            {
              'clave': 'desde',
              'etiqueta': 'Desde',
              'tipo': 'fecha',
              'valor': '2026-09-21',
            },
            {'clave': 'forma', 'etiqueta': 'Forma', 'tipo': 'texto'},
          ],
          adjuntos: [archivoJson('a1')],
          mensajes: [mensajeJson('m1', adjunto: archivoJson('a2'))],
          campos: camposLesion,
          requiereAdjunto: true,
        ),
      );

      expect(detalle.id, 'c1');
      expect(detalle.codigo, 'CA-000123');
      expect(detalle.estado, EstadoConsulta.respondida);
      expect(detalle.enviadaEn, DateTime.utc(2026, 9, 28, 14));
      expect(detalle.venceEn, DateTime.utc(2026, 9, 30, 14));
      expect(detalle.horasRestantes, isNull);
      expect(detalle.puedeEscribir, isTrue);
      expect(detalle.respuestaPorLeer, isTrue);
      expect(detalle.medicoVisible, 'Luis Mora');
      expect(detalle.respuestas.map((r) => r.valor), [
        true,
        2.5,
        '2026-09-21',
        null,
      ]);
      expect(detalle.respuestas.first.tipo, TipoCampo.siNo);
      expect(detalle.adjuntos.single.id, 'a1');
      expect(detalle.mensajes.single.esMedico, isTrue);
      expect(detalle.mensajes.single.adjunto?.id, 'a2');
      expect(detalle.mensajes.single.fecha, DateTime.utc(2026, 9, 28, 16));
      expect(detalle.campos, hasLength(camposLesion.length));
      expect(detalle.campos![3].unidad, 'cm');
      expect(detalle.campos![1].opciones, ['Cara', 'Brazos', 'Piernas']);
      expect(detalle.requiereAdjunto, isTrue);
    });

    test('sin requiereAdjunto, el envío no exige archivo', () {
      final json = consultaJson()..remove('requiereAdjunto');
      expect(ConsultaDetalle.desdeJson(json).requiereAdjunto, isFalse);
    });

    test('la copia guardada se vuelve a leer igual', () {
      final original = ConsultaDetalle.desdeJson(
        consultaJson(
          adjuntos: [archivoJson('a1')],
          mensajes: [mensajeJson('m1')],
          campos: camposLesion,
          requiereAdjunto: true,
          respuestas: [
            {
              'clave': 'zona',
              'etiqueta': 'Zona',
              'tipo': 'seleccion',
              'valor': 'Cara',
            },
          ],
        ),
      );

      expect(ConsultaDetalle.desdeJson(original.aJson()), original);
      expect(
        ConsultaResumen.desdeJson(original.resumen.aJson()),
        original.resumen,
      );
    });

    test('un estado desconocido no ofrece acciones', () {
      final c = ConsultaResumen.desdeJson({'_id': 'x', 'estado': 'NUEVO'});
      expect(c.estado, EstadoConsulta.cerrada);
      expect(c.estado.terminada, isTrue);
    });

    test('las opciones descartan especialidades sin médicos o sin motivos '
        'activos', () {
      final datos = {
        'especialidades': <Object?>[
          ...(opcionesJson()['especialidades'] as List),
          {
            'nombre': 'Sin médicos',
            'motivos': [
              {'_id': 'x', 'nombre': 'X', 'activo': true},
            ],
            'medicos': [],
          },
          {
            'nombre': 'Motivos apagados',
            'motivos': [
              {'_id': 'y', 'nombre': 'Y', 'activo': false},
            ],
            'medicos': [
              {'uid': 'd', 'nombre': 'D'},
            ],
          },
        ],
      };

      final especialidades = interpretarOpciones(datos);

      expect(especialidades.map((e) => e.nombre), [
        'Dermatología',
        'Pediatría',
      ]);
      // Ordenados por `orden`: el «Otro motivo» (99) va al final.
      expect(especialidades.first.motivosOrdenados.map((m) => m.id), [
        'm-lesion',
        'm-otro',
      ]);
      expect(
        especialidades.first.motivosOrdenados.first.requiereAdjunto,
        isTrue,
      );
    });
  });

  group('Leer del servidor', () {
    test('GET /portal/consultas/opciones', () async {
      api.rutas['GET /portal/consultas/opciones'] = (_) => opcionesJson();

      final especialidades = await servicio.opciones();

      expect(api.claves, ['GET /portal/consultas/opciones']);
      expect(especialidades, hasLength(2));
      expect(especialidades.first.medicos.single, isA<MedicoConsulta>());
    });

    test('GET /portal/consultas: la lista, guardada en el teléfono', () async {
      api.rutas['GET /portal/consultas'] = (_) => [
        consultaJson(id: 'c1'),
        consultaJson(id: 'c2', estado: 'BORRADOR'),
        {'sin': 'id'},
      ];

      final resultado = await servicio.listar('u1');

      expect(api.pedidos.single.queryParameters, isEmpty);
      expect(resultado.consultas.map((c) => c.id), ['c1', 'c2']);
      expect(resultado.desdeCache, isFalse);
      expect(cache.valores.keys, contains('consultas:u1'));
    });

    test('con ?estado= filtra y no pisa la copia', () async {
      api.rutas['GET /portal/consultas'] = (_) => [consultaJson()];

      await servicio.listar('u1', estado: 'ENVIADA');

      expect(api.pedidos.single.queryParameters, {'estado': 'ENVIADA'});
      expect(cache.valores, isEmpty);
    });

    test('sin red, la lista guardada; sin copia, el error', () async {
      api.rutas['GET /portal/consultas'] = (_) => [consultaJson()];
      await servicio.listar('u1');

      api.rutas['GET /portal/consultas'] = (_) => throw errorDeRed();
      final guardada = await servicio.listar('u1');

      expect(guardada.desdeCache, isTrue);
      expect(guardada.guardadasEn, isNotNull);
      expect(guardada.consultas.single.id, 'c1');

      expect(() => servicio.listar('otra'), throwsA(isA<DioException>()));
    });

    test('un error del servidor no se esconde detrás de la copia', () async {
      api.rutas['GET /portal/consultas'] = (_) => [consultaJson()];
      await servicio.listar('u1');

      api.rutas['GET /portal/consultas'] = (_) => throw errorHttp(500);

      expect(() => servicio.listar('u1'), throwsA(isA<DioException>()));
    });

    test(
      'GET /portal/consultas/:id, con su copia para abrir sin red',
      () async {
        api.rutas['GET /portal/consultas/c1'] = (_) =>
            consultaJson(estado: 'RESPONDIDA', mensajes: [mensajeJson('m1')]);

        final enLinea = await servicio.detalle('u1', 'c1');
        expect(enLinea.desdeCache, isFalse);
        expect(enLinea.detalle.mensajes, hasLength(1));

        api.rutas['GET /portal/consultas/c1'] = (_) => throw errorDeRed();
        final guardada = await servicio.detalle('u1', 'c1');

        expect(guardada.desdeCache, isTrue);
        expect(guardada.detalle, enLinea.detalle);
      },
    );
  });

  group('Borrador', () {
    test('POST /portal/consultas con los campos del contrato', () async {
      api.rutas['POST /portal/consultas'] = (_) =>
          consultaJson(id: 'c-nueva', estado: 'BORRADOR');

      final borrador = await servicio.crear(
        const NuevaConsulta(
          motivoId: 'm-lesion',
          medicoId: 'doc1',
          pacienteId: 'dep1',
          respuestas: {'pica': true, 'tamano': 2, 'desde': '2026-09-21'},
          descripcion: '  Manchas rojas  ',
        ),
      );

      expect(borrador.estado, EstadoConsulta.borrador);
      expect(api.pedidos.single.data, {
        'motivoId': 'm-lesion',
        'medicoId': 'doc1',
        'pacienteId': 'dep1',
        'respuestas': {'pica': true, 'tamano': 2, 'desde': '2026-09-21'},
        'descripcion': 'Manchas rojas',
      });
    });

    test('para el titular no se manda pacienteId', () {
      final json = const NuevaConsulta(
        motivoId: 'm',
        medicoId: 'd',
        respuestas: {},
        descripcion: 'x',
      ).aJson();

      expect(json.containsKey('pacienteId'), isFalse);
    });

    test('PATCH /portal/consultas/:id solo con lo que cambia', () async {
      api.rutas['PATCH /portal/consultas/c1'] = (_) =>
          consultaJson(estado: 'BORRADOR');

      await servicio.actualizar('c1', descripcion: ' Otra ');
      expect(api.ultimo('PATCH /portal/consultas/c1').data, {
        'descripcion': 'Otra',
      });

      await servicio.actualizar('c1', respuestas: {'pica': false});
      expect(api.ultimo('PATCH /portal/consultas/c1').data, {
        'respuestas': {'pica': false},
      });
    });

    test('POST /portal/consultas/:id/adjuntos: multipart con el campo '
        '«archivo»', () async {
      api.rutas['POST /portal/consultas/c1/adjuntos'] = (_) =>
          archivoJson('a9', nombre: 'brazo.jpg');

      final meta = await servicio.subirAdjunto('c1', fotoLocal('brazo.png'));

      final pedido = api.ultimo('POST /portal/consultas/c1/adjuntos');
      final formulario = pedido.data as FormData;

      expect(formulario.files, hasLength(1));
      expect(formulario.files.single.key, 'archivo');
      expect(formulario.fields, isEmpty);
      // El nombre sigue al contenido: era un JPG con extensión .png.
      expect(formulario.files.single.value.filename, 'brazo.jpg');
      expect(
        formulario.files.single.value.contentType.toString(),
        'image/jpeg',
      );
      expect(formulario.files.single.value.length, fotoLocal().tamano);
      expect(meta.id, 'a9');
    });

    test('DELETE del adjunto, enviar y DELETE del borrador', () async {
      api.rutas['DELETE /portal/consultas/c1/adjuntos/a1'] = (_) => null;
      api.rutas['POST /portal/consultas/c1/enviar'] = (_) => consultaJson();
      api.rutas['DELETE /portal/consultas/c1'] = (_) => null;

      await servicio.quitarAdjunto('c1', 'a1');
      final enviada = await servicio.enviar('c1');
      await servicio.eliminar('c1');

      expect(api.claves, [
        'DELETE /portal/consultas/c1/adjuntos/a1',
        'POST /portal/consultas/c1/enviar',
        'DELETE /portal/consultas/c1',
      ]);
      expect(api.pedidos[1].data, isNull);
      expect(enviada.estado, EstadoConsulta.enviada);
    });
  });

  group('Después de enviar', () {
    test('POST /portal/consultas/:id/cancelar con { motivo }', () async {
      api.rutas['POST /portal/consultas/c1/cancelar'] = (_) =>
          consultaJson(estado: 'CANCELADA');

      final cancelada = await servicio.cancelar('c1', ' Ya estoy mejor ');

      expect(api.pedidos.single.data, {'motivo': 'Ya estoy mejor'});
      expect(cancelada.estado, EstadoConsulta.cancelada);
    });

    test(
      'POST /portal/consultas/:id/mensajes con { texto, adjuntoId }',
      () async {
        api.rutas['POST /portal/consultas/c1/mensajes'] = (_) =>
            consultaJson(estado: 'RESPONDIDA', puedeEscribir: true);

        await servicio.escribir('c1', ' Gracias, doctor ', adjuntoId: 'a3');
        expect(api.ultimo('POST /portal/consultas/c1/mensajes').data, {
          'texto': 'Gracias, doctor',
          'adjuntoId': 'a3',
        });

        await servicio.escribir('c1', 'Sin archivo');
        expect(api.ultimo('POST /portal/consultas/c1/mensajes').data, {
          'texto': 'Sin archivo',
        });
      },
    );
  });
}
