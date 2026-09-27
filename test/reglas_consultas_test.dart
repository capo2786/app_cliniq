// test/reglas_consultas_test.dart

import 'package:app_cliniq/features/consultas/data/models/campo_formulario.dart';
import 'package:app_cliniq/features/consultas/data/models/consulta.dart';
import 'package:app_cliniq/features/consultas/dominio/reglas_consultas.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/consultas.dart';

import 'package:app_cliniq/core/fechas/zona_clinica.dart';

/// Las reglas puras de las consultas en línea: el plazo, el formulario y
/// cómo se enseñan las respuestas.
void main() {
  // La zona de la clínica llega de su configuración (`clinica.zonaHoraria`).
  setUpAll(() => ZonaClinica.aplicar('America/Guayaquil'));

  ConsultaResumen resumen(Map<String, dynamic> json) =>
      ConsultaResumen.desdeJson(json);

  final campos = interpretarCampos(camposLesion);

  group('Cuánto le queda al médico', () {
    // Enviada el 28/09 a las 14:00 UTC, vence el 30/09 a las 14:00 UTC.
    final enviada = resumen(consultaJson());

    test('en horas enteras, redondeando hacia abajo', () {
      expect(
        tiempoRestante(enviada, DateTime.utc(2026, 9, 28, 14)),
        'Quedan 48 h',
      );
      expect(
        tiempoRestante(enviada, DateTime.utc(2026, 9, 29, 2, 30)),
        'Quedan 35 h',
      );
    });

    test('la última hora, y los últimos minutos', () {
      expect(
        tiempoRestante(enviada, DateTime.utc(2026, 9, 30, 12, 30)),
        'Queda 1 h',
      );
      expect(
        tiempoRestante(enviada, DateTime.utc(2026, 9, 30, 13, 40)),
        'Quedan 20 min',
      );
      expect(
        tiempoRestante(enviada, DateTime.utc(2026, 9, 30, 13, 59, 30)),
        'Queda 1 min',
      );
    });

    test('pasado el plazo, demorada', () {
      expect(
        tiempoRestante(enviada, DateTime.utc(2026, 9, 30, 14)),
        'Demorada',
      );
      expect(estaDemorada(enviada, DateTime.utc(2026, 10, 1)), isTrue);

      final marcada = resumen({...consultaJson(), 'vencida': true});
      expect(
        tiempoRestante(marcada, DateTime.utc(2026, 9, 28, 15)),
        'Demorada',
      );
    });

    test(
      'se compara con el instante, esté el teléfono en la zona que esté',
      () {
        // Las 07:00 en Quito del 30 son las 12:00 UTC: quedan 2 h.
        final enQuito = DateTime.utc(2026, 9, 30, 12);
        expect(tiempoRestante(enviada, enQuito.toLocal()), 'Quedan 2 h');
      },
    );

    test('sin venceEn, las horas que dijo el servidor', () {
      final sinFecha = resumen({
        '_id': 'x',
        'estado': 'EN_REVISION',
        'horasRestantes': 12,
      });
      expect(tiempoRestante(sinFecha, DateTime.utc(2026)), 'Quedan 12 h');
    });

    test('fuera de ENVIADA y EN_REVISION no hay plazo', () {
      final ahora = DateTime.utc(2026, 9, 29);
      for (final estado in ['BORRADOR', 'RESPONDIDA', 'CERRADA', 'CANCELADA']) {
        expect(
          tiempoRestante(resumen(consultaJson(estado: estado)), ahora),
          isNull,
          reason: estado,
        );
      }
    });

    test('los momentos se dicen en la hora de la clínica', () {
      expect(
        momentoLegible(DateTime.utc(2026, 9, 30, 14)),
        'Miércoles 30 de septiembre, 09:00',
      );
      expect(
        selloLegible(DateTime.utc(2026, 9, 29, 3, 5)),
        '28/09/2026 · 22:05',
      );
    });
  });

  group('Novedades para el sondeo', () {
    final respondida = resumen(
      consultaJson(estado: 'RESPONDIDA', mensajes: [mensajeJson('m1')]),
    );

    test('igual estado, mensajes y último mensaje: nada nuevo', () {
      expect(hayNovedades(respondida, respondida), isFalse);
      expect(
        hayNovedades(
          respondida,
          // El mismo instante, escrito de otra forma.
          resumen({
            ...respondida.aJson(),
            'ultimoMensajeEn': '2026-09-28T11:00:00.000-05:00',
            'horasRestantes': 3,
            'medicoNombre': 'Otro nombre',
          }),
        ),
        isFalse,
        reason: 'solo cuentan el estado, los mensajes y el último mensaje',
      );
    });

    test('otro estado, otra cantidad de mensajes u otro último mensaje', () {
      expect(
        hayNovedades(respondida, resumen(consultaJson(estado: 'CERRADA'))),
        isTrue,
      );
      expect(
        hayNovedades(
          respondida,
          resumen({...respondida.aJson(), 'totalMensajes': 2}),
        ),
        isTrue,
      );
      expect(
        hayNovedades(
          respondida,
          resumen({
            ...respondida.aJson(),
            'ultimoMensajeEn': '2026-09-28T18:00:00.000Z',
          }),
        ),
        isTrue,
      );
      expect(
        hayNovedades(
          resumen(consultaJson()),
          resumen({
            ...consultaJson(),
            'ultimoMensajeEn': '2026-09-28T18:00:00.000Z',
          }),
        ),
        isTrue,
        reason: 'antes no había último mensaje',
      );
    });
  });

  group('El motivo de una cancelación', () {
    test('obligatorio y de hasta 500 caracteres, sin contar los espacios de '
        'los extremos', () {
      expect(maximoMotivoCancelacion, 500);
      expect(
        errorDelMotivoDeCancelacion('   '),
        'Cuéntanos por qué la cancelas.',
      );
      expect(errorDelMotivoDeCancelacion('Ya me siento mejor'), isNull);
      expect(errorDelMotivoDeCancelacion('  ${'a' * 500}  '), isNull);
      expect(
        errorDelMotivoDeCancelacion('a' * 501),
        'El motivo admite hasta 500 caracteres.',
      );
    });

    test('se cuenta como el servidor: un emoji vale por dos', () {
      expect(errorDelMotivoDeCancelacion('🙂' * 250), isNull);
      expect(errorDelMotivoDeCancelacion('🙂' * 251), isNotNull);
    });
  });

  group('La lista', () {
    final consultas = [
      resumen(consultaJson(id: 'b', estado: 'BORRADOR')),
      resumen(consultaJson(id: 'e')),
      resumen(
        consultaJson(id: 'r', estado: 'RESPONDIDA', ultimoEsMedico: true),
      ),
      resumen(consultaJson(id: 'x', estado: 'CANCELADA')),
      resumen(consultaJson(id: 'c', estado: 'CERRADA', ultimoEsMedico: true)),
    ];

    test('borradores, en curso (lo por leer primero) y terminadas', () {
      expect(borradores(consultas).map((c) => c.id), ['b']);
      expect(consultasEnCurso(consultas).map((c) => c.id), ['r', 'e']);
      expect(consultasTerminadas(consultas).map((c) => c.id), ['x', 'c']);
    });

    test('solo cuenta como por leer una respondida donde habló el médico', () {
      expect(respuestasPorLeer(consultas), 1);
    });
  });

  group('El formulario', () {
    test('lo requerido tiene que estar', () {
      final errores = erroresDelFormulario(
        campos: campos,
        respuestas: const {},
        descripcion: '',
        requiereAdjunto: true,
        adjuntos: 0,
      );

      expect(errores.keys, {
        'desde',
        'zona',
        'pica',
        claveDescripcion,
        claveAdjuntos,
      });
    });

    test('completo, sin errores', () {
      expect(
        erroresDelFormulario(
          campos: campos,
          respuestas: const {
            'desde': '2026-09-21',
            'zona': 'Brazos',
            'pica': false,
          },
          descripcion: 'Manchas rojas.',
          requiereAdjunto: true,
          adjuntos: 1,
        ),
        isEmpty,
      );
    });

    test('cada tipo se valida a su manera', () {
      CampoFormulario campo(String clave) =>
          campos.firstWhere((c) => c.clave == clave);

      expect(errorDelCampo(campo('tamano'), 'dos'), contains('en cm'));
      expect(errorDelCampo(campo('tamano'), '2,5'), isNull);
      expect(errorDelCampo(campo('tamano'), ''), isNull, reason: 'opcional');
      expect(errorDelCampo(campo('zona'), 'Espalda'), contains('opciones'));
      expect(errorDelCampo(campo('desde'), '2026-02-30'), isNotNull);
      expect(errorDelCampo(campo('pica'), 'sí'), isNotNull);
      expect(errorDelCampo(campo('pica'), false), isNull);
    });

    test('la descripción tiene tope', () {
      final errores = erroresDelFormulario(
        campos: const [],
        respuestas: const {},
        descripcion: 'a' * (maximoDescripcion + 1),
        requiereAdjunto: false,
        adjuntos: 0,
      );
      expect(errores[claveDescripcion], contains('$maximoDescripcion'));
    });

    test('al guardar un borrador, lo que se vació viaja como null', () {
      final api = respuestasParaApi(campos, const {
        'zona': 'Brazos',
        'notas': '   ',
      }, conVacias: true);

      expect(api['zona'], 'Brazos');
      expect(api['notas'], isNull);
      expect(api.containsKey('notas'), isTrue);
      expect(api.keys.toSet(), campos.map((c) => c.clave).toSet());
    });

    test('las respuestas viajan con su tipo, sin las vacías', () {
      final api = respuestasParaApi(campos, const {
        'desde': '2026-09-21',
        'zona': 'Brazos',
        'pica': true,
        'tamano': '2,5',
        'forma': '  redonda ',
        'notas': '   ',
        'ajena': 'no es del formulario',
      });

      expect(api, {
        'desde': '2026-09-21',
        'zona': 'Brazos',
        'pica': true,
        'tamano': 2.5,
        'forma': 'redonda',
      });
      expect(respuestasParaApi(campos, const {'tamano': '3'})['tamano'], 3);
      expect(
        respuestasParaApi(campos, const {'tamano': '3'})['tamano'],
        isA<int>(),
      );
    });

    test('un borrador vuelve a ser editable', () {
      final editables = respuestasEditables(const [
        RespuestaConsulta(
          clave: 'tamano',
          etiqueta: 'Tamaño',
          tipo: TipoCampo.numero,
          valor: 2.5,
        ),
        RespuestaConsulta(
          clave: 'pica',
          etiqueta: 'Pica',
          tipo: TipoCampo.siNo,
          valor: false,
        ),
        RespuestaConsulta(clave: 'forma', etiqueta: 'F', tipo: TipoCampo.texto),
      ]);

      expect(editables, {'tamano': '2,5', 'pica': false});
    });

    test('las respuestas se leen como se dicen', () {
      expect(valorLegible(TipoCampo.siNo, true), 'Sí');
      expect(valorLegible(TipoCampo.siNo, false), 'No');
      expect(valorLegible(TipoCampo.numero, 37.5, unidad: '°C'), '37,5 °C');
      expect(valorLegible(TipoCampo.numero, '2'), '2');
      expect(valorLegible(TipoCampo.fecha, '2026-09-21'), '21/09/2026');
      expect(valorLegible(TipoCampo.seleccion, 'Brazos'), 'Brazos');
      expect(valorLegible(TipoCampo.texto, null), 'Sin respuesta');
      expect(numeroDe('37.5'), 37.5);
      expect(numeroDe('1e3'), isNull);
    });
  });
}
