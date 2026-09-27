// test/dobles/pantalla.dart

/// Montar una pantalla suelta como la ve la aplicación después de entrar:
/// con la sesión abierta, la configuración y los catálogos de la clínica y
/// el tema.
library;

import 'package:app_cliniq/core/configuracion/config_publica.dart';
import 'package:app_cliniq/core/catalogos/catalogos_cubit.dart';
import 'package:app_cliniq/core/storage/almacen_claves.dart';
import 'package:app_cliniq/core/storage/credenciales_service.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/auth/data/almacen_de_sesion.dart';
import 'package:app_cliniq/features/auth/data/models/usuario.dart';
import 'package:app_cliniq/features/auth/providers/auth_bloc.dart';
import 'package:app_cliniq/features/auth/providers/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'clinica.dart';
import 'dobles.dart';

/// Una paciente con todos los permisos del portal.
Usuario pacienteDePrueba({List<String>? permisos}) => Usuario({
  'uid': 'u1',
  'nombre': 'Ana María Pérez',
  'email': 'ana@correo.com',
  'role': 3,
  'roles': ['PACIENTE'],
  'permisos':
      permisos ??
      [
        Permisos.misCitas,
        Permisos.agendar,
        Permisos.dependientes,
        Permisos.consultas,
        'portal.mi_salud',
      ],
  'legalPendientes': <String>[],
});

/// Pinta [pagina] con la sesión de [usuario] abierta, en un teléfono de
/// tamaño normal. Devuelve el `AuthBloc`, por si la prueba lo necesita.
Future<AuthBloc> montarPantalla(
  WidgetTester tester,
  Widget pagina, {
  Usuario? usuario,
  ConfigPublica? config,
  CatalogosState? catalogos,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);

  final llavero = AlmacenClavesEnMemoria();
  final auth = AuthBloc(
    servicio: AuthServiceFalso(),
    almacen: AlmacenDeSesion(llavero),
    credenciales: CredencialesService(llavero),
    fijarToken: (_) {},
    restaurarAlCrear: false,
  )..emit(AuthAutenticado(usuario ?? pacienteDePrueba()));
  addTearDown(auth.close);

  await tester.pumpWidget(
    conDatosDeLaClinica(
      config: config,
      catalogos: catalogos,
      BlocProvider.value(
        value: auth,
        child: MaterialApp(theme: temaCliniq(), home: pagina),
      ),
    ),
  );

  return auth;
}
