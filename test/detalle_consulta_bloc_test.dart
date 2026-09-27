// test/detalle_consulta_bloc_test.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:app_cliniq/core/archivos/archivo_local.dart';
import 'package:app_cliniq/core/archivos/selector_de_archivos.dart';
import 'package:app_cliniq/features/consultas/data/consultas_service.dart';
import 'package:app_cliniq/features/consultas/data/models/consulta.dart';
import 'package:app_cliniq/features/consultas/providers/detalle_consulta_bloc.dart';
import 'package:app_cliniq/features/consultas/providers/detalle_consulta_event.dart';
import 'package:app_cliniq/features/consultas/providers/detalle_consulta_state.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/consultas.dart';
import 'dobles/dobles.dart';
import 'dobles/clinica.dart';

/// El detalle de una consulta: cargar, el sondeo cada 30 segundos, escribir
/// con o sin archivo y cancelar.
///
/// Los latidos del sondeo los da la prueba a mano con un StreamController:
/// nada espera un reloj.
void main() {
  late ConsultasFalso servicio;
  late StreamController<void> latidos;
  late int suscripciones;

  // Se completan cuando el bloc empieza y deja de escuchar los latidos: así
  // la prueba sabe que el sondeo se encendió o se apagó sin esperar nada.
  late Completer<void> escuchando;
  late Completer<void> apagado;

  ConsultaDetalle detalle(Map<String, dynamic> json) =>
      ConsultaDetalle.desdeJson(json);

  final enviada = detalle(consultaJson());
  final respondida = detalle(
    consultaJson(
      estado: 'RESPONDIDA',
      puedeEscribir: true,
      ultimoEsMedico: true,
      mensajes: [mensajeJson('m1')],
    ),
  );

  setUp(() {
    servicio = ConsultasFalso();
    suscripciones = 0;
    escuchando = Completer<void>();
    apagado = Completer<void>();
    latidos = StreamController<void>.broadcast(
      onListen: () {
        suscripciones++;
        if (!escuchando.isCompleted) escuchando.complete();
      },
      onCancel: () {
        if (!apagado.isCompleted) apagado.complete();
      },
    );
  });

  tearDown(() => latidos.close());

  DetalleConsultaBloc crear() => DetalleConsultaBloc(
    servicio: servicio,
    uid: 'u1',
    id: 'c1',
    archivos: configDePrueba().archivos,
    latidos: () => latidos.stream,
  );

  Future<DetalleConsultaState> esperar(
    DetalleConsultaBloc bloc,
    bool Function(DetalleConsultaState s) condicion,
  ) async {
    if (condicion(bloc.state)) return bloc.state;
    return bloc.stream.firstWhere(condicion);
  }

  Future<void> abrir(DetalleConsultaBloc bloc) async {
    bloc.add(const DetalleConsultaSolicitado());
    await esperar(bloc, (s) => s.carga == CargaDetalle.lista);
  }

  group('Abrir', () {
    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'sin copia: cargando y la consulta del servidor',
      setUp: () => servicio.detalles = [enviada],
      build: crear,
      act: abrir,
      expect: () => [
        const DetalleConsultaState(carga: CargaDetalle.cargando),
        DetalleConsultaState(carga: CargaDetalle.lista, detalle: enviada),
      ],
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'con copia guardada: la copia al instante y después la del servidor',
      setUp: () {
        servicio
          ..detalleEnCache = ResultadoDetalle(
            detalle: enviada,
            desdeCache: true,
            guardadaEn: DateTime(2026, 9, 28, 10),
          )
          ..detalles = [respondida];
      },
      build: crear,
      act: abrir,
      expect: () => [
        isA<DetalleConsultaState>()
            .having((s) => s.desdeCache, 'desdeCache', isTrue)
            .having((s) => s.detalle, 'detalle', enviada),
        isA<DetalleConsultaState>().having(
          (s) => s.carga,
          'carga',
          CargaDetalle.cargando,
        ),
        isA<DetalleConsultaState>()
            .having((s) => s.desdeCache, 'desdeCache', isFalse)
            .having((s) => s.detalle, 'detalle', respondida),
      ],
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'si no se puede abrir y no hay copia: el error',
      setUp: () => servicio.errores['detalle'] = [errorHttp(404)],
      build: crear,
      act: (bloc) async {
        bloc.add(const DetalleConsultaSolicitado());
        await esperar(bloc, (s) => s.carga == CargaDetalle.error);
      },
      verify: (bloc) =>
          expect(bloc.state.error, 'No se encontró lo que buscabas.'),
    );
  });

  group('Sondeo cada 30 segundos', () {
    /// Da un latido y espera a que termine de preguntar.
    Future<void> latir(DetalleConsultaBloc bloc) async {
      latidos.add(null);
      await esperar(bloc, (s) => s.refrescando);
      await esperar(bloc, (s) => !s.refrescando);
    }

    Future<void> abrirYSondear(DetalleConsultaBloc bloc) async {
      await abrir(bloc);
      bloc.add(const DetalleConsultaSondeoCambiado(true));
      await escuchando.future;
    }

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'cada latido pregunta por la lista y, si la consulta cambió, trae el '
      'detalle con la respuesta del médico',
      setUp: () {
        servicio
          ..detalles = [enviada, respondida]
          ..lista = [respondida.resumen];
      },
      build: crear,
      act: (bloc) async {
        await abrirYSondear(bloc);

        latidos.add(null);
        await esperar(bloc, (s) => s.detalle == respondida && !s.refrescando);
        expect(bloc.sondeando, isTrue);
      },
      verify: (bloc) {
        expect(servicio.llamadas, ['detalle:c1', 'listar:u1', 'detalle:c1']);
        expect(bloc.state.aviso, isNull, reason: 'el sondeo no avisa nada');
        expect(bloc.sondeando, isFalse, reason: 'al cerrar se apaga');
        expect(latidos.hasListener, isFalse);
      },
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'si esta consulta no cambió, el latido no vuelve a pedir el detalle '
      '(cada lectura del detalle queda en la bitácora clínica)',
      setUp: () {
        servicio
          ..detalles = [enviada]
          ..lista = [
            // Otra consulta que sí cambió no cuenta.
            ConsultaResumen.desdeJson(
              consultaJson(id: 'c9', estado: 'RESPONDIDA'),
            ),
            enviada.resumen,
          ];
      },
      build: crear,
      act: (bloc) async {
        await abrirYSondear(bloc);
        await latir(bloc);
        await latir(bloc);
      },
      verify: (bloc) {
        expect(servicio.llamadas, ['detalle:c1', 'listar:u1', 'listar:u1']);
        expect(bloc.state.detalle, enviada);
      },
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'un mensaje nuevo sin cambio de estado también trae el detalle',
      setUp: () {
        final conDos = detalle(
          consultaJson(
            estado: 'RESPONDIDA',
            puedeEscribir: true,
            mensajes: [
              mensajeJson('m1'),
              mensajeJson(
                'm2',
                texto: 'Aplica la crema dos veces al día.',
                fecha: '2026-09-28T18:00:00.000Z',
              ),
            ],
          ),
        );
        servicio
          ..detalles = [respondida, conDos]
          ..lista = [conDos.resumen];
      },
      build: crear,
      act: (bloc) async {
        await abrirYSondear(bloc);
        latidos.add(null);
        await esperar(
          bloc,
          (s) => (s.detalle?.mensajes.length ?? 0) == 2 && !s.refrescando,
        );
      },
      verify: (_) =>
          expect(servicio.llamadas, ['detalle:c1', 'listar:u1', 'detalle:c1']),
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'encender dos veces no duplica el sondeo; apagado, los latidos no '
      'preguntan',
      setUp: () => servicio.detalles = [enviada],
      build: crear,
      act: (bloc) async {
        await abrir(bloc);
        bloc
          ..add(const DetalleConsultaSondeoCambiado(true))
          ..add(const DetalleConsultaSondeoCambiado(true));
        await escuchando.future;
        expect(bloc.sondeando, isTrue);

        bloc.add(const DetalleConsultaSondeoCambiado(false));
        await apagado.future;
        latidos.add(null);
      },
      verify: (bloc) {
        expect(suscripciones, 1);
        expect(latidos.hasListener, isFalse);
        expect(bloc.sondeando, isFalse);
        expect(servicio.llamadas, ['detalle:c1']);
      },
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'si la lista falla o llega la guardada (sin red), no se dice nada y '
      'se sigue con lo que había',
      setUp: () {
        servicio
          ..detalles = [enviada]
          // Aunque la copia de la lista diga otra cosa: es vieja.
          ..lista = [respondida.resumen]
          ..listaDesdeCache = true;
      },
      build: crear,
      act: (bloc) async {
        await abrirYSondear(bloc);
        await latir(bloc);

        servicio
          ..listaDesdeCache = false
          ..errores['listar'] = [errorHttp(500)];
        await latir(bloc);
      },
      verify: (bloc) {
        expect(servicio.llamadas, ['detalle:c1', 'listar:u1', 'listar:u1']);
        expect(bloc.state.detalle, enviada);
        expect(bloc.state.aviso, isNull);
        expect(bloc.state.error, isNull);
      },
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'si se ve la copia guardada, el primer latido con red trae el detalle '
      'aunque no haya cambiado',
      setUp: () {
        servicio
          ..detalleEnCache = ResultadoDetalle(
            detalle: enviada,
            desdeCache: true,
            guardadaEn: DateTime(2026, 9, 28, 10),
          )
          ..errores['detalle'] = [errorDeRed()]
          ..detalles = [enviada]
          ..lista = [enviada.resumen];
      },
      build: crear,
      act: (bloc) async {
        await abrirYSondear(bloc);
        expect(bloc.state.desdeCache, isTrue);

        latidos.add(null);
        await esperar(bloc, (s) => !s.desdeCache && !s.refrescando);
        await latir(bloc);
      },
      verify: (bloc) {
        expect(servicio.llamadas, [
          'detalle:c1',
          'listar:u1',
          'detalle:c1',
          'listar:u1',
        ]);
        expect(bloc.state.detalle, enviada);
      },
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'una consulta cerrada ya no se sondea',
      setUp: () =>
          servicio.detalles = [detalle(consultaJson(estado: 'CERRADA'))],
      build: crear,
      act: (bloc) async {
        await abrir(bloc);
        bloc.add(const DetalleConsultaRefrescado(silencioso: true));
        bloc.add(const DetalleConsultaSolicitado());
        await esperar(bloc, (s) => s.carga == CargaDetalle.cargando);
        await esperar(bloc, (s) => s.carga == CargaDetalle.lista);
      },
      verify: (_) => expect(servicio.llamadas, [
        'detalle:c1',
        'detalle:c1',
      ], reason: 'el latido silencioso no preguntó; la carga a mano sí'),
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'deslizar para refrescar vuelve a pedir el detalle, sin mirar la lista',
      setUp: () => servicio.detalles = [enviada, respondida],
      build: crear,
      act: (bloc) async {
        await abrir(bloc);
        bloc.add(const DetalleConsultaRefrescado());
        await esperar(bloc, (s) => s.detalle == respondida && !s.refrescando);
      },
      verify: (_) => expect(servicio.llamadas, ['detalle:c1', 'detalle:c1']),
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'deslizar para refrescar sí avisa si falla',
      setUp: () => servicio.detalles = [enviada],
      build: crear,
      act: (bloc) async {
        await abrir(bloc);
        servicio.errores['detalle'] = [errorDeRed()];
        bloc.add(const DetalleConsultaRefrescado());
        await esperar(bloc, (s) => s.aviso != null);
      },
      verify: (bloc) {
        expect(bloc.state.aviso?.exito, isFalse);
        expect(bloc.state.aviso?.mensaje, contains('Sin conexión'));
        expect(bloc.state.detalle, enviada);
      },
    );
  });

  group('Escribir', () {
    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'un mensaje con texto: POST mensajes y la conversación al día',
      setUp: () => servicio.detalles = [respondida],
      build: crear,
      act: (bloc) async {
        await abrir(bloc);
        bloc.add(const DetalleConsultaMensajeEnviado('  Gracias, doctor  '));
        await esperar(bloc, (s) => s.enviados == 1);
      },
      verify: (bloc) {
        expect(servicio.escritos.single.texto, 'Gracias, doctor');
        expect(servicio.escritos.single.adjuntoId, isNull);
        expect(bloc.state.detalle?.mensajes, hasLength(2));
        expect(bloc.state.enviando, isFalse);
        expect(servicio.recordadas, hasLength(1), reason: 'queda la copia');
      },
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'con un archivo: primero lo sube y luego escribe con su adjuntoId',
      setUp: () => servicio.detalles = [respondida],
      build: crear,
      act: (bloc) async {
        await abrir(bloc);
        bloc
          ..add(
            DetalleConsultaAdjuntoElegido(
              SeleccionDeArchivos(archivos: [fotoLocal('receta.jpg')]),
            ),
          )
          ..add(const DetalleConsultaMensajeEnviado('Le mando la receta'));
        await esperar(bloc, (s) => s.enviados == 1);
      },
      verify: (bloc) {
        expect(servicio.llamadas, [
          'detalle:c1',
          'subir:c1:receta.jpg',
          'escribir:c1',
        ]);
        expect(servicio.escritos.single.adjuntoId, 'a1');
        expect(bloc.state.adjunto, isNull);
        expect(bloc.state.adjuntoSubido, isNull);
        expect(bloc.state.detalle?.mensajes.last.adjunto?.id, 'a1');
      },
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'si el mensaje falla después de subir el archivo, reintentar no lo '
      'vuelve a subir',
      setUp: () {
        servicio
          ..detalles = [respondida]
          ..errores['escribir'] = [errorDeRed()];
      },
      build: crear,
      act: (bloc) async {
        await abrir(bloc);
        bloc
          ..add(
            DetalleConsultaAdjuntoElegido(
              SeleccionDeArchivos(archivos: [fotoLocal()]),
            ),
          )
          ..add(const DetalleConsultaMensajeEnviado('Foto'));

        final fallido = await esperar(
          bloc,
          (s) => !s.enviando && s.errorEnvio != null,
        );
        expect(fallido.adjuntoSubido?.id, 'a1');
        expect(fallido.adjunto, isNotNull);

        bloc.add(const DetalleConsultaMensajeEnviado('Foto'));
        await esperar(bloc, (s) => s.enviados == 1);
      },
      verify: (_) {
        expect(
          servicio.llamadas.where((l) => l.startsWith('subir')),
          hasLength(1),
        );
        expect(servicio.escritos.single.adjuntoId, 'a1');
      },
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'sin texto no se envía; con archivo, se pide que lo acompañe',
      setUp: () => servicio.detalles = [respondida],
      build: crear,
      act: (bloc) async {
        await abrir(bloc);
        bloc.add(const DetalleConsultaMensajeEnviado('   '));
        await esperar(bloc, (s) => s.errorEnvio != null);
        expect(bloc.state.errorEnvio, 'Escribe tu mensaje.');

        bloc
          ..add(
            DetalleConsultaAdjuntoElegido(
              SeleccionDeArchivos(archivos: [fotoLocal()]),
            ),
          )
          ..add(const DetalleConsultaMensajeEnviado(''));
        await esperar(
          bloc,
          (s) => s.errorEnvio?.contains('acompañar') ?? false,
        );
      },
      verify: (_) => expect(servicio.escritos, isEmpty),
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'sin puedeEscribir no se manda nada',
      setUp: () => servicio.detalles = [enviada],
      build: crear,
      act: (bloc) async {
        await abrir(bloc);
        bloc.add(const DetalleConsultaMensajeEnviado('Hola'));
      },
      verify: (bloc) {
        expect(servicio.escritos, isEmpty);
        expect(bloc.state.enviando, isFalse);
      },
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'un archivo que no vale no se adjunta y se dice por qué',
      setUp: () => servicio.detalles = [respondida],
      build: crear,
      act: (bloc) async {
        await abrir(bloc);
        bloc.add(
          DetalleConsultaAdjuntoElegido(
            SeleccionDeArchivos(
              archivos: [
                ArchivoLocal(
                  nombre: 'hoja.docx',
                  bytes: Uint8List.fromList([0x50, 0x4b, 3, 4]),
                ),
              ],
            ),
          ),
        );
        await esperar(bloc, (s) => s.aviso != null);
      },
      verify: (bloc) {
        expect(bloc.state.adjunto, isNull);
        expect(bloc.state.aviso?.mensaje, contains('hoja.docx'));
      },
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'una respuesta vieja del sondeo no pisa el mensaje recién enviado',
      setUp: () {
        servicio
          ..detalles = [respondida]
          // La lista que salió antes del envío: un solo mensaje.
          ..lista = [respondida.resumen];
      },
      build: crear,
      act: (bloc) async {
        await abrir(bloc);

        // El latido pregunta antes del envío y su respuesta llega después:
        // se descarta, sin volver a pedir el detalle.
        final tarde = Completer<void>();
        servicio.retenerLista = tarde;
        bloc.add(const DetalleConsultaRefrescado(silencioso: true));
        await esperar(bloc, (s) => s.refrescando);

        bloc.add(const DetalleConsultaMensajeEnviado('Nuevo'));
        await esperar(bloc, (s) => s.enviados == 1);
        expect(bloc.state.detalle?.mensajes, hasLength(2));

        tarde.complete();
        await esperar(bloc, (s) => !s.refrescando);
      },
      verify: (bloc) {
        expect(servicio.llamadas, ['detalle:c1', 'listar:u1', 'escribir:c1']);
        expect(bloc.state.detalle?.mensajes, hasLength(2));
      },
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'después de escribir se usa la consulta que devolvió el servidor: el '
      'latido siguiente no vuelve a pedir el detalle',
      setUp: () => servicio.detalles = [respondida],
      build: crear,
      act: (bloc) async {
        await abrir(bloc);
        bloc.add(const DetalleConsultaMensajeEnviado('Gracias'));
        await esperar(bloc, (s) => s.enviados == 1);

        servicio.lista = [bloc.state.detalle!.resumen];
        bloc.add(const DetalleConsultaSondeoCambiado(true));
        await escuchando.future;

        latidos.add(null);
        await esperar(bloc, (s) => s.refrescando);
        await esperar(bloc, (s) => !s.refrescando);
      },
      verify: (bloc) {
        expect(servicio.llamadas, ['detalle:c1', 'escribir:c1', 'listar:u1']);
        expect(bloc.state.detalle?.mensajes, hasLength(2));
      },
    );
  });

  group('Cancelar', () {
    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'una enviada se cancela con su motivo',
      setUp: () => servicio.detalles = [enviada],
      build: crear,
      act: (bloc) async {
        await abrir(bloc);
        expect(bloc.state.puedeCancelar, isTrue);
        bloc.add(const DetalleConsultaCancelada(' Ya me siento mejor '));
        await esperar(bloc, (s) => s.aviso != null && !s.cancelando);
      },
      verify: (bloc) {
        expect(servicio.llamadas, [
          'detalle:c1',
          'cancelar:c1:Ya me siento mejor',
        ], reason: 'se usa la consulta que devolvió el servidor');
        expect(bloc.state.detalle?.estado, EstadoConsulta.cancelada);
        expect(bloc.state.puedeCancelar, isFalse);
        expect(bloc.state.aviso?.exito, isTrue);
      },
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'sin motivo no se cancela',
      setUp: () => servicio.detalles = [enviada],
      build: crear,
      act: (bloc) async {
        await abrir(bloc);
        bloc.add(const DetalleConsultaCancelada('  '));
        await esperar(bloc, (s) => s.aviso != null);
      },
      verify: (_) => expect(
        servicio.llamadas.where((l) => l.startsWith('cancelar')),
        isEmpty,
      ),
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'un motivo de más de 500 caracteres no se manda',
      setUp: () => servicio.detalles = [enviada],
      build: crear,
      act: (bloc) async {
        await abrir(bloc);
        bloc.add(DetalleConsultaCancelada('a' * 501));
        await esperar(bloc, (s) => s.aviso != null);
      },
      verify: (bloc) {
        expect(
          bloc.state.aviso?.mensaje,
          'El motivo admite hasta 500 caracteres.',
        );
        expect(
          servicio.llamadas.where((l) => l.startsWith('cancelar')),
          isEmpty,
        );
      },
    );

    blocTest<DetalleConsultaBloc, DetalleConsultaState>(
      'en revisión ya no se puede cancelar',
      setUp: () =>
          servicio.detalles = [detalle(consultaJson(estado: 'EN_REVISION'))],
      build: crear,
      act: (bloc) async {
        await abrir(bloc);
        bloc.add(const DetalleConsultaCancelada('Motivo'));
      },
      verify: (bloc) {
        expect(bloc.state.puedeCancelar, isFalse);
        expect(servicio.llamadas, ['detalle:c1']);
      },
    );
  });
}
