// test/medicion_en_vivo_test.dart
//
// Lo que pasa mientras se mide, sin cámara ni pantalla: la cuenta que
// arranca sola con la cara bien encuadrada, se pausa al perderla y sigue
// sin el hueco; y la FC en vivo con una señal sintética a 72 lpm.

import 'package:app_cliniq/features/mediciones/dominio/reglas_mediciones.dart';
import 'package:app_cliniq/features/mediciones/escaner/control_de_medicion.dart';
import 'package:app_cliniq/features/mediciones/escaner/estimador_en_vivo.dart';
import 'package:app_cliniq/features/mediciones/escaner/motor_signos_camara.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/guia_encuadre.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/rostro_detectado.dart';
import 'package:app_cliniq/features/mediciones/escaner/serie_senal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/mediciones.dart';
import 'dobles/rostro.dart';
import 'dobles/senales.dart';

/// Un cuadro del rostro a los [ms] milisegundos, con o sin cara.
CuadroPpg _cuadro(int ms, {bool conCara = true, RostroDetectado? rostro}) {
  final momento = Duration(milliseconds: ms);
  return CuadroPpg(
    momento: momento,
    rojo: 150,
    verde: 110,
    azul: 90,
    luminancia: 120,
    cobertura: 0.8,
    rostro: conCara ? (rostro ?? rostroSintetico(momento: momento)) : null,
  );
}

void main() {
  group('La cuenta de la medición', () {
    test('dedo: cuenta desde el primer cuadro y se completa', () {
      final control = ControlDeMedicion(segundos: 2, conEncuadre: false);
      expect(control.fase, FaseMedicion.midiendo);
      var evento = EventoDeMedicion.ninguno;
      var i = 0;
      while (evento != EventoDeMedicion.completa) {
        evento = control.alCuadro(_cuadro(33 * i++, conCara: false));
      }
      expect(control.medido, greaterThanOrEqualTo(2));
      expect(control.restantes, 0);
      expect(control.instruccion, isNull);
    });

    test('rostro: no arranca hasta un segundo bien encuadrado', () {
      final control = ControlDeMedicion(segundos: 30, conEncuadre: true);
      // Lejos: «Acércate un poco», y la cuenta espera.
      for (var i = 0; i < 60; i++) {
        final evento = control.alCuadro(
          _cuadro(
            33 * i,
            rostro: rostroSintetico(
              ancho: 120,
              momento: Duration(milliseconds: 33 * i),
            ),
          ),
        );
        expect(evento, EventoDeMedicion.ninguno);
      }
      expect(control.fase, FaseMedicion.preparando);
      expect(control.instruccion, InstruccionEncuadre.acercate);
      expect(control.cuadros, isEmpty);
      expect(control.restantes, 30);

      // Bien: a los 1 s seguidos, arranca.
      final eventos = [
        for (var i = 60; i < 100; i++) control.alCuadro(_cuadro(33 * i)),
      ];
      final arranque = eventos.indexOf(EventoDeMedicion.arranco);
      expect(arranque, inInclusiveRange(29, 32)); // ~30 cuadros = 1 s
      expect(control.fase, FaseMedicion.midiendo);
      expect(control.instruccion, InstruccionEncuadre.perfecto);
      expect(control.cuadros.length, eventos.length - arranque);
    });

    test('un parpadeo de la detección (menos de 2 s) no pausa', () {
      final control = ControlDeMedicion(segundos: 30, conEncuadre: true);
      var ms = 0;
      for (var i = 0; i < 40; i++, ms += 33) {
        control.alCuadro(_cuadro(ms));
      }
      for (var i = 0; i < 45; i++, ms += 33) {
        expect(
          control.alCuadro(_cuadro(ms, conCara: false)),
          EventoDeMedicion.ninguno,
        );
      }
      expect(control.fase, FaseMedicion.midiendo);
    });

    test('pierde la cara más de 2 s: pausa, quita esos cuadros y sigue sin '
        'el hueco', () {
      final control = ControlDeMedicion(segundos: 30, conEncuadre: true);
      var ms = 0;
      for (var i = 0; i < 160; i++, ms += 33) {
        control.alCuadro(_cuadro(ms)); // arranca a ~1 s; mide ~4 s
      }
      final antes = control.medido;
      expect(antes, closeTo(4.2, 0.2));

      var pausa = false;
      for (var i = 0; i < 90 && !pausa; i++, ms += 33) {
        pausa =
            control.alCuadro(_cuadro(ms, conCara: false)) ==
            EventoDeMedicion.pausa;
      }
      expect(pausa, isTrue);
      expect(control.fase, FaseMedicion.pausada);
      expect(control.instruccion, InstruccionEncuadre.sinRostro);
      // Lo medido sin cara se quitó: queda lo de antes.
      expect(control.medido, closeTo(antes, 0.05));
      final enPausa = control.restantes;

      // Vuelve: un segundo bien encuadrada y sigue.
      ms += 3000;
      var reanudo = false;
      for (var i = 0; i < 40 && !reanudo; i++, ms += 33) {
        reanudo = control.alCuadro(_cuadro(ms)) == EventoDeMedicion.reanudo;
        if (!reanudo) expect(control.restantes, enPausa);
      }
      expect(reanudo, isTrue);
      for (var i = 0; i < 30; i++, ms += 33) {
        control.alCuadro(_cuadro(ms));
      }
      // La serie sigue sin el hueco: ningún salto mayor a dos cuadros.
      final tiempos = control.cuadros.map((c) => c.segundos).toList();
      for (var k = 1; k < tiempos.length; k++) {
        expect(tiempos[k] - tiempos[k - 1], inInclusiveRange(0.0, 0.07));
      }
      expect(control.medido, closeTo(antes + 1, 0.1));
    });

    test('si no vuelve en 8 s, la medición se da por perdida', () {
      final control = ControlDeMedicion(segundos: 30, conEncuadre: true);
      var ms = 0;
      for (var i = 0; i < 60; i++, ms += 33) {
        control.alCuadro(_cuadro(ms));
      }
      final eventos = <EventoDeMedicion>[];
      for (var i = 0; i < 300; i++, ms += 33) {
        eventos.add(control.alCuadro(_cuadro(ms, conCara: false)));
        if (eventos.last == EventoDeMedicion.perdida) break;
      }
      expect(eventos, contains(EventoDeMedicion.pausa));
      expect(eventos.last, EventoDeMedicion.perdida);
      // ~8 s desde que se perdió.
      expect(eventos.length * 0.033, closeTo(8, 0.2));
    });
  });

  group('La FC en vivo', () {
    test(
      'con una señal sintética a 72 lpm: aparece a los 8–10 s y acierta',
      () {
        final cuadros = cuadrosDeDedo(
          Sintetizador(31).dedo(lpm: 72, segundos: 16, ruido: 0.1),
        );
        final estimador = EstimadorEnVivo(motor: const MotorInterno());
        final lecturas = <({double medido, LecturaEnVivo lectura})>[];
        for (var n = 1; n <= cuadros.length; n++) {
          final serie = SerieSenal.de(ModoEscaner.dedo, cuadros.sublist(0, n));
          final medido = serie.duracion;
          final lectura = estimador.avanzar(serie, medido);
          if (lectura != null) lecturas.add((medido: medido, lectura: lectura));
        }

        // Una lectura por segundo.
        expect(lecturas.length, inInclusiveRange(15, 17));
        final primera = lecturas.firstWhere((l) => l.lectura.fcVisible);
        expect(primera.medido, inInclusiveRange(7.9, 10));
        for (final l in lecturas.where((l) => l.medido < 7.9)) {
          expect(l.lectura.fc, isNull);
        }
        for (final l in lecturas.where((l) => l.lectura.fcVisible)) {
          expect(l.lectura.fc, closeTo(72, 3));
          expect(l.lectura.calidad, greaterThanOrEqualTo(umbralCalidadRegular));
          // Los latidos caen sobre la onda que se dibuja.
          expect(l.lectura.latidosEnOnda, isNotEmpty);
          for (final i in l.lectura.latidosEnOnda) {
            expect(l.lectura.onda[i], greaterThan(0));
          }
        }

        // La historia de la mini gráfica y los latidos contados.
        expect(estimador.historial.length, inInclusiveRange(7, 9));
        expect(estimador.historial.first.segundo, primera.medido);
        // A 72 lpm, unos 1,2 latidos por segundo hasta ~0,4 s del final.
        expect(estimador.latidos, closeTo(72 / 60 * 15.5, 3));
      },
    );

    test('el rostro a 72 lpm (POS) también da la FC en vivo', () {
      final cuadros = cuadrosDeRostro(
        Sintetizador(32).rostro(lpm: 72, segundos: 12),
      );
      final lectura = const MotorInterno().enVivo(
        SerieSenal.de(ModoEscaner.rostro, cuadros),
      );
      expect(lectura.fcVisible, isTrue);
      expect(lectura.fc, closeTo(72, 4));
    });

    test('reiniciar olvida la historia y los latidos', () {
      final estimador = EstimadorEnVivo(motor: const MotorInterno());
      final serie = SerieSenal.de(
        ModoEscaner.dedo,
        cuadrosDeDedo(Sintetizador(33).dedo(lpm: 60, segundos: 12)),
      );
      expect(estimador.avanzar(serie, 12), isNotNull);
      expect(estimador.avanzar(serie, 12.5), isNull); // aún no toca
      expect(estimador.latidos, greaterThan(0));
      estimador.reiniciar();
      expect(estimador.latidos, 0);
      expect(estimador.historial, isEmpty);
    });
  });
}
