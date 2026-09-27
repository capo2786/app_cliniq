// test/dobles/registro.dart

/// Lo que usan las pruebas del registro: los documentos legales vigentes de
/// una clínica de prueba y un registro lleno.
library;

import 'package:app_cliniq/features/auth/data/models/datos_registro.dart';

/// Los documentos vigentes como los manda `GET /legal/documentos`: los dos
/// del registro, dos más de los pacientes y uno de los médicos.
List<Map<String, dynamic>> documentosVigentesJson() => [
  for (final (clave, slug, titulo, tipos) in [
    ('TERMINOS', 'terminos', 'Términos y condiciones de uso', [1, 2, 3, 4]),
    ('AVISO_LEGAL', 'aviso-legal', 'Aviso legal', [3]),
    (
      'PRIVACIDAD',
      'privacidad',
      'Política de privacidad y protección de datos',
      [1, 2, 3, 4],
    ),
    (
      'CONSENTIMIENTO_TELEMEDICINA',
      'consentimiento-telemedicina',
      'Consentimiento informado para telemedicina',
      [3],
    ),
    ('CONTRATO_MEDICO', 'contrato-medico', 'Condiciones para médicos', [2]),
  ])
    {
      'clave': clave,
      'slug': slug,
      'version': '1.0',
      'titulo': titulo,
      'resumen': '',
      'tipos': tipos,
      'vigenteDesde': '2026-01-01T05:00:00.000Z',
    },
];

DatosRegistro datosDePrueba({String telefono = '', String sexo = ''}) =>
    DatosRegistro(
      nombre: '  Ana   María  Torres ',
      email: ' Ana.Torres@Correo.COM ',
      telefono: telefono,
      tipoDocumento: 'PASAPORTE',
      cedula: ' ab12345 ',
      fechaNacimiento: '1990-05-17',
      sexo: sexo,
      password: 'Clave-segura-1',
    );
