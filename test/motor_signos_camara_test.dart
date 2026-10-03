// test/motor_signos_camara_test.dart
//
// El motor del teléfono (dedo y rostro, en vivo y al terminar), el
// análisis experimental del servidor con su plan B y los destinos de
// «Enviar a mi médico».

import 'dart:async';

import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/consultas/data/models/consulta.dart';
import 'package:app_cliniq/features/mediciones/data/analisis_en_servidor.dart';
import 'package:app_cliniq/features/mediciones/dominio/destinos_medico.dart';
import 'package:app_cliniq/features/mediciones/escaner/analizador_de_medicion.dart';
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
      expect(sinCara.consejo, ConsejosEscaner.rostroEnElMarco);

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

      // Señal plana: el servidor responde sin FC
      final plana = AnalisisEnServidor.leerResultado({
        'fc': null,
        'calidad': 0.0,
        'motor': 'senales-ms 0.1.0',
        'advertencias': ['No se detectó pulso'],
      }, ModoEscaner.dedo);
      expect(plana.valido, isFalse);
      expect(plana.fc, isNull);
      expect(plana.consejo, 'No se detectó pulso');

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
}
