// test/dobles/navegador_falso.dart

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hace de navegador del teléfono: anota lo que `url_launcher` abriría.
///
/// En el anfitrión de pruebas no hay navegador y el canal de `url_launcher`
/// no contesta nunca; con esto contesta al instante y la prueba puede mirar
/// qué dirección se abrió y si fue fuera de la aplicación.
class NavegadorFalso {
  static const MethodChannel _canal = MethodChannel(
    'plugins.flutter.io/url_launcher',
  );

  /// Si abrir sale bien.
  bool abre;

  final List<String> abiertas = [];

  /// Si la última se pidió fuera de la aplicación (sin vista web ni Safari
  /// dentro de la aplicación).
  bool? ultimaFuera;

  NavegadorFalso({this.abre = true});

  void instalar() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, (llamada) async {
          final argumentos = llamada.arguments;

          if (llamada.method == 'launch' && argumentos is Map) {
            abiertas.add(argumentos['url'].toString());
            ultimaFuera =
                argumentos['useWebView'] == false &&
                argumentos['useSafariVC'] == false;
            return abre;
          }

          if (llamada.method == 'canLaunch') return true;

          return null;
        });

    addTearDown(quitar);
  }

  void quitar() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, null);
  }
}
