import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/arranque/arranque_seguro.dart';
import 'core/catalogos/catalogos_cubit.dart';
import 'core/network/api_client.dart';
import 'core/servicios.dart';
import 'core/tema/tema_app.dart';
import 'features/arranque/presentacion/arranque_page.dart';
import 'features/auth/presentacion/login_page.dart';
import 'features/auth/providers/auth_bloc.dart';
import 'features/auth/providers/auth_state.dart';
import 'features/citas/providers/citas_bloc.dart';
import 'features/citas/providers/citas_event.dart';
import 'features/dependientes/providers/dependientes_bloc.dart';
import 'features/inicio/presentacion/dashboard_page.dart';
import 'features/legal/presentacion/aceptacion_legal_page.dart';

/*
 * El arranque no puede quedarse a medias en silencio.
 *
 * Cada paso va protegido: ninguno puede impedir que la aplicación abra, y lo
 * que falle queda escrito en el registro del sistema para poder leerlo con
 * `adb logcat`. Sin esto, en release una excepción antes de `runApp` es una
 * pantalla en negro y un reporte que dice «no abre».
 */
void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    vigilarErrores();

    await intentar(
      'los formatos de fecha en español',
      () => initializeDateFormatting('es'),
    );

    // La caché cifrada se abre antes de pintar para que el inicio pueda
    // enseñar las citas guardadas desde el primer cuadro.
    await intentar('la caché local', () => Servicios.cache.inicializar());

    // Los recordatorios se preparan antes de arrancar para que los ya
    // programados sobrevivan a un reinicio del teléfono.
    await intentar(
      'los recordatorios de citas',
      () => Servicios.recordatorios.inicializar(),
    );

    // Mientras no haya red, se vuelve a preguntar cada tanto: así el cartel
    // de sin conexión se va solo cuando vuelve.
    Servicios.red.vigilar();

    runApp(const CliniqApp());
  }, (error, pila) => registrarFallo('el arranque', error, pila));
}

/// La aplicación: los blocs compartidos y la puerta de entrada.
///
/// Los blocs que usan varias pestañas —la sesión, las citas, los
/// dependientes y los catálogos— nacen aquí. Una pantalla que se abre por
/// navegación (agendar) crea el suyo para cargar datos frescos en cada
/// visita.
class CliniqApp extends StatelessWidget {
  const CliniqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(
            servicio: Servicios.auth,
            almacen: Servicios.sesion,
            credenciales: Servicios.credenciales,
            fijarToken: (token) => ApiClient().token = token,
            sesionVencida: ApiClient().sesionVencida,
            limpiarDatosLocales: Servicios.limpiarDatosLocales,
          ),
        ),
        BlocProvider<CitasBloc>(
          create: (_) => CitasBloc(
            citas: Servicios.citas,
            portal: Servicios.portal,
            recordatorios: Servicios.recordatorios,
            reloj: Servicios.reloj,
          ),
        ),
        BlocProvider<DependientesBloc>(
          create: (_) => DependientesBloc(Servicios.dependientes),
        ),
        BlocProvider<CatalogosCubit>(
          create: (_) => CatalogosCubit(Servicios.catalogos),
        ),
      ],
      child: MaterialApp(
        title: 'Cliniq',
        debugShowCheckedModeBanner: false,
        theme: temaCliniq(),
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('es', 'EC')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const PuertaDeEntrada(),
      ),
    );
  }
}

/// A dónde va la persona según su sesión.
enum _Destino { arranque, acceso, legales, inicio }

/// Decide qué pantalla se ve: arranque, acceso, aceptación legal o inicio.
///
/// Es declarativa a propósito: la sesión dice dónde se está, y cuando cambia
/// —se venció, se cerró, se aceptaron los legales— la pantalla cambia sola,
/// sin que cada botón tenga que acordarse de navegar a mano.
class PuertaDeEntrada extends StatelessWidget {
  const PuertaDeEntrada({super.key});

  static _Destino _destino(AuthState state) => switch (state) {
    AuthInicial() => _Destino.arranque,
    AuthAutenticado(:final usuario) =>
      usuario.tieneLegalesPendientes ? _Destino.legales : _Destino.inicio,
    _ => _Destino.acceso,
  };

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (antes, ahora) =>
          antes is AuthAutenticado && ahora is! AuthAutenticado,
      listener: (context, state) {
        // Al salir —a mano o por sesión vencida— se cierran las pantallas que
        // quedaran abiertas encima y se olvida lo de la persona anterior.
        Navigator.of(context).popUntil((ruta) => ruta.isFirst);
        context.read<CitasBloc>().add(const CitasVaciadas());
        context.read<DependientesBloc>().add(const DependientesVaciados());
      },
      buildWhen: (antes, ahora) => _destino(antes) != _destino(ahora),
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: switch (_destino(state)) {
            _Destino.arranque => const ArranquePage(key: ValueKey('arranque')),
            _Destino.acceso => const LoginPage(key: ValueKey('acceso')),
            _Destino.legales => const AceptacionLegalPage(
              key: ValueKey('legales'),
            ),
            _Destino.inicio => const DashboardPage(key: ValueKey('inicio')),
          },
        );
      },
    );
  }
}
