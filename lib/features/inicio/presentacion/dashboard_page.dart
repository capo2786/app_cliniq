// lib/features/inicio/presentacion/dashboard_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/presentacion/enlaces.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/visual_del_servidor.dart';
import '../../../core/presentacion/widgets/cerrar_sesion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../agendar/presentacion/agendar_page.dart';
import '../../auth/data/models/usuario.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../auth/providers/auth_event.dart';
import '../../citas/presentacion/citas_page.dart';
import '../../citas/providers/citas_bloc.dart';
import '../../citas/providers/citas_event.dart';
import '../../consultas/presentacion/consultas_page.dart';
import '../../consultas/providers/consultas_bloc.dart';
import '../../consultas/providers/consultas_event.dart';
import '../../dependientes/presentacion/dependientes_page.dart';
import '../../dependientes/providers/dependientes_bloc.dart';
import '../../navegacion/data/menu_service.dart';
import '../../navegacion/dominio/destinos.dart';
import '../../navegacion/providers/menu_cubit.dart';
import '../../perfil/presentacion/perfil_page.dart';
import 'inicio_page.dart';

/// Las pantallas que viven como pestaña (las demás se abren encima).
const Set<PantallaNativa> pantallasDePestana = {
  PantallaNativa.inicio,
  PantallaNativa.citas,
  PantallaNativa.dependientes,
  PantallaNativa.consultas,
  PantallaNativa.perfil,
};

/// La estructura de la aplicación con sesión: las pestañas de abajo.
///
/// La barra la arma el menú del servidor (`GET /menus/mi-menu?plataforma=
/// APP`): los cuatro primeros enlaces, por su orden, más «Perfil», que
/// siempre está; el resto va a «Accesos rápidos» del inicio. Cada enlace
/// lleva el nombre, el icono y el color que eligió el administrador. Una
/// ruta que la aplicación conoce abre su pantalla; una que no conoce se abre
/// en el navegador, en el panel web.
///
/// Aquí nacen también las cargas de todo lo que comparten las pestañas
/// —citas, consultas en línea, dependientes y el menú— y los recordatorios,
/// y se vuelven a pedir al regresar a la aplicación.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  PantallaNativa _actual = PantallaNativa.inicio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sincronizar();

      // El permiso de notificaciones se pide aquí, ya dentro: pedirlo en el
      // acceso, antes de saber para qué, es la forma más segura de que lo
      // nieguen.
      unawaited(Servicios.recordatorios.solicitarPermiso());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Servicios.red.olvidar();
      unawaited(Servicios.red.estado());
      context.read<AuthBloc>().add(const AuthPerfilRefrescado());
      _sincronizar();
    }
  }

  void _sincronizar() {
    if (!mounted) return;

    final usuario = context.read<AuthBloc>().usuario;
    if (usuario == null) return;

    unawaited(context.read<MenuCubit>().cargar(usuario.uid));

    if (usuario.puede(Permisos.misCitas)) {
      context.read<CitasBloc>().add(CitasSolicitadas(usuario.uid));
    }

    if (usuario.puede(Permisos.consultas)) {
      context.read<ConsultasBloc>().add(ConsultasSolicitadas(usuario.uid));
    }

    if (usuario.puede(Permisos.dependientes)) {
      context.read<DependientesBloc>().add(
        DependientesSolicitados(usuario.uid),
      );
    }
  }

  /// Las pestañas que hay: el inicio siempre (es la portada, con los accesos
  /// rápidos), las pantallas de la barra en su orden y el perfil al final.
  List<PantallaNativa> _pestanas(NavegacionDeLaApp navegacion) {
    final pestanas = <PantallaNativa>[PantallaNativa.inicio];

    for (final enlace in navegacion.barra) {
      if (destinoDe(enlace) case DestinoNativo(:final pantalla)
          when pantallasDePestana.contains(pantalla) &&
              !pestanas.contains(pantalla)) {
        pestanas.add(pantalla);
      }
    }

    return pestanas..add(PantallaNativa.perfil);
  }

  /// Abre una pantalla de la aplicación: su pestaña si la tiene; si no,
  /// encima (agendar siempre va encima, es un recorrido).
  void _abrir(PantallaNativa pantalla, List<PantallaNativa> pestanas) {
    if (pantalla != PantallaNativa.agendar && pestanas.contains(pantalla)) {
      setState(() => _actual = pantalla);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _pagina(pantalla, pestanas)),
    );
  }

  void _abrirEnlace(EnlaceMenu enlace, List<PantallaNativa> pestanas) {
    switch (destinoDe(enlace)) {
      case DestinoNativo(:final pantalla):
        _abrir(pantalla, pestanas);
      case DestinoWeb(:final url):
        unawaited(abrirEnlace(context, url, queEs: '«${enlace.label}»'));
    }
  }

  Widget _pagina(PantallaNativa pantalla, List<PantallaNativa> pestanas) {
    return switch (pantalla) {
      PantallaNativa.inicio => const SizedBox.shrink(),
      PantallaNativa.citas => CitasPage(
        alAgendar: () => _abrir(PantallaNativa.agendar, pestanas),
      ),
      PantallaNativa.agendar => const AgendarPage(),
      PantallaNativa.dependientes => const DependientesPage(),
      PantallaNativa.consultas => const ConsultasPage(),
      PantallaNativa.perfil => const PerfilPage(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final menu = context.watch<MenuCubit>().state;
    final enlaces = menu.enlaces;

    if (enlaces == null) {
      final error = menu.error;

      return _SinMenu(
        error: menu.cargando ? null : error,
        alReintentar: _sincronizar,
      );
    }

    final navegacion = NavegacionDeLaApp.desde(enlaces);
    final pestanas = _pestanas(navegacion);
    final actual = pestanas.contains(_actual) ? _actual : pestanas.first;

    return Scaffold(
      body: IndexedStack(
        index: pestanas.indexOf(actual),
        children: [
          // Con su clave: si el administrador reordena el menú, cada
          // pantalla conserva su estado y no el de la que estaba antes ahí.
          for (final pantalla in pestanas)
            KeyedSubtree(
              key: ValueKey(pantalla),
              child: pantalla == PantallaNativa.inicio
                  ? InicioPage(
                      accesos: navegacion.accesos,
                      alAbrirEnlace: (e) => _abrirEnlace(e, pestanas),
                      alAbrir: (p) => _abrir(p, pestanas),
                    )
                  : _pagina(pantalla, pestanas),
            ),
        ],
      ),
      bottomNavigationBar: _BarraInferior(
        pestanas: [
          for (final enlace in navegacion.barra)
            _Pestana.deEnlace(
              enlace,
              activa: destinoDe(enlace) == DestinoNativo(actual),
              alTocar: () => _abrirEnlace(enlace, pestanas),
            ),
          _Pestana(
            clave: const Key('pestana-perfil'),
            etiqueta: 'Perfil',
            icono: Icons.person_outline_rounded,
            activa: actual == PantallaNativa.perfil,
            alTocar: () => _abrir(PantallaNativa.perfil, pestanas),
          ),
        ],
      ),
    );
  }
}

/// Mientras llega el menú, o si no se pudo traer y no hay copia.
class _SinMenu extends StatelessWidget {
  final String? error;
  final VoidCallback alReintentar;

  const _SinMenu({required this.error, required this.alReintentar});

  @override
  Widget build(BuildContext context) {
    final error = this.error;

    return Scaffold(
      backgroundColor: AppColors.fondo,
      appBar: AppBar(actions: const [BotonCerrarSesion(), SizedBox(width: 6)]),
      body: FondoDegradado(
        child: ListView(
          padding: context.margenDeScroll(superior: 40),
          children: [
            if (error == null)
              const CargandoCentro(mensaje: 'Preparando tu menú…')
            else
              EstadoError(
                key: const Key('sin-menu'),
                mensaje: error,
                alReintentar: alReintentar,
              ),
          ],
        ),
      ),
    );
  }
}

/// Una pestaña de la barra.
class _Pestana {
  final String etiqueta;
  final IconData icono;

  /// El color del administrador, o `null` para el del tema.
  final Color? color;
  final bool activa;

  /// Agendar va destacado en la barra: es la razón de ser de la aplicación.
  final bool destacada;
  final VoidCallback alTocar;

  /// Para encontrarla en las pruebas: `pestana-<key del enlace>`.
  final Key clave;

  const _Pestana({
    required this.clave,
    required this.etiqueta,
    required this.icono,
    required this.activa,
    required this.alTocar,
    this.color,
    this.destacada = false,
  });

  factory _Pestana.deEnlace(
    EnlaceMenu enlace, {
    required bool activa,
    required VoidCallback alTocar,
  }) => _Pestana(
    clave: Key('pestana-${enlace.key}'),
    etiqueta: enlace.label,
    icono: iconoDelServidor(enlace.icon),
    color: colorDelServidor(enlace.color),
    activa: activa,
    destacada: destinoDe(enlace) == const DestinoNativo(PantallaNativa.agendar),
    alTocar: alTocar,
  );
}

/// La barra de abajo, con «Agendar» destacado si el menú lo trae.
class _BarraInferior extends StatelessWidget {
  final List<_Pestana> pestanas;

  const _BarraInferior({required this.pestanas});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.superficie,
        border: Border(
          top: BorderSide(
            color: AppColors.primarioClaro.withValues(alpha: 0.16),
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.sombra,
            blurRadius: 18,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        // Los rótulos de la barra crecen con el texto del sistema, pero con
        // tope: la barra tiene un alto fijo y cinco pestañas que caber.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (final pestana in pestanas)
                  Expanded(
                    child: pestana.destacada
                        ? _BotonDestacado(key: pestana.clave, pestana: pestana)
                        : _BotonPestana(key: pestana.clave, pestana: pestana),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonPestana extends StatelessWidget {
  final _Pestana pestana;

  const _BotonPestana({super.key, required this.pestana});

  @override
  Widget build(BuildContext context) {
    final activa = pestana.activa;
    final propio = pestana.color ?? AppColors.acentoClaro;
    final color = activa ? propio : AppColors.textoSecundario;

    return Semantics(
      button: true,
      selected: activa,
      label: pestana.etiqueta,
      child: InkResponse(
        onTap: pestana.alTocar,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: BoxDecoration(
                color: activa
                    ? propio.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(pestana.icono, color: color, size: 23),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                pestana.etiqueta,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: activa ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonDestacado extends StatelessWidget {
  final _Pestana pestana;

  const _BotonDestacado({super.key, required this.pestana});

  @override
  Widget build(BuildContext context) {
    final propio = pestana.color;

    return Semantics(
      button: true,
      label: pestana.etiqueta,
      child: GestureDetector(
        onTap: pestana.alTocar,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: propio == null ? AppGradientes.accion : null,
                color: propio,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (propio ?? AppColors.acento).withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(pestana.icono, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                pestana.etiqueta,
                maxLines: 1,
                style: TextStyle(
                  color: propio ?? AppColors.acentoClaro,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
