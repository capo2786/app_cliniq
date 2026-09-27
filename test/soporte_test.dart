// test/soporte_test.dart

import 'package:app_cliniq/core/archivos/selector_de_archivos.dart';
import 'package:app_cliniq/core/catalogos/catalogo_service.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/soporte/data/models/ticket.dart';
import 'package:app_cliniq/features/soporte/data/soporte_service.dart';
import 'package:app_cliniq/features/soporte/dominio/reglas_soporte.dart';
import 'package:app_cliniq/features/soporte/providers/nuevo_ticket_cubit.dart';
import 'package:app_cliniq/features/soporte/providers/soporte_cubit.dart';
import 'package:app_cliniq/features/soporte/providers/ticket_cubit.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/soporte.dart';

/// Soporte: la lectura de los tickets, las reglas del servidor, la copia
/// sin red y los cubits de la lista, del ticket nuevo y de la conversación.
void main() {
  final reglas = configDePrueba().archivos;

  group('La lectura', () {
    test('un ticket de la lista: su resumen y «Soporte respondió»', () {
      final ticket = Ticket.desdeJson(resumenTicketJson());

      expect(ticket.estado, EstadoTicket.enProceso);
      expect(ticket.categoria, 'TECNICO');
      expect(ticket.mensajes, isNull);
      expect(ticket.totalMensajes, 2);
      expect(ticket.respondioSoporte, isTrue);
      // Instantes reales, en UTC.
      expect(ticket.venceEn, DateTime.utc(2026, 9, 30, 15, 19, 10, 437));
      expect(
        ticket.ultimaActividad,
        DateTime.utc(2026, 9, 27, 15, 20, 13, 785),
      );
    });

    test('un ticket entero, con la conversación y el adjunto por id', () {
      final ticket = Ticket.desdeJson(ticketJson());

      expect(ticket.mensajes, hasLength(2));
      expect(ticket.mensajes!.first.adjuntoId, 'arch1');
      expect(ticket.mensajes!.first.esSoporte, isFalse);
      expect(ticket.respondioSoporte, isTrue);
      expect(ticket.totalMensajes, 2);
    });

    test('los estados: qué se puede hacer en cada uno', () {
      expect(EstadoTicket.abierto.admiteMensajes, isTrue);
      expect(EstadoTicket.resuelto.admiteMensajes, isTrue);
      expect(EstadoTicket.resuelto.atendido, isTrue);
      expect(EstadoTicket.cerrado.admiteMensajes, isFalse);
      // Uno desconocido, como cerrado: no ofrece lo que se rechazaría.
      expect(EstadoTicket.desdeCodigo('ARCHIVADO'), EstadoTicket.cerrado);
    });

    test('sin identificador no hay ticket; en la lista se salta', () {
      expect(() => Ticket.desdeJson({'asunto': 'x'}), throwsFormatException);
      expect(
        interpretarTickets([
          resumenTicketJson(),
          {'asunto': 'x'},
          'basura',
        ]),
        hasLength(1),
      );
    });
  });

  group('Las reglas', () {
    test('el asunto, entre 3 y 150 caracteres', () {
      expect(errorDelAsunto('  '), 'Escribe un asunto.');
      expect(errorDelAsunto('ab'), isNotNull);
      expect(errorDelAsunto('abc'), isNull);
      expect(errorDelAsunto('a' * 150), isNull);
      expect(errorDelAsunto('a' * 151), isNotNull);
    });

    test('la descripción, entre 10 y 5000; se mide como el servidor', () {
      expect(errorDeLaDescripcion(''), 'Cuéntanos qué pasa.');
      expect(errorDeLaDescripcion('corta'), isNotNull);
      expect(errorDeLaDescripcion('0123456789'), isNull);
      expect(errorDeLaDescripcion('a' * 5001), isNotNull);
      // 2600 emojis son 5200 unidades para el servidor.
      expect(errorDeLaDescripcion('🙂' * 2600), isNotNull);
    });

    test('un mensaje sin texto solo vale con un archivo', () {
      expect(errorDelMensaje(' ', conAdjunto: false), 'Escribe tu mensaje.');
      expect(errorDelMensaje(' ', conAdjunto: true), isNull);
      expect(errorDelMensaje('a' * 5001, conAdjunto: false), isNotNull);
    });

    test('las severidades: las activas del catálogo, en su orden', () {
      final catalogo = catalogosDePrueba().items(Catalogos.severidadTicket);
      expect(severidadesOfrecidas(catalogo), [
        'CRITICA',
        'ALTA',
        'MEDIA',
        'BAJA',
      ]);

      final sinMedia = [
        for (final i in catalogo)
          if (i.codigo != 'MEDIA') i,
        const ItemCatalogo(codigo: 'INVENTADA', nombre: 'Inventada'),
      ];
      expect(severidadesOfrecidas(sinMedia), ['CRITICA', 'ALTA', 'BAJA']);
      expect(severidadInicial(severidadesOfrecidas(sinMedia)), 'CRITICA');

      // Catálogo vacío: todas las del sistema, como el panel.
      expect(severidadesOfrecidas(const []), severidadesDelSistema);
      expect(severidadInicial(severidadesDelSistema), 'MEDIA');
    });

    test('la categoría inicial: la marcada por defecto o la primera', () {
      const citas = ItemCatalogo(codigo: 'CITAS', nombre: 'Citas');
      const otro = ItemCatalogo(
        codigo: 'OTRO',
        nombre: 'Otro',
        esPorDefecto: true,
      );

      expect(categoriaInicial(const [citas, otro]), 'OTRO');
      expect(categoriaInicial(const [citas]), 'CITAS');
      expect(categoriaInicial(const []), isEmpty);
    });

    test('los abiertos primero y, dentro, lo más reciente arriba', () {
      final tickets = interpretarTickets([
        resumenTicketJson(
          id: 'viejo',
          estado: 'ABIERTO',
          ultimoMensajeEn: '2026-09-01T10:00:00.000Z',
        ),
        resumenTicketJson(
          id: 'resuelto',
          estado: 'RESUELTO',
          ultimoMensajeEn: '2026-09-27T10:00:00.000Z',
        ),
        resumenTicketJson(
          id: 'nuevo',
          estado: 'EN_PROCESO',
          ultimoMensajeEn: '2026-09-20T10:00:00.000Z',
        ),
      ]);

      expect(ordenarTickets(tickets).map((t) => t.id), [
        'nuevo',
        'viejo',
        'resuelto',
      ]);
    });
  });

  group('El servicio', () {
    late CacheLocal cache;
    late bool hayRed;
    late DioGrabador api;
    late Map<String, dynamic> respuestaMensaje;

    setUp(() {
      cache = CacheEnMemoria();
      hayRed = true;
      respuestaMensaje = ticketJson();
      api = DioGrabador({
        'GET /soporte/tickets': (_) {
          if (!hayRed) throw errorDeRed();
          return [resumenTicketJson()];
        },
        'GET /soporte/tickets/t1': (_) {
          if (!hayRed) throw errorDeRed();
          return ticketJson();
        },
        'POST /soporte/tickets': (pedido) => {
          ...ticketJson(id: 't2', estado: 'ABIERTO', mensajes: const []),
          ...(pedido.data as Map).cast<String, dynamic>(),
        },
        'POST /soporte/tickets/t1/adjuntos': (_) => {
          '_id': 'arch9',
          'nombre': 'captura.png',
          'mime': 'image/png',
          'tamano': 40,
        },
        'POST /soporte/tickets/t1/mensajes': (_) => respuestaMensaje,
      });
    });

    SoporteService servicio() => SoporteService(api.dio, cache);

    test('mis tickets, con copia para leerlos sin red', () async {
      final lista = await servicio().listar('u1');
      expect(lista.tickets.single.asunto, 'No carga el calendario');

      hayRed = false;
      final sinRed = await servicio().listar('u1');
      expect(sinRed.desdeCache, isTrue);
      expect(sinRed.tickets, hasLength(1));
    });

    test('un ticket entero, con copia; sin copia, el error', () async {
      await servicio().detalle('u1', 't1');
      hayRed = false;

      final sinRed = await servicio().detalle('u1', 't1');
      expect(sinRed.desdeCache, isTrue);
      expect(sinRed.ticket.mensajes, hasLength(2));

      await expectLater(
        servicio().detalle('u1', 'otro'),
        throwsA(isA<DioException>()),
      );
    });

    test('la copia es de quien entró: se borra al cerrar sesión', () async {
      await servicio().listar('u1');
      await cache.vaciarDatosPersonales();

      expect(await servicio().ticketsGuardados('u1'), isNull);
    });

    test(
      'abrir un ticket manda los campos del panel, sin espacios de más',
      () async {
        await servicio().crear(
          const NuevoTicket(
            categoria: 'CITAS',
            severidad: 'ALTA',
            asunto: '  No puedo reprogramar  ',
            descripcion: '  Me sale un error al elegir la hora.  ',
          ),
        );

        expect(api.ultimo('POST /soporte/tickets').data, {
          'categoria': 'CITAS',
          'severidad': 'ALTA',
          'asunto': 'No puedo reprogramar',
          'descripcion': 'Me sale un error al elegir la hora.',
        });
      },
    );

    test(
      'el archivo sube por multipart al ticket, en el campo «archivo»',
      () async {
        final meta = await servicio().subirAdjunto('t1', capturaPng());

        expect(meta.id, 'arch9');
        final pedido = api.ultimo('POST /soporte/tickets/t1/adjuntos');
        final formulario = pedido.data as FormData;
        expect(formulario.files.single.key, 'archivo');
        expect(formulario.files.single.value.filename, 'captura.png');
      },
    );

    test(
      'responder manda {texto, adjuntoId} y devuelve el ticket al día',
      () async {
        final ticket = await servicio().responder(
          'u1',
          't1',
          '  Ya lo probé  ',
          adjuntoId: 'arch9',
        );

        expect(api.ultimo('POST /soporte/tickets/t1/mensajes').data, {
          'texto': 'Ya lo probé',
          'adjuntoId': 'arch9',
        });
        expect(ticket.mensajes, hasLength(2));

        // Queda guardado para abrirlo sin red.
        expect(await servicio().ticketGuardado('u1', 't1'), isNotNull);
      },
    );

    test(
      'si la respuesta no trae la conversación, se vuelve a pedir',
      () async {
        respuestaMensaje = {'_id': 'm3', 'texto': 'Ya lo probé'};

        final ticket = await servicio().responder('u1', 't1', 'Ya lo probé');

        expect(api.claves.last, 'GET /soporte/tickets/t1');
        expect(ticket.mensajes, hasLength(2));
      },
    );
  });

  group('La lista', () {
    test('abre con la copia y la pone al día; un ticket nuevo se suma '
        'arriba', () async {
      final cache = CacheEnMemoria();
      final api = DioGrabador({
        'GET /soporte/tickets': (_) => [
          resumenTicketJson(asunto: 'Del servidor'),
        ],
      });
      await SoporteService(api.dio, cache).listar('u1');

      final cubit = SoporteCubit(
        servicio: SoporteService(api.dio, cache),
        uid: 'u1',
      );
      addTearDown(cubit.close);

      final estados = <SoporteState>[];
      final escucha = cubit.stream.listen(estados.add);
      addTearDown(escucha.cancel);

      await cubit.cargar();

      expect(estados.first.desdeCache, isTrue);
      expect(cubit.state.carga, CargaTickets.lista);
      expect(cubit.state.desdeCache, isFalse);

      cubit.recordar(
        Ticket.desdeJson(
          ticketJson(
            id: 't9',
            estado: 'ABIERTO',
            creadoEn: '2026-09-28T10:00:00Z',
            mensajes: const [],
          ),
        ),
      );
      expect(cubit.state.tickets.first.id, 't9');
      expect(cubit.state.tickets, hasLength(2));
    });

    test('sin red y sin copia: el error, sin tickets', () async {
      final cubit = SoporteCubit(
        servicio: SoporteService(
          DioGrabador({'GET /soporte/tickets': (_) => throw errorDeRed()}).dio,
          CacheEnMemoria(),
        ),
        uid: 'u1',
      );
      addTearDown(cubit.close);

      await cubit.cargar();

      expect(cubit.state.carga, CargaTickets.error);
      expect(cubit.state.error, contains('Sin conexión'));
    });
  });

  group('El ticket nuevo', () {
    late DioGrabador api;
    late bool fallaElArchivo;

    setUp(() {
      fallaElArchivo = false;
      api = DioGrabador({
        'POST /soporte/tickets': (_) =>
            ticketJson(id: 't1', estado: 'ABIERTO', mensajes: const []),
        'POST /soporte/tickets/t1/adjuntos': (_) {
          if (fallaElArchivo) throw errorHttp(422, 'El archivo no es seguro.');
          return {
            '_id': 'arch9',
            'nombre': 'captura.png',
            'mime': 'image/png',
            'tamano': 40,
          };
        },
        'POST /soporte/tickets/t1/mensajes': (_) => ticketJson(
          id: 't1',
          estado: 'ABIERTO',
          mensajes: [
            mensajeTicketJson(
              'm1',
              esSoporte: false,
              texto: 'Adjunto: captura.png',
              adjuntoId: 'arch9',
            ),
          ],
        ),
      });
    });

    NuevoTicketCubit crear({String categoria = 'TECNICO'}) {
      final cubit = NuevoTicketCubit(
        servicio: SoporteService(api.dio, CacheEnMemoria()),
        uid: 'u1',
        archivos: reglas,
        categoria: categoria,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('con datos que el servidor rechazaría, no se manda nada', () async {
      final cubit = crear(categoria: '');

      await cubit.enviar(asunto: 'ab', descripcion: 'corta');

      expect(cubit.state.errorCategoria, isNotNull);
      expect(cubit.state.errorAsunto, isNotNull);
      expect(cubit.state.errorDescripcion, isNotNull);
      expect(api.pedidos, isEmpty);

      cubit.elegirCategoria('CITAS');
      expect(cubit.state.errorCategoria, isNull);
      expect(cubit.state.errorAsunto, isNotNull);
    });

    test('sin archivo: se crea con la severidad elegida y termina', () async {
      final cubit = crear()..elegirSeveridad('ALTA');

      await cubit.enviar(
        asunto: 'No carga el calendario',
        descripcion: 'La pantalla queda en blanco al abrirla.',
      );

      expect(cubit.state.creado?.id, 't1');
      expect(api.ultimo('POST /soporte/tickets').data['severidad'], 'ALTA');
      expect(api.claves, ['POST /soporte/tickets']);
    });

    test(
      'con archivo: se crea, sube y va en un mensaje «Adjunto: …»',
      () async {
        final cubit = crear()
          ..elegirAdjunto(SeleccionDeArchivos(archivos: [capturaPng()]));

        await cubit.enviar(
          asunto: 'No carga el calendario',
          descripcion: 'La pantalla queda en blanco al abrirla.',
        );

        expect(api.claves, [
          'POST /soporte/tickets',
          'POST /soporte/tickets/t1/adjuntos',
          'POST /soporte/tickets/t1/mensajes',
        ]);
        expect(api.ultimo('POST /soporte/tickets/t1/mensajes').data, {
          'texto': 'Adjunto: captura.png',
          'adjuntoId': 'arch9',
        });
        expect(cubit.state.creado!.mensajes, hasLength(1));
        expect(cubit.state.problemaDelAdjunto, isNull);
      },
    );

    test(
      'si el archivo falla, el ticket ya existe: termina y lo dice',
      () async {
        fallaElArchivo = true;
        final cubit = crear()
          ..elegirAdjunto(SeleccionDeArchivos(archivos: [capturaPng()]));

        await cubit.enviar(
          asunto: 'No carga el calendario',
          descripcion: 'La pantalla queda en blanco al abrirla.',
        );

        expect(cubit.state.creado?.id, 't1');
        expect(
          cubit.state.problemaDelAdjunto,
          contains('El archivo no es seguro.'),
        );
      },
    );

    test(
      'si el servidor rechaza el ticket, se avisa y se puede reintentar',
      () async {
        api.rutas['POST /soporte/tickets'] = (_) =>
            throw errorHttp(400, 'La categoría debe ser CITAS, PAGOS.');
        final cubit = crear();

        await cubit.enviar(
          asunto: 'No carga el calendario',
          descripcion: 'La pantalla queda en blanco al abrirla.',
        );

        expect(cubit.state.creado, isNull);
        expect(cubit.state.enviando, isFalse);
        expect(
          cubit.state.aviso!.mensaje,
          'La categoría debe ser CITAS, PAGOS.',
        );
      },
    );

    test(
      'el archivo se valida con las reglas de la clínica antes de subir',
      () {
        final cubit = crear()
          ..elegirAdjunto(SeleccionDeArchivos(archivos: [videoMp4()]));

        expect(cubit.state.adjunto, isNull);
        expect(
          cubit.state.aviso!.mensaje,
          contains('no es un PDF, JPG ni PNG'),
        );

        cubit.elegirAdjunto(
          SeleccionDeArchivos(
            archivos: [capturaPng('a.png'), capturaPng('b.png')],
          ),
        );
        expect(cubit.state.adjunto!.nombre, 'a.png');
        expect(cubit.state.aviso!.mensaje, contains('un solo archivo'));
      },
    );
  });

  group('La conversación', () {
    late CacheLocal cache;
    late DioGrabador api;
    late int subidas;
    late bool fallaElMensaje;

    setUp(() {
      cache = CacheEnMemoria();
      subidas = 0;
      fallaElMensaje = false;
      api = DioGrabador({
        'GET /soporte/tickets/t1': (_) => ticketJson(),
        'POST /soporte/tickets/t1/adjuntos': (_) {
          subidas++;
          return {'_id': 'arch9', 'nombre': 'captura.png', 'mime': 'image/png'};
        },
        'POST /soporte/tickets/t1/mensajes': (pedido) {
          if (fallaElMensaje) throw errorDeRed();
          final cuerpo = pedido.data as Map;
          return ticketJson(
            mensajes: [
              ...ticketJson()['mensajes'] as List<Map<String, dynamic>>,
              mensajeTicketJson(
                'm3',
                esSoporte: false,
                texto: cuerpo['texto'] as String,
                adjuntoId: cuerpo['adjuntoId'] as String?,
              ),
            ],
          );
        },
      });
    });

    TicketCubit crear({Ticket? inicial}) {
      final cubit = TicketCubit(
        servicio: SoporteService(api.dio, cache),
        uid: 'u1',
        id: 't1',
        archivos: reglas,
        inicial: inicial,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('abre con el resumen de la lista y trae la conversación', () async {
      final cubit = crear(inicial: Ticket.desdeJson(resumenTicketJson()));
      expect(cubit.state.ticket!.mensajes, isNull);

      await cubit.cargar();

      expect(cubit.state.carga, CargaTicket.lista);
      expect(cubit.state.ticket!.mensajes, hasLength(2));
    });

    test('escribir: el mensaje se suma y el campo se vacía', () async {
      final cubit = crear();
      await cubit.cargar();

      await cubit.enviar('  Ya borré la caché  ');

      expect(cubit.state.ticket!.mensajes!.last.texto, 'Ya borré la caché');
      expect(cubit.state.enviados, 1);
      expect(cubit.state.errorEnvio, isNull);
    });

    test(
      'sin texto no se manda; con solo un archivo va «Adjunto: …»',
      () async {
        final cubit = crear();
        await cubit.cargar();

        await cubit.enviar('   ');
        expect(cubit.state.errorEnvio, 'Escribe tu mensaje.');

        cubit.elegirAdjunto(SeleccionDeArchivos(archivos: [capturaPng()]));
        await cubit.enviar('');

        expect(api.ultimo('POST /soporte/tickets/t1/mensajes').data, {
          'texto': 'Adjunto: captura.png',
          'adjuntoId': 'arch9',
        });
        expect(cubit.state.adjunto, isNull);
      },
    );

    test(
      'si el mensaje falla, el reintento no vuelve a subir el archivo',
      () async {
        final cubit = crear();
        await cubit.cargar();
        cubit.elegirAdjunto(SeleccionDeArchivos(archivos: [capturaPng()]));

        fallaElMensaje = true;
        await cubit.enviar('Mira la captura');
        expect(cubit.state.errorEnvio, contains('Sin conexión'));
        expect(cubit.state.adjuntoSubido?.id, 'arch9');

        fallaElMensaje = false;
        await cubit.enviar('Mira la captura');

        expect(subidas, 1);
        expect(cubit.state.enviados, 1);
      },
    );

    test('en un ticket cerrado no se escribe', () async {
      api.rutas['GET /soporte/tickets/t1'] = (_) =>
          ticketJson(estado: 'CERRADO');
      final cubit = crear();
      await cubit.cargar();

      expect(cubit.state.puedeEscribir, isFalse);
      await cubit.enviar('Hola');
      expect(api.claves, isNot(contains('POST /soporte/tickets/t1/mensajes')));
    });

    test('sin red: la copia guardada; sin copia, el error', () async {
      final conCopia = crear();
      await conCopia.cargar();

      api.rutas['GET /soporte/tickets/t1'] = (_) => throw errorDeRed();
      final sinRed = crear();
      await sinRed.cargar();
      expect(sinRed.state.desdeCache, isTrue);
      expect(sinRed.state.ticket!.mensajes, hasLength(2));

      cache = CacheEnMemoria();
      final sinNada = crear();
      await sinNada.cargar();
      expect(sinNada.state.carga, CargaTicket.error);
      expect(sinNada.state.error, contains('Sin conexión'));
    });
  });
}
