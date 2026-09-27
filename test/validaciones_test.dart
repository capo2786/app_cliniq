// test/validaciones_test.dart

import 'package:app_cliniq/core/catalogos/catalogo_service.dart';
import 'package:app_cliniq/features/dependientes/dominio/validaciones.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';

/// La cédula con dígito verificador y las reglas del formulario de
/// dependientes: las mismas que el panel web y que el servidor.
void main() {
  group('Cédula ecuatoriana (módulo 10)', () {
    test('acepta cédulas válidas', () {
      expect(esCedulaValida('1710034065'), isTrue);
      expect(esCedulaValida('0926687856'), isTrue);
      expect(esCedulaValida('1712345675'), isTrue);
    });

    test('rechaza un dígito verificador equivocado', () {
      expect(esCedulaValida('1710034066'), isFalse);
      expect(esCedulaValida('1712345678'), isFalse);
    });

    test('rechaza dos dígitos cambiados de lugar', () {
      expect(esCedulaValida('1701034065'), isFalse);
    });

    test('rechaza provincias que no existen', () {
      expect(esCedulaValida('0012345678'), isFalse);
      expect(esCedulaValida('2512345678'), isFalse);
    });

    test('acepta la provincia 30 (ecuatorianos en el exterior)', () {
      // 30 + 1 + 234567 → verificador calculado a mano: 30 1 2 3 4 5 6 7
      // coef 2 1 2 1 2 1 2 1 2 sobre 3,0,1,2,3,4,5,6,7 →
      // 6,0,2,2,6,4,10→1,6,14→5 = 32 → (10-2)%10 = 8.
      expect(esCedulaValida('3012345678'), isTrue);
    });

    test('rechaza tercer dígito de 6 en adelante (no persona natural)', () {
      expect(esCedulaValida('1760001550'), isFalse);
    });

    test('rechaza largo o caracteres incorrectos', () {
      expect(esCedulaValida('171003406'), isFalse);
      expect(esCedulaValida('17100340655'), isFalse);
      expect(esCedulaValida('17100340a5'), isFalse);
      expect(esCedulaValida(''), isFalse);
    });
  });

  group('Documento según su tipo', () {
    // Lo que dice la configuración de prueba (`general.validarCedula`).
    final validar = configDePrueba().general.validarCedula;

    String? error(String? valor, String tipo, {bool? validarCedula}) =>
        errorDeDocumento(valor, tipo, validarCedula: validarCedula ?? validar);

    test('vacío es válido: el documento es opcional', () {
      expect(error('', 'CEDULA'), isNull);
      expect(error(null, 'PASAPORTE'), isNull);
    });

    test('con CEDULA y la validación encendida se exige el módulo 10', () {
      expect(validar, isTrue);
      expect(error('1710034065', 'CEDULA'), isNull);
      expect(error('1710034066', 'CEDULA'), isNotNull);
    });

    test('con la validación apagada en la clínica basta con diez dígitos', () {
      final apagada = configDePrueba(general: {'validarCedula': false})
          .general
          .validarCedula;

      expect(error('1710034066', 'CEDULA', validarCedula: apagada), isNull);
      expect(error('171003406', 'CEDULA', validarCedula: apagada), isNotNull);
      expect(error('17100340a6', 'CEDULA', validarCedula: apagada), isNotNull);
    });

    test('con PASAPORTE, de 5 a 20 letras o números', () {
      expect(error('AB12345', 'PASAPORTE'), isNull);
      expect(error('1710034066', 'PASAPORTE'), isNull);
      expect(error('AB1', 'PASAPORTE'), isNotNull);
      expect(error('AB-12345', 'PASAPORTE'), isNotNull);
    });

    test('un tipo que la aplicación no conoce solo se mide', () {
      expect(error('XYZ-123', 'CARNET'), isNull);
      expect(error('X' * 21, 'CARNET'), isNotNull);
    });
  });

  group('Catálogos de los formularios', () {
    final catalogos = catalogosDePrueba();

    test('las opciones son los códigos del catálogo, en su orden', () {
      expect(codigosParaElegir(catalogos.items(Catalogos.sexo), null), [
        'F',
        'M',
        'O',
      ]);
      expect(
        codigosParaElegir(catalogos.items(Catalogos.tipoSangre), '').first,
        'O+',
      );
    });

    test('un valor guardado que ya no está se conserva al final', () {
      expect(codigosParaElegir(catalogos.items(Catalogos.sexo), 'X'), [
        'F',
        'M',
        'O',
        'X',
      ]);
    });

    test('la etiqueta sale del catálogo; sin ella, el código', () {
      expect(etiquetaDe(catalogos, Catalogos.sexo, 'M'), 'Masculino');
      expect(
        etiquetaDe(catalogos, Catalogos.tipoDocumento, 'CEDULA'),
        'Cédula',
      );
      expect(etiquetaDe(catalogos, Catalogos.sexo, 'X'), 'X');
    });
  });

  group('Fecha de nacimiento', () {
    final hoy = DateTime(2026, 9, 28);

    test('es obligatoria', () {
      expect(errorDeFechaNacimiento('', hoy), isNotNull);
      expect(errorDeFechaNacimiento(null, hoy), isNotNull);
    });

    test('no puede estar en el futuro', () {
      expect(errorDeFechaNacimiento('2026-09-29', hoy), isNotNull);
      expect(errorDeFechaNacimiento('2026-09-28', hoy), isNull);
      expect(errorDeFechaNacimiento('2015-03-10', hoy), isNull);
    });

    test('rechaza fechas imposibles y años absurdos', () {
      expect(errorDeFechaNacimiento('2020-02-30', hoy), isNotNull);
      expect(errorDeFechaNacimiento('1850-01-01', hoy), isNotNull);
    });

    test('la edad en años cumplidos', () {
      expect(edad('2016-09-28', hoy), 10);
      expect(edad('2016-09-29', hoy), 9);
      expect(edad('fecha', hoy), isNull);
    });
  });

  group('Otros campos', () {
    test('nombre de 3 a 120 caracteres', () {
      expect(errorDeNombre('Ana'), isNull);
      expect(errorDeNombre('  Al '), isNotNull);
      expect(errorDeNombre('a' * 121), isNotNull);
    });

    test('teléfono opcional de 7 a 15 dígitos', () {
      expect(errorDeTelefono(''), isNull);
      expect(errorDeTelefono('0991234567'), isNull);
      expect(errorDeTelefono('+593 99 123 4567'), isNull);
      expect(errorDeTelefono('123'), isNotNull);
    });
  });
}
