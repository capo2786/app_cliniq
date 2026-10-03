// test/ficha_medicion_test.dart
//
// La lógica pura de «Detalle de la medición»: el caso de cada medición, la
// otra del mismo escaneo, las tarjetas, el origen, las notas, los datos de
// un aparato, un envío pendiente y la ruta.

import 'package:app_cliniq/features/mediciones/data/cola_mediciones.dart';
import 'package:app_cliniq/features/mediciones/data/models/medicion.dart';
import 'package:app_cliniq/features/mediciones/dominio/detalle_medicion.dart';
import 'package:app_cliniq/features/mediciones/presentacion/detalle/ficha_medicion.dart';
import 'package:app_cliniq/features/navegacion/dominio/destinos.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/detalle_medicion.dart';
import 'dobles/mediciones.dart';

void main() {
  late DetalleMedicion detalle;

  setUpAll(() => detalle = detalleMedido());

  group('La lógica de la pantalla', () {
    final pulso = Medicion.desdeJson(pulsoEnLista())!;
    final respiracion = Medicion.desdeJson(respiracionEnLista())!;
    final presion = Medicion.desdeJson(medicionJson(id: 'pa1'))!;

    test('el caso de cada medición', () {
      expect(casoDe(presion), CasoDeDetalle.aparato);
      expect(casoDe(pulso), CasoDeDetalle.detalleSinCargar);
      expect(hayQuePedirla(pulso), isTrue);
      expect(hayQuePedirla(presion), isFalse);
      expect(hayQuePedirla(null), isTrue);
      final anterior = Medicion.desdeJson(pulsoEnLista(tieneDetalle: false))!;
      expect(casoDe(anterior), CasoDeDetalle.anteriorAlDetalle);
      expect(casoDe(respiracion), CasoDeDetalle.respiracionDeCamara);
      final completa = Medicion.desdeJson(
        pulsoEnLista()..['detalle'] = detalle.aJson(),
      )!;
      expect(casoDe(completa), CasoDeDetalle.conDetalle);
      expect(hayQuePedirla(completa), isFalse);
    });

    test('la compañera es la del mismo escaneo', () {
      expect(companeraDe(pulso, [presion, respiracion, pulso]), respiracion);
      expect(companeraDe(respiracion, [pulso]), pulso);
      expect(companeraDe(presion, [pulso, respiracion]), isNull);
      final otraHora = Medicion.desdeJson(
        respiracionEnLista()..['medidoEn'] = '2026-10-02T15:00:00.000Z',
      )!;
      expect(companeraDe(pulso, [otraHora]), isNull);
    });

    test('las tarjetas: FC y FR del escaneo, la calidad y la variabilidad '
        'del teléfono solo si es válida', () {
      final v = valoresDeTarjetas(pulso, companera: respiracion);
      expect((v.fc, v.fr, v.calidad, v.vfc), (72, 15, 0.86, null));

      final completa = Medicion.desdeJson(
        pulsoEnLista()..['detalle'] = detalle.aJson(),
      )!;
      final conVfc = valoresDeTarjetas(completa);
      expect(detalle.vfcValida, isTrue);
      expect(conVfc.vfc!.rmssd, closeTo(detalle.metricas!.rmssd, 0.06));
      expect(conVfc.fr, isNull);
    });

    test('el origen, las notas y los datos de un aparato', () {
      expect(
        origenDelAnalisis('motor: senales-ms 1.0.0'),
        'Analizado en el servidor (experimental)',
      );
      expect(
        origenDelAnalisis('motor: interno-pos v1'),
        'Calculado en el '
        'teléfono',
      );
      expect(origenDelAnalisis('Después de caminar'), isNull);
      expect(notasVisibles('motor: interno-ppg v1'), isNull);
      expect(notasVisibles(' Después de caminar '), 'Después de caminar');

      expect(datosDeMedicion(presion), [
        ('Sistólica (la alta)', '128 mmHg'),
        ('Diastólica (la baja)', '82 mmHg'),
        ('Referencia', 'Alta'),
        ('Momento', 'En reposo'),
        ('Cómo se midió', 'Aparato de casa'),
      ]);
    });

    test('un envío pendiente: primero el pulso con su detalle', () {
      final envio = EnvioPendiente(
        idLocal: 'local1',
        creadoEn: DateTime.utc(2026, 10, 3),
        mediciones: [
          MedicionNueva(
            tipo: TipoMedicion.fr,
            valor: 15,
            metodo: MetodoMedicion.camaraDedo,
            medidoEn: DateTime.utc(2026, 10, 3, 15),
          ),
          MedicionNueva(
            tipo: TipoMedicion.fc,
            valor: 72,
            metodo: MetodoMedicion.camaraDedo,
            medidoEn: DateTime.utc(2026, 10, 3, 15),
            detalle: detalle,
          ),
        ],
      );
      final mediciones = medicionesDelEnvio(envio);
      expect(mediciones.first.tipo, TipoMedicion.fc);
      expect(mediciones.first.detalle, detalle);
      expect(companeraDe(mediciones.first, mediciones)!.tipo, TipoMedicion.fr);
    });

    test('la ruta /portal/mediciones/:id abre el detalle', () {
      expect(
        destinoDeRuta('/portal/mediciones/fc1'),
        const DestinoNativo(PantallaNativa.medicion, {'id': 'fc1'}),
      );
      expect(
        destinoDeRuta('/portal/mediciones'),
        const DestinoNativo(PantallaNativa.mediciones),
      );
    });
  });
}
