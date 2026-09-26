// lib/features/inicio/presentacion/dashboard_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/catalogos/catalogos_cubit.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../agendar/presentacion/agendar_page.dart';
import '../../auth/data/models/usuario.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../auth/providers/auth_event.dart';
import '../../citas/presentacion/citas_page.dart';
import '../../citas/providers/citas_bloc.dart';
import '../../citas/providers/citas_event.dart';
import '../../dependientes/presentacion/dependientes_page.dart';
import '../../dependientes/providers/dependientes_bloc.dart';
import '../../perfil/presentacion/perfil_page.dart';
import 'inicio_page.dart';

/*
 * Una pestaña de abajo. Hay de dos clases y por eso el índice de la barra no
 * puede ser el índice de la pila de páginas:
 *
 *   - Las que cambian de vista llevan [pagina], la posición en la pila.
 *   - «Agendar» no cambia de vista: abre el agendamiento encima y al volver
 *     se sigue donde se estaba, así que lleva [abre] y no ocupa sitio.
 */
class _Pestana {
  final IconData icono;
  final IconData iconoActivo;
  final String etiqueta;
  final int? pagina;
  final VoidCallback? abre;

  const _Pestana({
    required this.icono,
    required this.iconoActivo,
    required this.etiqueta,
    this.pagina,
    this.abre,
  });

  bool get destacada => abre != null;
}

/// La estructura de la aplicación con sesión: las pestañas de abajo.
///
/// Aquí nacen las cargas de todo lo que comparten las pestañas —citas,
/// dependientes y catálogos— y los recordatorios, y se vuelven a pedir al
/// regresar a la aplicación: quien la abre por la mañana tiene que ver las
/// citas de hoy, no las de anoche.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  static const int _paginaInicio = 0;
  static const int _paginaCitas = 1;
  static const int _paginaDependientes = 2;
  static const int _paginaPerfil = 3;

  int _pagina = _paginaInicio;

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

    if (usuario.puede(Permisos.misCitas)) {
      context.read<CitasBloc>().add(CitasSolicitadas(usuario.uid));
    }

    if (usuario.puede(Permisos.dependientes)) {
      context.read<DependientesBloc>().add(
        DependientesSolicitados(usuario.uid),
      );
    }

    unawaited(context.read<CatalogosCubit>().cargar());
  }

  void _abrirAgendar() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AgendarPage()));
  }

  void _irA(DestinoRapido destino) {
    switch (destino) {
      case DestinoRapido.agendar:
        _abrirAgendar();
      case DestinoRapido.citas:
        setState(() => _pagina = _paginaCitas);
      case DestinoRapido.dependientes:
        setState(() => _pagina = _paginaDependientes);
      case DestinoRapido.perfil:
        setState(() => _pagina = _paginaPerfil);
    }
  }

  List<_Pestana> get _pestanas => [
    const _Pestana(
      icono: Icons.home_outlined,
      iconoActivo: Icons.home_rounded,
      etiqueta: 'Inicio',
      pagina: _paginaInicio,
    ),
    const _Pestana(
      icono: Icons.event_note_outlined,
      iconoActivo: Icons.event_note_rounded,
      etiqueta: 'Citas',
      pagina: _paginaCitas,
    ),
    _Pestana(
      icono: Icons.add_rounded,
      iconoActivo: Icons.add_rounded,
      etiqueta: 'Agendar',
      abre: _abrirAgendar,
    ),
    const _Pestana(
      icono: Icons.family_restroom_outlined,
      iconoActivo: Icons.family_restroom_rounded,
      etiqueta: 'Dependientes',
      pagina: _paginaDependientes,
    ),
    const _Pestana(
      icono: Icons.person_outline_rounded,
      iconoActivo: Icons.person_rounded,
      etiqueta: 'Perfil',
      pagina: _paginaPerfil,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _pagina,
        children: [
          InicioPage(alIr: _irA),
          CitasPage(alAgendar: _abrirAgendar),
          const DependientesPage(),
          const PerfilPage(),
        ],
      ),
      bottomNavigationBar: _BarraInferior(
        pestanas: _pestanas,
        pagina: _pagina,
        alElegir: (pestana) {
          if (pestana.abre != null) {
            pestana.abre!();
          } else {
            setState(() => _pagina = pestana.pagina!);
          }
        },
      ),
    );
  }
}

/// La barra de abajo, con «Agendar» destacado en el centro.
///
/// Agendar es la razón de ser de la aplicación: va en el centro, más grande
/// y con el color de la acción, al alcance del pulgar desde cualquier
/// pestaña.
class _BarraInferior extends StatelessWidget {
  final List<_Pestana> pestanas;
  final int pagina;
  final ValueChanged<_Pestana> alElegir;

  const _BarraInferior({
    required this.pestanas,
    required this.pagina,
    required this.alElegir,
  });

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
                        ? _BotonDestacado(
                            pestana: pestana,
                            onTap: () => alElegir(pestana),
                          )
                        : _BotonPestana(
                            pestana: pestana,
                            activa: pestana.pagina == pagina,
                            onTap: () => alElegir(pestana),
                          ),
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
  final bool activa;
  final VoidCallback onTap;

  const _BotonPestana({
    required this.pestana,
    required this.activa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = activa ? AppColors.acentoClaro : AppColors.textoSecundario;

    return Semantics(
      button: true,
      selected: activa,
      label: pestana.etiqueta,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              decoration: BoxDecoration(
                color: activa
                    ? AppColors.acento.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                activa ? pestana.iconoActivo : pestana.icono,
                color: color,
                size: 23,
              ),
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
  final VoidCallback onTap;

  const _BotonDestacado({required this.pestana, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: pestana.etiqueta,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppGradientes.accion,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.acento.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(pestana.icono, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                pestana.etiqueta,
                maxLines: 1,
                style: const TextStyle(
                  color: AppColors.acentoClaro,
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
