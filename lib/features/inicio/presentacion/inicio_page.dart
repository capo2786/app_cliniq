// lib/features/inicio/presentacion/inicio_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/formato/fechas.dart';
import '../../../core/presentacion/margenes.dart';
import '../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../core/presentacion/widgets/cerrar_sesion.dart';
import '../../../core/presentacion/widgets/estados.dart';
import '../../../core/presentacion/widgets/fondo_app.dart';
import '../../../core/presentacion/widgets/logo_cliniq.dart';
import '../../../core/presentacion/widgets/tarjetas.dart';
import '../../../core/servicios.dart';
import '../../../core/tema/tokens.dart';
import '../../auth/data/models/usuario.dart';
import '../../auth/providers/auth_bloc.dart';
import '../../auth/providers/auth_event.dart';
import '../../citas/dominio/reglas_citas.dart';
import '../../citas/providers/citas_bloc.dart';
import '../../citas/providers/citas_event.dart';
import '../../citas/providers/citas_state.dart';
import '../../consultas/dominio/reglas_consultas.dart';
import '../../consultas/providers/consultas_bloc.dart';
import 'widgets/proxima_cita.dart';

/// Las pestañas a las que se puede saltar desde los accesos rápidos.
enum DestinoRapido { agendar, consultas, citas, dependientes, perfil }

/// La portada: quién eres, cuál es tu próxima cita y los accesos rápidos.
class InicioPage extends StatefulWidget {
  final ValueChanged<DestinoRapido> alIr;

  const InicioPage({super.key, required this.alIr});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  /// La cuenta regresiva de la próxima cita dice «faltan 3 h 20 min»: tiene
  /// que avanzar sola mientras la pantalla está abierta.
  Timer? _reloj;
  DateTime _ahora = Servicios.reloj.ahora();

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _ahora = Servicios.reloj.ahora());
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _refrescar() async {
    final auth = context.read<AuthBloc>();
    final usuario = auth.usuario;
    if (usuario == null) return;

    auth.add(const AuthPerfilRefrescado());

    final citas = context.read<CitasBloc>()..add(CitasSolicitadas(usuario.uid));

    await citas.stream
        .firstWhere((s) => !s.cargando)
        .timeout(const Duration(seconds: 15), onTimeout: () => citas.state);

    if (mounted) setState(() => _ahora = Servicios.reloj.ahora());
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthBloc>().usuario;

    return Scaffold(
      backgroundColor: AppColors.fondoProfundo,
      appBar: AppBar(
        titleSpacing: 20,
        title: const Row(
          children: [
            LogoCliniq(tamano: 34),
            SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Cliniq',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  'Portal del paciente',
                  style: TextStyle(
                    color: AppColors.primarioClaro,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: const [BotonCerrarSesion(), SizedBox(width: 6)],
      ),
      body: FondoDegradado(
        child: RefreshIndicator(
          color: AppColors.acentoClaro,
          backgroundColor: AppColors.superficie,
          onRefresh: _refrescar,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: context.margenDeScroll(
              horizontal: 18,
              superior: 20,
              inferior: 30,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: BlocBuilder<CitasBloc, CitasState>(
                  builder: (context, citas) {
                    final proximas = proximasCitas(citas.citas, _ahora);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AvisoSinConexion(),
                        _Bienvenida(
                          usuario: usuario,
                          ahora: _ahora,
                          proximas: proximas.length,
                        ),
                        const SizedBox(height: 26),
                        const EtiquetaSeccion('Tu próxima cita'),
                        if (citas.carga == CargaCitas.cargando &&
                            citas.citas.isEmpty)
                          const CargandoCentro(
                            mensaje: 'Buscando tu próxima cita…',
                          )
                        else if (proximas.isEmpty)
                          EstadoVacio(
                            icono: Icons.event_available_rounded,
                            titulo: citas.carga == CargaCitas.error
                                ? 'No pudimos ver tus citas'
                                : 'No tienes citas próximas',
                            descripcion: citas.carga == CargaCitas.error
                                ? (citas.error ??
                                      'Revisa tu conexión y desliza hacia '
                                          'abajo para reintentar.')
                                : 'Agenda con el médico que necesites, para '
                                      'ti o para alguien a tu cargo.',
                            accion: 'Agendar una cita',
                            alPulsar: () => widget.alIr(DestinoRapido.agendar),
                          )
                        else
                          TarjetaProximaCita(
                            cita: proximas.first,
                            ahora: _ahora,
                          ),
                        const SizedBox(height: 26),
                        const EtiquetaSeccion('Accesos rápidos'),
                        if (usuario?.puede(Permisos.consultas) ?? false) ...[
                          _AccesoConsultas(
                            alAbrir: () => widget.alIr(DestinoRapido.consultas),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _AccesosRapidos(alIr: widget.alIr),
                        const SizedBox(height: 30),
                        const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                color: AppColors.textoTenue,
                                size: 15,
                              ),
                              SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  'Tus datos de salud, protegidos con tu sesión',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textoTenue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El saludo: quién eres, en la tarjeta que sube del gris azulado al
/// terracota.
///
/// El contenido se apoya sobre un velo oscuro que sube desde abajo, para
/// que el texto blanco tenga contraste también sobre el extremo terracota.
class _Bienvenida extends StatelessWidget {
  final Usuario? usuario;
  final DateTime ahora;
  final int proximas;

  const _Bienvenida({
    required this.usuario,
    required this.ahora,
    required this.proximas,
  });

  String get _saludo {
    final hora = ahora.hour;
    if (hora < 12) return 'BUENOS DÍAS';
    if (hora < 19) return 'BUENAS TARDES';
    return 'BUENAS NOCHES';
  }

  @override
  Widget build(BuildContext context) {
    final nombre = usuario?.primerNombre ?? '';
    final email = usuario?.email ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: AppGradientes.bienvenida,
        border: Border.all(color: Colors.white24),
        boxShadow: [
          // La tarjeta se levanta del fondo con una sombra de su propio
          // color; sin ella flota sin peso.
          BoxShadow(
            color: AppColors.acento.withValues(alpha: 0.3),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
              right: -70,
              top: -90,
              child: Container(
                width: 210,
                height: 210,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.veloClaro, AppColors.veloTransparente],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -16,
              top: -20,
              child: Icon(
                Icons.health_and_safety_rounded,
                size: 140,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [
                      AppColors.fondoProfundo.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          usuario?.iniciales ?? '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _saludo,
                              style: const TextStyle(
                                color: AppColors.textoSuave,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.9,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nombre.isEmpty ? 'Hola' : 'Hola, $nombre',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                height: 1.12,
                              ),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textoSuave,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.veloClaro,
                          AppColors.veloTransparente,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      _Dato(
                        icono: Icons.calendar_today_rounded,
                        texto: FormatoFecha.diaMedio(ahora),
                      ),
                      _Dato(
                        icono: Icons.event_note_rounded,
                        texto: proximas == 1
                            ? '1 cita próxima'
                            : '$proximas citas próximas',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Dato({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.fondoProfundo.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: AppColors.acentoSuave, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Consultas en línea, a lo ancho y antes que los demás accesos: es la forma
/// de hablar con un médico sin cita, y avisa cuando hay respuestas por leer.
class _AccesoConsultas extends StatelessWidget {
  final VoidCallback alAbrir;

  const _AccesoConsultas({required this.alAbrir});

  @override
  Widget build(BuildContext context) {
    final porLeer = context.select<ConsultasBloc, int>(
      (bloc) => respuestasPorLeer(bloc.state.consultas),
    );
    final enCurso = context.select<ConsultasBloc, int>(
      (bloc) => consultasEnCurso(bloc.state.consultas).length,
    );

    final descripcion = porLeer > 0
        ? (porLeer == 1
              ? 'Tienes 1 respuesta del médico'
              : 'Tienes $porLeer respuestas del médico')
        : enCurso > 0
        ? (enCurso == 1 ? '1 consulta en curso' : '$enCurso consultas en curso')
        : 'Escríbele a un médico sin ir a la clínica';

    return TarjetaTranslucida(
      key: const Key('acceso-consultas'),
      tinte: AppColors.ambar,
      onTap: alAbrir,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.ambar.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.forum_outlined,
              color: AppColors.ambar,
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Consultas en línea',
                  style: TextStyle(
                    color: AppColors.texto,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  descripcion,
                  style: TextStyle(
                    color: porLeer > 0
                        ? AppColors.exito
                        : AppColors.textoSecundario,
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: porLeer > 0 ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (porLeer > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.exito,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$porLeer',
                style: const TextStyle(
                  color: AppColors.fondoProfundo,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textoSecundario,
          ),
        ],
      ),
    );
  }
}

class _AccesosRapidos extends StatelessWidget {
  final ValueChanged<DestinoRapido> alIr;

  const _AccesosRapidos({required this.alIr});

  @override
  Widget build(BuildContext context) {
    final accesos = [
      (
        DestinoRapido.agendar,
        'Agendar',
        'Una cita nueva',
        Icons.add_circle_outline_rounded,
        AppColors.acentoClaro,
      ),
      (
        DestinoRapido.citas,
        'Mis citas',
        'Próximas e historial',
        Icons.event_note_rounded,
        AppColors.celeste,
      ),
      (
        DestinoRapido.dependientes,
        'Dependientes',
        'Quienes están a tu cargo',
        Icons.family_restroom_rounded,
        AppColors.menta,
      ),
      (
        DestinoRapido.perfil,
        'Mi perfil',
        'Datos y seguridad',
        Icons.person_outline_rounded,
        AppColors.violeta,
      ),
    ];

    return LayoutBuilder(
      builder: (context, limites) {
        final ancho = (limites.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (destino, titulo, descripcion, icono, color) in accesos)
              SizedBox(
                width: ancho,
                child: TarjetaTranslucida(
                  tinte: color,
                  onTap: () => alIr(destino),
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icono, color: color, size: 23),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        titulo,
                        style: const TextStyle(
                          color: AppColors.texto,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textoSecundario,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
