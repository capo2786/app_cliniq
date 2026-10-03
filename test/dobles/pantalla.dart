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
import 'package:app_cliniq/features/ayuda/data/ayuda_contextual_service.dart';
import 'package:app_cliniq/features/ayuda/data/models/ayuda_de_accion.dart';
import 'package:app_cliniq/features/ayuda/providers/ayuda_contextual_cubit.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:dio/dio.dart';
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
///
/// Con [ayuda], los textos de los botones de ayuda ya cargados (como los
/// deja `GET /ayuda/contextual`); sin él, no hay textos y los botones no se
/// enseñan.
Future<AuthBloc> montarPantalla(
  WidgetTester tester,
  Widget pagina, {
  Usuario? usuario,
  ConfigPublica? config,
  CatalogosState? catalogos,
  Map<String, AyudaDeAccion>? ayuda,
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

  final textos = ayuda == null
      ? null
      : AyudaContextualCubit(
          AyudaContextualService(Dio(), CacheEnMemoria()),
          inicial: AyudaContextualState(uid: 'u1', mapa: ayuda, alDia: true),
        );
  if (textos != null) addTearDown(textos.close);

  await tester.pumpWidget(
    conDatosDeLaClinica(
      config: config,
      catalogos: catalogos,
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: auth),
          if (textos != null) BlocProvider.value(value: textos),
        ],
        child: MaterialApp(theme: temaCliniq(), home: pagina),
      ),
    ),
  );

  return auth;
}
