import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/arranque/arranque_seguro.dart';
import 'core/catalogos/catalogos_cubit.dart';
import 'core/configuracion/config_publica.dart';
import 'core/configuracion/config_publica_cubit.dart';
import 'core/fechas/zona_clinica.dart';
import 'core/network/api_client.dart';
import 'core/presentacion/rutas.dart';
import 'core/presentacion/widgets/barra_de_accion.dart';
import 'core/servicios.dart';
import 'core/tema/paleta_marca.dart';
import 'core/tema/tema_app.dart';
import 'features/arranque/presentacion/arranque_page.dart';
import 'features/arranque/presentacion/espera_datos_clinica.dart';
import 'features/auth/presentacion/login_page.dart';
import 'features/avisos/providers/campana_cubit.dart';
import 'features/auth/providers/auth_bloc.dart';
import 'features/auth/providers/auth_state.dart';
import 'features/citas/providers/citas_bloc.dart';
import 'features/citas/providers/citas_event.dart';
import 'features/consultas/providers/consultas_bloc.dart';
import 'features/consultas/providers/consultas_event.dart';
import 'features/dependientes/providers/dependientes_bloc.dart';
import 'features/encuestas/providers/encuestas_cubit.dart';
import 'features/inicio/presentacion/dashboard_page.dart';
import 'features/legal/presentacion/aceptacion_legal_page.dart';
import 'features/navegacion/presentacion/receptor_de_enlaces.dart';
import 'features/navegacion/providers/menu_cubit.dart';

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

    // La última configuración de la clínica, si hay: su zona horaria y los
    // colores de su marca desde el primer cuadro. La del servidor llega
    // después (ver `ConfigPublicaCubit`).
    await intentar('la configuración guardada', () async {
      final guardada = await Servicios.configuracion.guardada();
      if (guardada != null) aplicarConfiguracion(guardada.config);
    });

    // Los recordatorios se preparan antes de arrancar para que los ya
    // programados sobrevivan a un reinicio del teléfono.
    await intentar(
      'los recordatorios de citas',
      () => Servicios.recordatorios.inicializar(),
    );

    // Mientras no haya red, se vuelve a preguntar cada tanto: así el cartel
    // de sin conexión se va solo cuando vuelve.
    Servicios.red.vigilar();

    // Los enlaces de los correos (confirmar el correo, crear la contraseña
    // nueva) abren la aplicación: App Links y Universal Links. El primero
    // —el que abrió la aplicación— llega al empezar a escuchar.
    runApp(CliniqApp(enlacesEntrantes: AppLinks().uriLinkStream));
  }, (error, pila) => registrarFallo('el arranque', error, pila));
}

/// Lo que se hace con cada configuración que entra en uso: la zona horaria
/// de la clínica y los colores de su marca. Si los colores cambiaron con la
/// aplicación ya abierta, se vuelve a pintar entera (conservando dónde está
/// cada quien).
void aplicarConfiguracion(ConfigPublica config) {
  ZonaClinica.aplicar(config.clinica.zonaHoraria);

  final cambioLaMarca = PaletaMarca.aplicar(
    primario: config.clinica.colorPrimario,
    acento: config.clinica.colorAcento,
  );
  if (cambioLaMarca) repintarTodo();
}

/// Marca para reconstruir cada elemento del árbol. Los colores de la marca
/// no viven en el tema de Material sino en los tokens (`AppColors`), así que
/// cambiar el tema no basta: hay que volver a construir lo ya pintado. El
/// estado de cada pantalla se conserva.
void repintarTodo() {
  final binding = WidgetsBinding.instance;

  void marcar(Element elemento) {
    elemento.markNeedsBuild();
    elemento.visitChildren(marcar);
  }

  binding.addPostFrameCallback(
    (_) => binding.rootElement?.visitChildren(marcar),
  );
  binding.scheduleFrame();
}

/// La aplicación: los blocs compartidos y la puerta de entrada.
///
/// Los blocs que usan varias pantallas —la configuración y los catálogos de
/// la clínica, la sesión, las citas, las consultas en línea, los
/// dependientes, el menú, la campana de avisos y las encuestas por
/// responder— nacen aquí. Una pantalla que se abre por navegación
/// (agendar, una consulta nueva) crea el suyo para cargar datos frescos en
/// cada visita.
class CliniqApp extends StatelessWidget {
  /// Los enlaces de los correos que abren la aplicación (`app_links`). Sin
  /// ellos —en las pruebas—, no se escucha ninguno.
  final Stream<Uri>? enlacesEntrantes;

  const CliniqApp({super.key, this.enlacesEntrantes});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // La configuración y los catálogos son públicos: se piden al abrir,
        // antes de saber si hay sesión, porque el acceso ya los necesita.
        BlocProvider<ConfigPublicaCubit>(
          lazy: false,
          create: (_) => ConfigPublicaCubit(
            Servicios.configuracion,
            alAplicar: aplicarConfiguracion,
          )..cargar(),
        ),
        BlocProvider<CatalogosCubit>(
          lazy: false,
          create: (_) => CatalogosCubit(Servicios.catalogos)..cargar(),
        ),
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
          create: (context) => CitasBloc(
            citas: Servicios.citas,
            portal: Servicios.portal,
            recordatorios: Servicios.recordatorios,
            reloj: Servicios.reloj,
            config: () => context.read<ConfigPublicaCubit>().state.config,
            catalogos: () => context.read<CatalogosCubit>().state,
          ),
        ),
        BlocProvider<ConsultasBloc>(
          create: (_) => ConsultasBloc(Servicios.consultas),
        ),
        BlocProvider<DependientesBloc>(
          create: (_) => DependientesBloc(Servicios.dependientes),
        ),
        BlocProvider<MenuCubit>(create: (_) => MenuCubit(Servicios.menu)),
        BlocProvider<CampanaCubit>(
          create: (_) => CampanaCubit(Servicios.avisos),
        ),
        BlocProvider<EncuestasCubit>(
          create: (_) => EncuestasCubit(Servicios.encuestas),
        ),
      ],
      child: _DatosDeLaClinicaAlDia(
        child:
            BlocSelector<
              ConfigPublicaCubit,
              ConfigPublicaState,
              (String, String?, String?)
            >(
              // El nombre para el sistema y los colores de la marca para el
              // tema: si cambian, el tema se vuelve a armar.
              selector: (state) => (
                state.config?.clinica.nombre ?? '',
                state.config?.clinica.colorPrimario,
                state.config?.clinica.colorAcento,
              ),
              builder: (context, datos) => MaterialApp(
                title: datos.$1,
                debugShowCheckedModeBanner: false,
                theme: temaCliniq(),
                locale: const Locale('es'),
                supportedLocales: const [Locale('es'), Locale('es', 'EC')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                navigatorObservers: [observadorDeRutas],
                builder: (context, hijo) =>
                    CerrarTecladoAlTocarFuera(child: hijo ?? const SizedBox()),
                home: EsperaDatosDeLaClinica(
                  child: ReceptorDeEnlaces(
                    enlaces: enlacesEntrantes,
                    child: const PuertaDeEntrada(),
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

/// Mantiene al día la configuración y los catálogos.
///
/// Se vuelven a pedir cada vez que la aplicación vuelve al frente: si el
/// administrador cambió algo, se nota la próxima vez que se abre. Y cuando
/// cambian, los recordatorios de las citas se vuelven a programar con las
/// reglas y los textos nuevos (o se cancelan, si la clínica los apagó).
class _DatosDeLaClinicaAlDia extends StatefulWidget {
  final Widget child;

  const _DatosDeLaClinicaAlDia({required this.child});

  @override
  State<_DatosDeLaClinicaAlDia> createState() => _DatosDeLaClinicaAlDiaState();
}

class _DatosDeLaClinicaAlDiaState extends State<_DatosDeLaClinicaAlDia>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    unawaited(context.read<ConfigPublicaCubit>().cargar());
    unawaited(context.read<CatalogosCubit>().cargar());
  }

  void _revisarRecordatorios(BuildContext context) {
    context.read<CitasBloc>().add(const CitasRecordatoriosRevisados());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ConfigPublicaCubit, ConfigPublicaState>(
          listenWhen: (antes, ahora) =>
              ahora.config != null && antes.config != ahora.config,
          listener: (context, _) => _revisarRecordatorios(context),
        ),
        BlocListener<CatalogosCubit, CatalogosState>(
          listenWhen: (antes, ahora) => antes.listas != ahora.listas,
          listener: (context, _) => _revisarRecordatorios(context),
        ),
      ],
      child: widget.child,
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
        context.read<ConsultasBloc>().add(const ConsultasVaciadas());
        context.read<DependientesBloc>().add(const DependientesVaciados());
        context.read<MenuCubit>().vaciar();
        context.read<CampanaCubit>().activar(false);
        context.read<EncuestasCubit>().vaciar();
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
