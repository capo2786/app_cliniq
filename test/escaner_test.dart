// test/escaner_test.dart
//
// El escáner sin pantallas: la extracción de cada cuadro (YUV420, NV21 y
// BGRA, el dedo y la piel del rostro), la serie y su JSON (solo números),
// el motor del teléfono, el análisis del servidor con su plan B, los
// destinos de «Enviar a mi médico» y el cubit con una fuente falsa.

import 'dart:async';
import 'dart:typed_data';

import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/consultas/data/models/consulta.dart';
import 'package:app_cliniq/features/mediciones/data/analisis_en_servidor.dart';
import 'package:app_cliniq/features/mediciones/data/cola_mediciones.dart';
import 'package:app_cliniq/features/mediciones/data/mediciones_service.dart';
import 'package:app_cliniq/features/mediciones/data/models/medicion.dart';
import 'package:app_cliniq/features/mediciones/dominio/destinos_medico.dart';
import 'package:app_cliniq/features/mediciones/escaner/analizador_de_medicion.dart';
import 'package:app_cliniq/features/mediciones/escaner/aviso_experimental.dart';
import 'package:app_cliniq/features/mediciones/escaner/escaner_cubit.dart';
import 'package:app_cliniq/features/mediciones/escaner/extractor_de_cuadros.dart';
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
ImagenCruda _imagen(
  FormatoImagen formato, {
  required int r,
  required int g,
  required int b,
  int ancho = 64,
  int alto = 48,
}) {
  // Del RGB al YUV (BT.601, rango completo).
  final y = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
  final u = (128 - 0.168736 * r - 0.331264 * g + 0.5 * b).round().clamp(0, 255);
  final v = (128 + 0.5 * r - 0.418688 * g - 0.081312 * b).round().clamp(0, 255);

  switch (formato) {
    case FormatoImagen.bgra8888:
      final bytes = Uint8List(ancho * alto * 4);
      for (var i = 0; i < ancho * alto; i++) {
        bytes[i * 4] = b;
        bytes[i * 4 + 1] = g;
        bytes[i * 4 + 2] = r;
        bytes[i * 4 + 3] = 255;
      }
      return ImagenCruda(
        formato: formato,
        ancho: ancho,
        alto: alto,
        planos: [PlanoCrudo(bytes, bytesPorFila: ancho * 4, bytesPorPixel: 4)],
      );
    case FormatoImagen.nv21:
      final bytes = Uint8List(ancho * alto * 3 ~/ 2);
      bytes.fillRange(0, ancho * alto, y);
      for (var i = ancho * alto; i < bytes.length; i += 2) {
        bytes[i] = v;
        bytes[i + 1] = u;
      }
      return ImagenCruda(
        formato: formato,
        ancho: ancho,
        alto: alto,
        planos: [PlanoCrudo(bytes, bytesPorFila: ancho)],
      );
    case FormatoImagen.yuv420:
      return ImagenCruda(
        formato: formato,
        ancho: ancho,
        alto: alto,
        planos: [
          PlanoCrudo(
            Uint8List(ancho * alto)..fillRange(0, ancho * alto, y),
            bytesPorFila: ancho,
          ),
          // U y V intercalados (pixelStride 2), como en muchos Android.
          PlanoCrudo(
            Uint8List(ancho * alto ~/ 2)..fillRange(0, ancho * alto ~/ 2, u),
            bytesPorFila: ancho,
            bytesPorPixel: 2,
          ),
          PlanoCrudo(
            Uint8List(ancho * alto ~/ 2)..fillRange(0, ancho * alto ~/ 2, v),
            bytesPorFila: ancho,
            bytesPorPixel: 2,
          ),
        ],
      );
  }
}

const _piel = (r: 205, g: 150, b: 125);

void main() {
  group('Extraer cada cuadro', () {
    for (final formato in FormatoImagen.values) {
      test('dedo en ${formato.name}: la yema roja cubre la cámara', () {
        final cuadro = reducirDedo(
          _imagen(formato, r: 190, g: 30, b: 25),
          const Duration(milliseconds: 33),
        );
        expect(cuadro.momento, const Duration(milliseconds: 33));
        expect(cuadro.rojo, closeTo(190, 4));
        expect(cuadro.cobertura, 1);
        expect(cuadro.saturacion, 0);
      });
    }

    test('sin el dedo (la mesa, gris): cobertura cero', () {
      final cuadro = reducirDedo(
        _imagen(FormatoImagen.bgra8888, r: 120, g: 118, b: 115),
        Duration.zero,
      );
      expect(cuadro.cobertura, 0);
    });

    test('apretando demasiado, el rojo se quema', () {
      final cuadro = reducirDedo(
        _imagen(FormatoImagen.bgra8888, r: 255, g: 60, b: 40),
        Duration.zero,
      );
      expect(cuadro.saturacion, 1);
    });

    test('la piel por su color (YCbCr); el fondo azul no', () {
      expect(esPiel((r: 205.0, g: 150.0, b: 125.0)), isTrue);
      expect(esPiel((r: 60.0, g: 90.0, b: 200.0)), isFalse);
      expect(esPiel((r: 10.0, g: 8.0, b: 8.0)), isFalse);
    });

    test('rostro: promedia solo la piel y dice cuánta hay', () {
      final extractor = ExtractorDeRostro();
      final conCara = extractor.reducir(
        _imagen(
          FormatoImagen.nv21,
          r: _piel.r,
          g: _piel.g,
          b: _piel.b,
          ancho: 120,
          alto: 160,
        ),
        Duration.zero,
        rotacion: 270,
      );
      expect(conCara.cobertura, 1);
      expect(conCara.rojo, closeTo(_piel.r, 6));
      expect(conCara.verde, closeTo(_piel.g, 6));

      final sinCara = ExtractorDeRostro().reducir(
        _imagen(FormatoImagen.bgra8888, r: 60, g: 90, b: 200),
        Duration.zero,
      );
      expect(sinCara.cobertura, 0);
    });

    test('del óvalo de la pantalla al píxel del sensor girado', () {
      // Imagen del sensor de 640×480; derecha, 480×640.
      expect(aPixelDelSensor(0, 0, 0, 640, 480), (x: 0, y: 0));
      expect(aPixelDelSensor(0, 0, 90, 640, 480), (x: 0, y: 479));
      expect(aPixelDelSensor(0, 0, 270, 640, 480), (x: 639, y: 0));
      expect(aPixelDelSensor(0, 0, 180, 640, 480), (x: 639, y: 479));
      // El centro sigue en el centro.
      final centro = aPixelDelSensor(0.5, 0.5, 90, 640, 480);
      expect(centro.x, closeTo(320, 1));
      expect(centro.y, closeTo(240, 1));
    });
  });

  group('La serie: solo números', () {
    test('el JSON para analizar tiene la forma {metodo, t (ms), canales}', () {
      final serie = SerieSenal.de(
        ModoEscaner.dedo,
        cuadrosDeDedo(Sintetizador(1).dedo(lpm: 72, segundos: 2)),
      );
      final json = serie.aJsonParaAnalisis();

      expect(json.keys, ['metodo', 't', 'canales']);
      expect(json['metodo'], 'CAMARA_DEDO');
      expect((json['t'] as List).first, isA<int>());
      expect((json['canales'] as Map).keys, ['y', 'r']);
      expect((json['canales']['r'] as List).length, (json['t'] as List).length);

      final rostro = SerieSenal.de(
        ModoEscaner.rostro,
        cuadrosDeRostro(Sintetizador(1).rostro(lpm: 72, segundos: 2)),
      ).aJsonParaAnalisis();
      expect(rostro['metodo'], 'CAMARA_ROSTRO');
      expect((rostro['canales'] as Map).keys, ['r', 'g', 'b']);
    });

    test('se escribe y se vuelve a leer igual', () {
      final serie = SerieSenal.de(
        ModoEscaner.rostro,
        cuadrosDeRostro(Sintetizador(2).rostro(lpm: 60, segundos: 1)),
      );
      expect(SerieSenal.desdeJson(serie.aJson()), serie);
      expect(SerieSenal.desdeJson({'modo': 'pies'}), isNull);
    });
  });

  group('El motor del teléfono', () {
    const motor = MotorInterno();

    test('dedo a 72 lpm: el pulso, buena calidad y su nombre en las notas', () {
      final serie = SerieSenal.de(
        ModoEscaner.dedo,
        cuadrosDeDedo(Sintetizador(3).dedo(lpm: 72, ruido: 0.2)),
      );
      final r = motor.analizar(serie);

      expect(r.valido, isTrue);
      expect(r.fc, closeTo(72, 3));
      expect(r.calidad, greaterThan(0.7));
      expect(r.origen, OrigenAnalisis.telefono);
      expect(r.notas, 'motor: interno-ppg v1');
    });

    test('con el rojo quemado mide con la luminancia', () {
      final serie = SerieSenal.de(
        ModoEscaner.dedo,
        cuadrosDeDedo(Sintetizador(4).dedo(lpm: 110), saturacion: 0.7),
      );
      final r = motor.analizar(serie);
      expect(r.fc, closeTo(110, 3));
    });

    test('rostro a 60 lpm con POS', () {
      final serie = SerieSenal.de(
        ModoEscaner.rostro,
        cuadrosDeRostro(Sintetizador(5).rostro(lpm: 60, brillo: 2)),
      );
      final r = motor.analizar(serie);
      expect(r.fc, closeTo(60, 5));
      expect(r.notas, 'motor: interno-pos v1');
    });

    test('sin el dedo: no da valor y aconseja cubrir la cámara', () {
      final serie = SerieSenal.de(
        ModoEscaner.dedo,
        cuadrosDeDedo(Sintetizador(6).dedo(lpm: 72), cobertura: 0.2),
      );
      final r = motor.analizar(serie);
      expect(r.valido, isFalse);
      expect(r.fc, isNull);
      expect(r.consejo, contains('cubría la cámara'));
    });

    test('una señal plana: no da valor', () {
      final plana = Sintetizador(7).plana();
      final r = motor.analizar(
        SerieSenal.de(ModoEscaner.dedo, cuadrosDeDedo(plana)),
      );
      expect(r.valido, isFalse);
      expect(r.consejo, isNotNull);
    });

    test('en vivo: la onda, la calidad y los consejos', () {
      final buena = motor.enVivo(
        SerieSenal.de(
          ModoEscaner.dedo,
          cuadrosDeDedo(Sintetizador(8).dedo(lpm: 72, segundos: 12)),
        ),
      );
      expect(buena.calidad, greaterThan(0.6));
      expect(buena.consejo, isNull);
      expect(buena.onda, isNotEmpty);
      expect(buena.onda.every((v) => v >= -1 && v <= 1), isTrue);

      final sinDedo = motor.enVivo(
        SerieSenal.de(
          ModoEscaner.dedo,
          cuadrosDeDedo(
            Sintetizador(8).dedo(lpm: 72, segundos: 3),
            cobertura: 0.1,
          ),
        ),
      );
      expect(sinDedo.consejo, ConsejosEscaner.cubreLaCamara);
      expect(sinDedo.calidad, isNull); // menos de 8 s

      final sinCara = motor.enVivo(
        SerieSenal.de(
          ModoEscaner.rostro,
          cuadrosDeRostro(
            Sintetizador(8).rostro(lpm: 72, segundos: 3),
            piel: 0.1,
          ),
        ),
      );
      expect(sinCara.consejo, ConsejosEscaner.rostroEnElOvalo);

      final oscuro = Sintetizador(8).rostro(lpm: 72, segundos: 3);
      final apagado = SerieRgb(
        oscuro.tiempos,
        [for (final v in oscuro.rojo) v * 0.25],
        [for (final v in oscuro.verde) v * 0.25],
        [for (final v in oscuro.azul) v * 0.25],
      );
      expect(
        motor
            .enVivo(SerieSenal.de(ModoEscaner.rostro, cuadrosDeRostro(apagado)))
            .consejo,
        ConsejosEscaner.masLuz,
      );
    });
  });

  group('El análisis del servidor (experimental)', () {
    final serie = SerieSenal.de(
      ModoEscaner.dedo,
      cuadrosDeDedo(Sintetizador(9).dedo(lpm: 72, segundos: 30)),
    );

    test('lee {fc, fr, vfc, calidad, motor, advertencias}', () {
      final r = AnalisisEnServidor.leerResultado({
        'fc': 74.4,
        'fr': 15.2,
        'vfc': {'sdnn': 48.2, 'rmssd': 39.9},
        'calidad': 0.82,
        'motor': 'senales-ms 1.0.0',
        'advertencias': ['Señal con algo de movimiento'],
      }, ModoEscaner.dedo);

      expect(r.fc, 74);
      expect(r.fr, 15);
      expect(r.vfc, const Vfc(sdnn: 48.2, rmssd: 39.9));
      expect(r.origen, OrigenAnalisis.servidor);
      expect(r.notas, 'motor: senales-ms 1.0.0');
      expect(r.advertencias, ['Señal con algo de movimiento']);
    });

    test('las reglas de la aplicación mandan: sin FR con calidad < 0,6 y sin '
        'valor con calidad baja', () {
      final regular = AnalisisEnServidor.leerResultado({
        'fc': 80,
        'fr': 16,
        'calidad': 0.5,
        'motor': 'senales-ms 1.0.0',
        'advertencias': <String>[],
      }, ModoEscaner.dedo);
      expect(regular.fc, 80);
      expect(regular.fr, isNull);

      final mala = AnalisisEnServidor.leerResultado({
        'fc': 80,
        'calidad': 0.1,
        'motor': 'senales-ms 1.0.0',
        'advertencias': ['Muy poca luz'],
      }, ModoEscaner.rostro);
      expect(mala.valido, isFalse);
      expect(mala.consejo, 'Muy poca luz');

      expect(
        () => AnalisisEnServidor.leerResultado({'fc': 70}, ModoEscaner.dedo),
        throwsFormatException,
      );
    });

    test(
      'con red: manda solo la serie de números y usa el del servidor',
      () async {
        final api = DioGrabador({
          'POST /portal/mediciones/analizar': (_) => {
            'fc': 73,
            'calidad': 0.9,
            'motor': 'senales-ms 1.0.0',
            'advertencias': <String>[],
          },
        });
        final r = await AnalizadorDeMedicion(
          local: const MotorInterno(),
          servidor: AnalisisEnServidor(api.dio),
          hayRed: () => true,
        ).analizar(serie);

        expect(r.origen, OrigenAnalisis.servidor);
        expect(r.fc, 73);
        final cuerpo =
            api.ultimo('POST /portal/mediciones/analizar').data as Map;
        expect(cuerpo.keys, ['metodo', 't', 'canales']);
        expect(cuerpo['metodo'], 'CAMARA_DEDO');
        // Nada que no sean números en los canales.
        for (final canal in (cuerpo['canales'] as Map).values) {
          expect((canal as List).every((v) => v is num), isTrue);
        }
      },
    );

    test('si el servidor falla, el del teléfono', () async {
      final api = DioGrabador({
        'POST /portal/mediciones/analizar': (_) =>
            throw errorHttp(503, 'El analizador no responde.'),
      });
      final r = await AnalizadorDeMedicion(
        local: const MotorInterno(),
        servidor: AnalisisEnServidor(api.dio),
        hayRed: () => true,
      ).analizar(serie);

      expect(r.origen, OrigenAnalisis.telefono);
      expect(r.fc, closeTo(72, 3));
    });

    test('si tarda más del plazo, el del teléfono', () async {
      final api = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (pedido, manejador) {
              Timer(const Duration(milliseconds: 400), () {
                manejador.resolve(
                  Response(requestOptions: pedido, data: {'calidad': 1}),
                );
              });
            },
          ),
        );
      final r = await AnalizadorDeMedicion(
        local: const MotorInterno(),
        servidor: AnalisisEnServidor(api),
        hayRed: () => true,
        plazo: const Duration(milliseconds: 50),
      ).analizar(serie);

      expect(r.origen, OrigenAnalisis.telefono);
    });

    test('sin red, ni lo intenta', () async {
      final api = DioGrabador();
      final r = await AnalizadorDeMedicion(
        local: const MotorInterno(),
        servidor: AnalisisEnServidor(api.dio),
        hayRed: () => false,
      ).analizar(serie);

      expect(r.origen, OrigenAnalisis.telefono);
      expect(api.pedidos, isEmpty);
    });

    test('una serie de menos de 10 s no se manda', () {
      final corta = SerieSenal.de(
        ModoEscaner.dedo,
        cuadrosDeDedo(Sintetizador(1).dedo(lpm: 72, segundos: 8)),
      );
      expect(AnalisisEnServidor.admite(corta), isFalse);
      expect(AnalisisEnServidor.admite(serie), isTrue);
    });
  });

  group('Enviar a mi médico: a dónde', () {
    final ahora = DateTime(2026, 10, 3, 9);
    Cita cita(
      String id,
      DateTime inicio, {
      TipoCita tipo = TipoCita.telemedicina,
      EstadoCita estado = EstadoCita.programada,
      String? pacienteId,
      bool dependiente = false,
    }) => Cita(
      id: id,
      inicio: inicio,
      fin: inicio.add(const Duration(minutes: 20)),
      tipo: tipo,
      estado: estado,
      doctorId: 'd',
      medico: 'Dra. Ruiz',
      pacienteId: pacienteId,
      paraDependiente: dependiente,
    );

    test('la próxima cita de telemedicina y las consultas abiertas', () {
      final destinos = destinosParaElMedico(
        citas: [
          cita('lejos', DateTime(2026, 10, 9, 10)),
          cita('pronto', DateTime(2026, 10, 5, 10)),
          cita('pasada', DateTime(2026, 10, 1, 10)),
          cita(
            'presencial',
            DateTime(2026, 10, 4, 10),
            tipo: TipoCita.presencial,
          ),
          cita(
            'cancelada',
            DateTime(2026, 10, 4, 11),
            estado: EstadoCita.cancelada,
          ),
          cita(
            'del hijo',
            DateTime(2026, 10, 4, 12),
            pacienteId: 'h1',
            dependiente: true,
          ),
        ],
        consultas: const [
          ConsultaResumen(
            id: 'c1',
            codigo: 'CA-123',
            estado: EstadoConsulta.respondida,
            pacienteId: 'u1',
          ),
          ConsultaResumen(
            id: 'c2',
            codigo: 'CA-999',
            estado: EstadoConsulta.cerrada,
            pacienteId: 'u1',
          ),
        ],
        uid: 'u1',
        ahora: ahora,
      );

      expect(destinos.map((d) => d.citaId ?? d.consultaId), ['pronto', 'c1']);
      expect(destinos.first.titulo, contains('5 de octubre'));
      expect(destinos.last.titulo, 'Consulta en línea CA-123');
    });

    test('para un dependiente, solo lo suyo', () {
      final destinos = destinosParaElMedico(
        citas: [
          cita('mia', DateTime(2026, 10, 4, 10)),
          cita(
            'del hijo',
            DateTime(2026, 10, 4, 12),
            pacienteId: 'h1',
            dependiente: true,
          ),
        ],
        consultas: const [],
        uid: 'u1',
        pacienteId: 'h1',
        ahora: ahora,
      );
      expect(destinos.single.citaId, 'del hijo');
    });
  });

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
