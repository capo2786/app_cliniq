// test/recordatorios_test.dart

import 'package:app_cliniq/core/catalogos/catalogo_service.dart';
import 'package:app_cliniq/core/configuracion/config_publica.dart';
import 'package:app_cliniq/core/notificaciones/recordatorios_citas.dart';
import 'package:app_cliniq/features/citas/data/models/cita.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';

/// Los recordatorios locales: los que la clínica tiene encendidos, con los
/// textos de sus catálogos.
void main() {
  Cita cita(
    String id,
    DateTime inicio, {
    EstadoCita estado = EstadoCita.programada,
  }) {
    return Cita(
      id: id,
      inicio: inicio,
      fin: inicio.add(const Duration(minutes: 30)),
      tipo: TipoCita.telemedicina,
      estado: estado,
      doctorId: 'doc',
      medico: 'Ana Pérez',
    );
  }

  final ahora = DateTime(2026, 9, 28, 9);
  final catalogos = catalogosDePrueba();

  List<Recordatorio> para(List<Cita> citas, {ReglasAgenda? agenda}) =>
      recordatoriosPara(
        citas,
        ahora,
        agenda: agenda ?? configDePrueba().agenda,
        catalogos: catalogos,
      );

  test('con 24 h y 1 h encendidos: un día y una hora antes', () {
    final avisos = para([cita('a', DateTime(2026, 9, 30, 10))]);

    expect(avisos.map((r) => r.momento), [
      DateTime(2026, 9, 29, 10),
      DateTime(2026, 9, 30, 9),
    ]);
    expect(avisos.first.titulo, 'Mañana hay cita');
    expect(avisos.last.cuerpo, contains('Ana Pérez'));
    expect(avisos.last.cuerpo, isNot(contains('Dr(a).')));
  });

  test(
    'el texto usa el nombre de la modalidad y los consejos del catálogo',
    () {
      final lote = catalogosJson();
      lote[Catalogos.modalidadCita]![1]['nombre'] = 'Videoconsulta';
      lote[Catalogos.preparacionCita] = [
        {'codigo': 'TELEMEDICINA_1', 'nombre': 'Usa audífonos.'},
        {'codigo': 'TELEMEDICINA_2', 'nombre': 'Carga el teléfono.'},
        {'codigo': 'PRESENCIAL_1', 'nombre': 'Llega temprano.'},
      ];

      final aviso = recordatoriosPara(
        [cita('a', DateTime(2026, 9, 30, 10))],
        ahora,
        agenda: configDePrueba().agenda,
        catalogos: catalogosDePrueba(lote),
      ).last;

      expect(
        aviso.cuerpo,
        '10:00 · Ana Pérez · Videoconsulta. Usa audífonos. Carga el teléfono.',
      );
    },
  );

  test('sin consejos en el catálogo, el aviso no inventa ninguno', () {
    final lote = catalogosJson()..[Catalogos.preparacionCita] = [];

    final aviso = recordatoriosPara(
      [cita('a', DateTime(2026, 9, 30, 10))],
      ahora,
      agenda: configDePrueba().agenda,
      catalogos: catalogosDePrueba(lote),
    ).last;

    expect(aviso.cuerpo, '10:00 · Ana Pérez · Telemedicina');
  });

  test('con los recordatorios apagados en la clínica, ninguno', () {
    final avisos = para([
      cita('a', DateTime(2026, 9, 30, 10)),
    ], agenda: configDePrueba(agenda: {'recordatoriosActivos': false}).agenda);

    expect(avisos, isEmpty);
  });

  test('solo los encendidos: sin el de 24 h, con el del inicio', () {
    final avisos = para(
      [cita('a', DateTime(2026, 9, 30, 10))],
      agenda: configDePrueba(
        agenda: {'recordatorio24h': false, 'recordatorioInicio': true},
      ).agenda,
    );

    expect(avisos.map((r) => r.momento), [
      DateTime(2026, 9, 30, 9),
      DateTime(2026, 9, 30, 10),
    ]);
    expect(avisos.last.titulo, 'La cita empieza ahora');
  });

  test('el aviso cuya hora ya pasó no se programa', () {
    // Faltan 5 horas: el de 24 h ya pasó, el de 1 h no.
    final avisos = para([cita('a', DateTime(2026, 9, 28, 14))]);

    expect(avisos, hasLength(1));
    expect(avisos.single.momento, DateTime(2026, 9, 28, 13));
  });

  test('ni citas pasadas ni canceladas', () {
    final avisos = para([
      cita('pasada', DateTime(2026, 9, 27, 9)),
      cita('cancelada', DateTime(2026, 10, 5, 9), estado: EstadoCita.cancelada),
    ]);

    expect(avisos, isEmpty);
  });

  test('las citas de un dependiente dicen de quién son', () {
    final deHijo = Cita(
      id: 'h',
      inicio: DateTime(2026, 9, 30, 10),
      fin: DateTime(2026, 9, 30, 10, 30),
      tipo: TipoCita.presencial,
      estado: EstadoCita.programada,
      doctorId: 'doc',
      pacienteNombre: 'Tomás',
      paraDependiente: true,
    );

    expect(para([deHijo]).first.titulo, 'Mañana hay cita de Tomás');
  });

  test('lo que se le promete a la persona sigue a la configuración', () {
    expect(
      textoDeRecordatorios(configDePrueba().agenda),
      'Te recordaremos un día antes y una hora antes.',
    );
    expect(
      textoDeRecordatorios(
        configDePrueba(agenda: {'recordatorioInicio': true}).agenda,
      ),
      'Te recordaremos un día antes, una hora antes y al empezar.',
    );
    expect(
      textoDeRecordatorios(
        configDePrueba(agenda: {'recordatoriosActivos': false}).agenda,
      ),
      isNull,
    );
  });

  test('identificadores estables, distintos y dentro de su rango', () {
    final a1 = identificadorDeRecordatorio('abc', AntelacionRecordatorio.unDia);
    final a2 = identificadorDeRecordatorio('abc', AntelacionRecordatorio.unDia);
    final b = identificadorDeRecordatorio(
      'abc',
      AntelacionRecordatorio.unaHora,
    );
    final c = identificadorDeRecordatorio(
      'abc',
      AntelacionRecordatorio.alInicio,
    );

    expect(a1, a2);
    expect({a1, b, c}, hasLength(3));
    for (final id in [a1, b, c]) {
      expect(id, greaterThanOrEqualTo(idBaseRecordatorios));
      expect(id, lessThan(idBaseRecordatorios + anchoRangoRecordatorios));
    }
  });
}
