// test/envio_pendientes_test.dart
//
// Lo registrado sin red sale solo: al montarse con la sesión abierta y en
// cuanto vuelve la conexión.

import 'package:app_cliniq/core/red/estado_de_la_red.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/features/mediciones/data/cola_mediciones.dart';
import 'package:app_cliniq/features/mediciones/data/mediciones_service.dart';
import 'package:app_cliniq/features/mediciones/presentacion/envio_de_pendientes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dobles/clinica.dart';
import 'dobles/dio_grabador.dart';
import 'dobles/dobles.dart';
import 'dobles/esperas.dart';
import 'dobles/mediciones.dart';
import 'dobles/pantalla.dart';

void main() {
  testWidgets('envía lo pendiente al entrar y al volver la red', (
    tester,
  ) async {
    sondeoConRed();
    final red = SondeoDeRed();
    final cache = CacheEnMemoria();
    var hayRed = false;
    final api = DioGrabador({
      'POST /portal/mediciones': (_) {
        if (!hayRed) throw errorDeRed();
        return {'mediciones': <Object>[]};
      },
    });
    final cola = ColaMediciones(cache, MedicionesService(api.dio, cache));

    // Dos registros sin red: quedan en el teléfono.
    await tester.runAsync(() async {
      await cola.registrar('u1', mediciones: [medicionNueva()]);
      await cola.registrar('u1', mediciones: [medicionNueva(valor: 80)]);
    });
    api.pedidos.clear();

    await montarPantalla(
      tester,
      EnvioDeMedicionesPendientes(
        cola: cola,
        red: red,
        child: const Scaffold(body: Text('Inicio')),
      ),
    );
    // Al montarse lo intentó, pero seguía sin red.
    await esperarHasta(tester, () => api.claves.isNotEmpty);
    expect(api.claves, ['POST /portal/mediciones']);
    expect(await tester.runAsync(() => cola.pendientes('u1')), hasLength(2));

    hayRed = true;
    red.actual.value = const EstadoDeLaRed(MotivoDeRed.sinRed);
    red.anotarExito();
    await esperarHasta(tester, () => api.claves.length == 3);

    expect(await tester.runAsync(() => cola.pendientes('u1')), isEmpty);
    expect(
      api.claves.where((c) => c == 'POST /portal/mediciones'),
      hasLength(3),
    );
  });
}
