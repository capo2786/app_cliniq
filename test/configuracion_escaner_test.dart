// test/configuracion_escaner_test.dart
//
// La configuración del escáner que llegó con el rostro a pantalla
// completa: el modo dedo, opcional y apagado por defecto
// (`telemedicina.escanerDedoActivo`).

import 'package:app_cliniq/core/configuracion/config_publica.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';

void main() {
  test('el modo dedo del escáner: opcional y apagado por defecto', () {
    expect(configDePrueba().telemedicina.escanerDedoActivo, isFalse);
    expect(
      configDePrueba(telemedicina: {'escanerDedoActivo': true})
          .telemedicina
          .escanerDedoActivo,
      isTrue,
    );
    expect(
      configDePrueba(telemedicina: {'escanerDedoActivo': false})
          .telemedicina
          .escanerDedoActivo,
      isFalse,
    );

    // Un servidor anterior no lo manda: queda apagado.
    final json = configJson();
    (json['telemedicina'] as Map).remove('escanerDedoActivo');
    expect(
      ConfigPublica.desdeJson(json).telemedicina.escanerDedoActivo,
      isFalse,
    );

    // Si llega, se lee estricto.
    expect(
      () => configDePrueba(telemedicina: {'escanerDedoActivo': 'sí'}),
      throwsFormatException,
    );
  });
}
