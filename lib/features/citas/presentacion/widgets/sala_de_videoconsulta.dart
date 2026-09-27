// lib/features/citas/presentacion/widgets/sala_de_videoconsulta.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/presentacion/avisos.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/permisos_de_video.dart';
import '../../data/videollamada_service.dart';
import '../../dominio/videoconsulta.dart';

/// El fondo de la ventana de la sala: oscuro, como el panel de video web.
const Color _fondoSala = AppColors.fondoProfundo;

/// Cuánto se espera, con la página ya cargada, a que Jitsi diga que entró
/// antes de quitar el «Conectando…» y dejar ver lo que la página diga (un
/// token vencido, una sala llena).
const Duration _esperaParaEntrar = Duration(seconds: 8);

/// Abre la videoconsulta en una ventana sobre la pantalla de la cita.
///
/// Casi toda la pantalla, con las esquinas de arriba redondeadas y la cita
/// en penumbra detrás: la cabecera de Cliniq (con quién, a qué hora
/// termina y colgar) y, debajo, la sala. Colgar desde la cabecera, desde
/// Jitsi o con el botón atrás de Android (que pregunta antes) vuelve a la
/// misma pantalla. Termina cuando se cierra la ventana.
Future<void> abrirVideoconsulta(
  BuildContext context, {
  required DatosDeSala datos,
  required ServicioVideollamada servicio,
  String asunto = '',
  String? medico,
  DateTime? termina,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Encima de todo, también de la barra de pestañas del tablero.
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    // El video necesita todos los gestos, y la ventana no se cierra por un
    // toque fuera de ella: para salir está colgar.
    enableDrag: false,
    isDismissible: false,
    showDragHandle: false,
    backgroundColor: _fondoSala,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadio.panel)),
    ),
    routeSettings: const RouteSettings(name: 'videoconsulta'),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.97,
      child: VentanaDeVideoconsulta(
        datos: datos,
        servicio: servicio,
        asunto: asunto,
        medico: medico,
        termina: termina,
      ),
    ),
  );
}

enum _Etapa { permisos, sinPermisos, sala, error }

/// Lo que va dentro de la ventana: la cabecera y, debajo, según toque, los
/// permisos, la sala o por qué no abrió.
///
/// Primero pide la cámara y el micrófono; sin ellos lo explica y ofrece
/// volver a pedirlos (o abrir los ajustes, si el teléfono ya no deja
/// preguntar). Con ellos abre la sala. Si la sala no carga, lo dice aquí
/// mismo con «Reintentar»: nunca se va a otra parte.
class VentanaDeVideoconsulta extends StatefulWidget {
  final DatosDeSala datos;
  final ServicioVideollamada servicio;
  final String asunto;
  final String? medico;
  final DateTime? termina;

  const VentanaDeVideoconsulta({
    super.key,
    required this.datos,
    required this.servicio,
    this.asunto = '',
    this.medico,
    this.termina,
  });

  @override
  State<VentanaDeVideoconsulta> createState() => _VentanaDeVideoconsultaState();
}

class _VentanaDeVideoconsultaState extends State<VentanaDeVideoconsulta> {
  _Etapa _etapa = _Etapa.permisos;
  ResultadoDePermisos _permisos = ResultadoDePermisos.denegados;
  String _error = '';

  /// Cada «Reintentar» arma una sala nueva.
  int _intento = 0;
  bool _dentro = false;
  bool _esperaCumplida = false;
  Timer? _espera;
  bool _cerrando = false;

  late final OyenteDeSala _oyente = OyenteDeSala(
    alCargar: _alCargar,
    alEntrar: _alEntrar,
    alTerminar: _cerrar,
    alFallar: _alFallar,
  );

  @override
  void initState() {
    super.initState();
    _pedirPermisos();
  }

  @override
  void dispose() {
    _espera?.cancel();
    super.dispose();
  }

  Future<void> _pedirPermisos() async {
    if (_etapa != _Etapa.permisos) setState(() => _etapa = _Etapa.permisos);

    ResultadoDePermisos resultado;
    try {
      resultado = await widget.servicio.permisos.pedir();
    } catch (_) {
      resultado = ResultadoDePermisos.denegados;
    }
    if (!mounted) return;

    if (resultado == ResultadoDePermisos.concedidos) {
      _abrirSala();
    } else {
      setState(() {
        _permisos = resultado;
        _etapa = _Etapa.sinPermisos;
      });
    }
  }

  void _abrirSala() {
    _espera?.cancel();
    setState(() {
      _intento++;
      _dentro = false;
      _esperaCumplida = false;
      _etapa = _Etapa.sala;
    });
  }

  void _alCargar() {
    if (!mounted || _dentro) return;
    _espera?.cancel();
    _espera = Timer(_esperaParaEntrar, () {
      if (mounted) setState(() => _esperaCumplida = true);
    });
  }

  void _alEntrar() {
    if (mounted) setState(() => _dentro = true);
  }

  void _alFallar(String mensaje) {
    if (!mounted || _cerrando) return;
    _espera?.cancel();
    setState(() {
      _error = mensaje;
      _etapa = _Etapa.error;
    });
  }

  /// Colgar o el botón atrás: en la sala, pregunta antes.
  Future<void> _salir() async {
    if (_cerrando) return;

    if (_etapa == _Etapa.sala) {
      final salir = await confirmarAccion(
        context,
        titulo: '¿Salir de la videoconsulta?',
        mensaje:
            'Vas a colgar y volver a tu cita. Mientras la sala siga abierta, '
            'puedes volver a entrar.',
        confirmar: 'Salir',
        icono: Icons.call_end_rounded,
        peligroso: true,
      );
      if (!salir || !mounted) return;
    }

    _cerrar();
  }

  /// Cierra la ventana (y con ella la sala). Si justo había una pregunta
  /// abierta —Jitsi colgó mientras tanto—, se va también.
  void _cerrar() {
    if (_cerrando || !mounted) return;
    _cerrando = true;

    final navegador = Navigator.of(context);
    final ruta = ModalRoute.of(context);
    if (ruta != null && ruta.isActive) {
      navegador.popUntil((r) => r == ruta);
    }
    navegador.pop();
  }

  @override
  Widget build(BuildContext context) {
    final medios = MediaQuery.of(context);
    // El teclado del chat de Jitsi encoge la sala; la cabecera se queda.
    final abajo = math.max(medios.viewInsets.bottom, medios.viewPadding.bottom);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (seFue, _) {
        if (!seFue) _salir();
      },
      child: Material(
        color: _fondoSala,
        child: Padding(
          padding: EdgeInsets.only(bottom: abajo),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CabeceraDeVideoconsulta(
                titulo: tituloDeLaVideoconsulta(widget.medico),
                termina: widget.termina,
                alColgar: _salir,
              ),
              Expanded(child: _cuerpo()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cuerpo() {
    switch (_etapa) {
      case _Etapa.permisos:
        return const Center(
          child: CargandoCentro(
            mensaje: 'Pidiendo permiso para la cámara y el micrófono…',
          ),
        );
      case _Etapa.sinPermisos:
        return _SinPermisos(
          bloqueados: _permisos == ResultadoDePermisos.bloqueados,
          alReintentar: _pedirPermisos,
          alAbrirAjustes: () => widget.servicio.permisos.abrirAjustes(),
        );
      case _Etapa.error:
        return _Aviso(
          icono: Icons.videocam_off_rounded,
          titulo: 'No se abrió la videoconsulta',
          mensaje: _error,
          acciones: [
            _Accion(
              clave: const Key('reintentar-videoconsulta'),
              texto: 'Reintentar',
              icono: Icons.refresh_rounded,
              alPulsar: _abrirSala,
            ),
          ],
        );
      case _Etapa.sala:
        return Stack(
          fit: StackFit.expand,
          children: [
            KeyedSubtree(
              key: ValueKey('sala-$_intento'),
              child: widget.servicio.sala.construir(
                widget.datos,
                asunto: widget.asunto,
                oyente: _oyente,
              ),
            ),
            if (!_dentro && !_esperaCumplida)
              const ColoredBox(
                color: _fondoSala,
                child: Center(
                  child: CargandoCentro(mensaje: 'Conectando con la sala…'),
                ),
              ),
          ],
        );
    }
  }
}

/// La cabecera de la ventana, como la del panel de video web: con quién es,
/// a qué hora termina y colgar.
class CabeceraDeVideoconsulta extends StatelessWidget {
  final String titulo;
  final DateTime? termina;
  final VoidCallback alColgar;

  const CabeceraDeVideoconsulta({
    super.key,
    required this.titulo,
    required this.alColgar,
    this.termina,
  });

  @override
  Widget build(BuildContext context) {
    final termina = this.termina;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.videocam_rounded,
              color: AppColors.texto,
              size: 19,
            ),
          ),
          const SizedBox(width: AppEspaciado.m),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (termina != null)
                    Text(
                      terminaALas(termina),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11.5,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppEspaciado.s),
          IconButton.filled(
            key: const Key('colgar-videoconsulta'),
            tooltip: 'Colgar y salir',
            onPressed: alColgar,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.peligroBoton,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.call_end_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

/// Sin cámara o sin micrófono: por qué hacen falta y cómo darlos.
class _SinPermisos extends StatelessWidget {
  final bool bloqueados;
  final VoidCallback alReintentar;
  final VoidCallback alAbrirAjustes;

  const _SinPermisos({
    required this.bloqueados,
    required this.alReintentar,
    required this.alAbrirAjustes,
  });

  @override
  Widget build(BuildContext context) {
    return _Aviso(
      icono: Icons.mic_off_rounded,
      titulo: 'Falta el permiso de la cámara o el micrófono',
      mensaje: bloqueados
          ? 'La cámara o el micrófono están desactivados para Cliniq. '
                'Actívalos en los ajustes del teléfono y vuelve a intentarlo.'
          : 'Para la videoconsulta necesitamos la cámara y el micrófono: así '
                'el médico te ve y te escucha.',
      acciones: [
        if (bloqueados)
          _Accion(
            clave: const Key('ajustes-videoconsulta'),
            texto: 'Abrir ajustes',
            icono: Icons.settings_rounded,
            alPulsar: alAbrirAjustes,
          ),
        _Accion(
          clave: const Key('reintentar-videoconsulta'),
          texto: 'Reintentar',
          icono: Icons.refresh_rounded,
          alPulsar: alReintentar,
        ),
      ],
    );
  }
}

class _Accion {
  final Key clave;
  final String texto;
  final IconData icono;
  final VoidCallback alPulsar;

  const _Accion({
    required this.clave,
    required this.texto,
    required this.icono,
    required this.alPulsar,
  });
}

/// Un aviso centrado dentro de la ventana, con sus botones.
class _Aviso extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String mensaje;
  final List<_Accion> acciones;

  const _Aviso({
    required this.icono,
    required this.titulo,
    required this.mensaje,
    required this.acciones,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppEspaciado.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, color: AppColors.alerta, size: 34),
            const SizedBox(height: AppEspaciado.m),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.texto,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppEspaciado.s),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textoSuave,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppEspaciado.xl),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppEspaciado.s,
              runSpacing: AppEspaciado.s,
              children: [
                for (final accion in acciones)
                  OutlinedButton.icon(
                    key: accion.clave,
                    onPressed: accion.alPulsar,
                    icon: Icon(accion.icono, size: 18),
                    label: Text(accion.texto),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.acentoClaro,
                      side: BorderSide(
                        color: AppColors.acento.withValues(alpha: 0.55),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
