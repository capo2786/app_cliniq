// test/guia_encuadre_test.dart
//
// La guía de encuadre: una instrucción a la vez, con su prioridad, para
// cada caso de la tabla del contrato (con ML Kit y con el respaldo por
// color de piel).

import 'package:app_cliniq/features/mediciones/escaner/rostro/guia_encuadre.dart';
import 'package:app_cliniq/features/mediciones/escaner/rostro/rostro_detectado.dart';
import 'package:app_cliniq/features/mediciones/escaner/serie_senal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/rostro.dart';

CuadroPpg _cuadro(
  RostroDetectado? rostro, {
  double luminancia = 120,
  double cobertura = 0.8,
  bool porColor = false,
  Duration momento = Duration.zero,
}) => CuadroPpg(
  momento: momento,
  rojo: 150,
  verde: 110,
  azul: 90,
  luminancia: luminancia,
  cobertura: cobertura,
  rostro: rostro,
  porColorDePiel: porColor,
);

void main() {
  late GuiaDeEncuadre guia;

  setUp(() => guia = GuiaDeEncuadre());

  InstruccionEncuadre evaluar(RostroDetectado? r, {double luminancia = 120}) =>
      guia.evaluar(_cuadro(r, luminancia: luminancia));

  group('Con ML Kit', () {
    test('sin rostro: «Pon tu cara dentro del marco»', () {
      final i = evaluar(null);
      expect(i, InstruccionEncuadre.sinRostro);
      expect(i.texto, 'Pon tu cara dentro del marco');
      expect(i.hayRostro, isFalse);
    });

    test('muy lejos (< 35 % del ancho): «Acércate un poco»', () {
      final i = evaluar(rostroSintetico(ancho: 140)); // 29 %
      expect(i, InstruccionEncuadre.acercate);
      expect(i.texto, 'Acércate un poco');
    });

    test('muy cerca (> 85 %): «Aléjate un poco»', () {
      final i = evaluar(rostroSintetico(ancho: 430)); // 90 %
      expect(i.texto, 'Aléjate un poco');
    });

    test('descentrado: «Centra tu cara»', () {
      expect(evaluar(rostroSintetico(cx: 340)).texto, 'Centra tu cara');
      expect(evaluar(rostroSintetico(cy: 420)).texto, 'Centra tu cara');
    });

    test('girado (|Y| > 15° o |Z| > 12°): «Mira de frente a la cámara»', () {
      expect(
        evaluar(rostroSintetico(anguloY: -20)).texto,
        'Mira de frente a la cámara',
      );
      expect(
        evaluar(rostroSintetico(anguloZ: 14)).texto,
        'Mira de frente a la cámara',
      );
      expect(evaluar(rostroSintetico(anguloY: 10, anguloZ: 8)).bien, isTrue);
    });

    test('el centro de la caja se mueve: «Quédate quieto»', () {
      for (var i = 0; i < 4; i++) {
        final r = rostroSintetico(
          cx: 240 + i * 8.0, // 8 px por detección: 3 % del ancho
          momento: Duration(milliseconds: 100 * i),
        );
        guia.evaluar(_cuadro(r, momento: r.momento));
      }
      final ultimo = rostroSintetico(
        cx: 272,
        momento: const Duration(milliseconds: 400),
      );
      expect(guia.evaluar(_cuadro(ultimo)).texto, 'Quédate quieto');

      // Quieto otra vez durante la ventana: ya está bien.
      for (var i = 5; i < 14; i++) {
        final r = rostroSintetico(
          cx: 272,
          momento: Duration(milliseconds: 100 * i),
        );
        guia.evaluar(_cuadro(r));
      }
      final quieto = rostroSintetico(
        cx: 272,
        momento: const Duration(milliseconds: 1400),
      );
      expect(guia.evaluar(_cuadro(quieto)).bien, isTrue);
    });

    test('un temblor de 1 % no cuenta como movimiento', () {
      for (var i = 0; i < 8; i++) {
        final r = rostroSintetico(
          cx: 240 + (i.isEven ? 2.0 : -2.0),
          momento: Duration(milliseconds: 100 * i),
        );
        expect(guia.evaluar(_cuadro(r)).bien, isTrue);
      }
    });

    test('poca luz: «Busca un lugar con más luz»', () {
      expect(
        evaluar(rostroSintetico(), luminancia: 45).texto,
        'Busca un lugar con más luz',
      );
    });

    test('todo bien: «Perfecto, no te muevas»', () {
      final i = evaluar(rostroSintetico());
      expect(i, InstruccionEncuadre.perfecto);
      expect(i.texto, 'Perfecto, no te muevas');
      expect(i.bien, isTrue);
    });

    test('la prioridad: lejos y a oscuras dice primero «Acércate»', () {
      expect(
        evaluar(rostroSintetico(ancho: 120, cx: 100), luminancia: 20),
        InstruccionEncuadre.acercate,
      );
      expect(
        evaluar(rostroSintetico(cx: 340, anguloY: 30)),
        InstruccionEncuadre.centra,
      );
    });
  });

  group('Sin ML Kit (color de piel)', () {
    test('poca piel en el marco: «Pon tu cara dentro del marco»', () {
      expect(
        guia.evaluar(_cuadro(null, cobertura: 0.1, porColor: true)),
        InstruccionEncuadre.sinRostro,
      );
    });

    test('poca luz y todo bien', () {
      expect(
        guia.evaluar(_cuadro(null, luminancia: 30, porColor: true)),
        InstruccionEncuadre.masLuz,
      );
      expect(
        guia.evaluar(_cuadro(null, porColor: true)),
        InstruccionEncuadre.perfecto,
      );
    });
  });
}
