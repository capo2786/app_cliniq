// test/fotos_perfil_dominio_test.dart

import 'package:app_cliniq/features/agendar/data/models/medico_portal.dart';
import 'package:app_cliniq/features/auth/data/models/usuario.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:app_cliniq/features/consultas/data/models/consulta.dart';
import 'package:app_cliniq/features/consultas/data/models/opciones_consulta.dart';
import 'package:app_cliniq/features/dependientes/data/models/dependiente.dart';
import 'package:app_cliniq/features/fotos_perfil/dominio/foto_perfil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'dobles/fotos_perfil.dart';

/// La lógica pura de la foto de perfil: iniciales, versiones, el recorte
/// cuadrado y lo que leen los modelos.
void main() {
  group('Iniciales', () {
    test('dos palabras: la primera letra de cada una', () {
      expect(inicialesDe('Ana María Pérez'), 'AM');
      expect(inicialesDe('  luis   mora '), 'LM');
    });

    test('una palabra: una letra; vacío: «?»', () {
      expect(inicialesDe('Ana'), 'A');
      expect(inicialesDe('   '), '?');
    });
  });

  group('Versión de la foto', () {
    test('entero, número o texto; cero, negativo o basura: sin foto', () {
      expect(versionDeFoto(3), 3);
      expect(versionDeFoto(4.0), 4);
      expect(versionDeFoto(' 7 '), 7);
      expect(versionDeFoto(0), isNull);
      expect(versionDeFoto(-1), isNull);
      expect(versionDeFoto('x'), isNull);
      expect(versionDeFoto(null), isNull);
    });

    test('la respuesta del PUT trae el usuario suelto o en «user»', () {
      expect(versionEnRespuesta({'uid': 'u1', 'fotoVersion': 5}), 5);
      expect(
        versionEnRespuesta({
          'user': {'fotoVersion': 6},
        }),
        6,
      );
      expect(versionEnRespuesta({'uid': 'u1'}), isNull);
      expect(versionEnRespuesta('ok'), isNull);
    });
  });

  group('Recorte centrado', () {
    test('horizontal: se recortan los lados', () {
      expect(recorteCentrado(1024, 768), (x: 128, y: 0, lado: 768));
    });

    test('vertical: se recortan arriba y abajo', () {
      expect(recorteCentrado(600, 1000), (x: 0, y: 200, lado: 600));
    });

    test('cuadrada: queda entera', () {
      expect(recorteCentrado(512, 512), (x: 0, y: 0, lado: 512));
    });

    test('sin tamaño: error', () {
      expect(() => recorteCentrado(0, 10), throwsArgumentError);
    });
  });

  group('Recortar la foto', () {
    test('una PNG apaisada sale JPEG cuadrado de 512 px', () {
      final salida = recortarFotoDePerfilSincrono(pngDePrueba(300, 200));

      // Los magic bytes de un JPEG.
      expect(salida.sublist(0, 3), [0xFF, 0xD8, 0xFF]);

      final leida = img.decodeJpg(salida)!;
      expect(leida.width, ladoFotoPerfil);
      expect(leida.height, ladoFotoPerfil);
      expect(salida.length, lessThan(1024 * 1024));
    });

    test('una grande también baja a 512 px', () {
      final salida = recortarFotoDePerfilSincrono(pngDePrueba(900, 1024));
      final leida = img.decodeJpg(salida)!;

      expect((leida.width, leida.height), (512, 512));
    });

    test('lo que no es imagen: FormatException', () {
      expect(
        () => recortarFotoDePerfilSincrono(jpegFalso),
        throwsFormatException,
      );
    });

    test('en un isolate aparte da lo mismo', () async {
      final salida = await recortarFotoDePerfil(pngDePrueba(120, 160));

      expect(img.decodeJpg(salida)!.width, 512);
    });
  });

  group('Modelos', () {
    test('Usuario: fotoVersion y la copia con otra foto', () {
      final usuario = Usuario({'uid': 'u1', 'nombre': 'Ana', 'fotoVersion': 2});

      expect(usuario.fotoVersion, 2);
      expect(usuario.iniciales, 'A');
      expect(usuario.conFotoVersion(3).fotoVersion, 3);
      expect(usuario.conFotoVersion(null).fotoVersion, isNull);
      expect(
        usuario.conFotoVersion(null).datos.containsKey('fotoVersion'),
        isFalse,
      );
      expect(Usuario(const {'uid': 'u2'}).fotoVersion, isNull);
    });

    test('Dependiente: se lee, se guarda en la copia y se cambia', () {
      final d = Dependiente.desdeJson({
        'uid': 'd1',
        'nombre': 'Sofía',
        'fotoVersion': 4,
      });

      expect(d.fotoVersion, 4);
      expect(Dependiente.desdeJson(d.aJson()).fotoVersion, 4);
      expect(d.conFotoVersion(null).fotoVersion, isNull);
      expect(d.conFotoVersion(5), isNot(d));
      expect(d.conFotoVersion(5).nombre, 'Sofía');
    });

    test('Médico del portal y cita: la versión de la foto del médico', () {
      expect(
        MedicoPortal.desdeJson({
          'uid': 'm1',
          'nombre': 'Luis Mora',
          'fotoVersion': 9,
        }).fotoVersion,
        9,
      );

      final cita = Cita.desdeJson({
        '_id': 'c1',
        'start': '2026-10-20T09:00:00.000Z',
        'end': '2026-10-20T09:30:00.000Z',
        'type': 'PRESENCIAL',
        'status': 'PROGRAMADA',
        'doctorId': 'm1',
        'doctorFotoVersion': 3,
      });

      expect(cita.doctorFotoVersion, 3);
      expect(Cita.desdeJson(cita.aJson()).doctorFotoVersion, 3);
      expect(cita.copiarCon(medico: 'Otro').doctorFotoVersion, 3);
    });

    test('Médico elegible de una consulta: su fotoVersion', () {
      expect(
        MedicoConsulta.desdeJson({
          'uid': 'm1',
          'nombre': 'Luis',
          'fotoVersion': 2,
        })!.fotoVersion,
        2,
      );
      expect(
        MedicoConsulta.desdeJson({'uid': 'm1', 'nombre': 'Luis'})!.fotoVersion,
        isNull,
      );
    });

    test('Consulta: la foto del médico en sus mensajes', () {
      final detalle = ConsultaDetalle.desdeJson({
        '_id': 'k1',
        'codigo': 'CA-1',
        'estado': 'RESPONDIDA',
        'medicoId': 'm1',
        'doctorFotoVersion': 7,
        'mensajes': [
          {'_id': '1', 'autorId': 'm1', 'esMedico': true, 'texto': 'Hola'},
          {'_id': '2', 'autorId': 'u1', 'esMedico': false, 'texto': 'Gracias'},
          {
            '_id': '3',
            'autorId': 'm2',
            'esMedico': true,
            'texto': 'Soy otro médico',
            'autorFotoVersion': 2,
          },
        ],
      });

      expect(detalle.medicoFotoVersion, 7);
      expect(detalle.resumen.medicoFotoVersion, 7);
      expect(detalle.fotoVersionDe(detalle.mensajes[0]), 7);
      expect(detalle.fotoVersionDe(detalle.mensajes[1]), isNull);
      expect(detalle.fotoVersionDe(detalle.mensajes[2]), 2);
      expect(ConsultaDetalle.desdeJson(detalle.aJson()).medicoFotoVersion, 7);
    });
  });
}
