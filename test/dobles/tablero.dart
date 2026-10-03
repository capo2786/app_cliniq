// test/dobles/tablero.dart

import 'package:app_cliniq/core/catalogos/catalogos_cubit.dart';
import 'package:app_cliniq/core/storage/almacen_claves.dart';
import 'package:app_cliniq/core/storage/cache_local.dart';
import 'package:app_cliniq/core/storage/credenciales_service.dart';
import 'package:app_cliniq/core/tema/tema_app.dart';
import 'package:app_cliniq/features/auth/data/almacen_de_sesion.dart';
import 'package:app_cliniq/features/auth/data/models/usuario.dart';
import 'package:app_cliniq/features/auth/providers/auth_bloc.dart';
import 'package:app_cliniq/features/auth/providers/auth_state.dart';
import 'package:app_cliniq/features/avisos/data/avisos_service.dart';
import 'package:app_cliniq/features/avisos/providers/campana_cubit.dart';
import 'package:app_cliniq/features/ayuda/data/ayuda_contextual_service.dart';
import 'package:app_cliniq/features/ayuda/providers/ayuda_contextual_cubit.dart';
import 'package:app_cliniq/features/citas/data/citas_service.dart';
import 'package:app_cliniq/features/citas/providers/citas_bloc.dart';
import 'package:app_cliniq/features/consultas/providers/consultas_bloc.dart';
import 'package:app_cliniq/features/dependientes/providers/dependientes_bloc.dart';
import 'package:app_cliniq/features/encuestas/data/encuestas_service.dart';
import 'package:app_cliniq/features/encuestas/providers/encuestas_cubit.dart';
import 'package:app_cliniq/features/inicio/presentacion/dashboard_page.dart';
import 'package:app_cliniq/features/navegacion/data/menu_service.dart';
import 'package:app_cliniq/features/navegacion/providers/menu_cubit.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'clinica.dart';
import 'consultas.dart';
import 'dobles.dart';

/// Monta el tablero (`DashboardPage`) con la sesión ya abierta, como la deja
/// el acceso, y los blocs que comparten las pestañas, todos contra la API de
/// mentira [dio] y la caché [cache]. En un teléfono de tamaño común.
///
/// La campana no late sola: sus latidos se prueban aparte.
Future<void> montarTablero(
  WidgetTester tester, {
  required Dio dio,
  required CacheLocal cache,
  Usuario? usuario,
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
  )..emit(AuthAutenticado(usuario ?? usuarioDePrueba()));
  addTearDown(auth.close);

  await tester.pumpWidget(
    conDatosDeLaClinica(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: auth),
          BlocProvider(create: (_) => MenuCubit(MenuService(dio, cache))),
          BlocProvider(
            create: (context) => CitasBloc(
              citas: CitasService(dio, CacheEnMemoria()),
              portal: PortalFalso(),
              recordatorios: ProgramadorFalso(),
              config: configDePrueba,
              catalogos: () => context.read<CatalogosCubit>().state,
            ),
          ),
          BlocProvider(create: (_) => ConsultasBloc(ConsultasFalso())),
          BlocProvider(create: (_) => DependientesBloc(DependientesFalso())),
          BlocProvider(
            create: (_) => CampanaCubit(
              AvisosService(dio, cache),
              latidos: () => const Stream.empty(),
            ),
          ),
          BlocProvider(
            create: (_) => EncuestasCubit(EncuestasService(dio, cache)),
          ),
          BlocProvider(
            create: (_) =>
                AyudaContextualCubit(AyudaContextualService(dio, cache)),
          ),
        ],
        child: MaterialApp(theme: temaCliniq(), home: const DashboardPage()),
      ),
    ),
  );
}
