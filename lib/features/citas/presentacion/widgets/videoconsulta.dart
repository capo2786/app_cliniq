import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/configuracion/config_publica_cubit.dart';
import '../../../../core/configuracion/en_contexto.dart';
import '../../../../core/fechas/fecha_local.dart';
import '../../../../core/integraciones/costuras.dart';
import '../../../../core/presentacion/proveedores.dart';
import '../../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/contacto_clinica.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/servicios.dart';
import '../../../../core/tema/tokens.dart';
import '../../../auth/providers/auth_bloc.dart';
import '../../data/models/cita.dart';
import '../../data/videollamada_service.dart';
import '../../dominio/videoconsulta.dart';

/// «Entrar a la videoconsulta», para una cita de telemedicina.
///
/// Se enciende los minutos antes del inicio y se apaga los minutos después
/// del fin que dice la configuración de la clínica
/// (`telemedicina.minutosAntes` y `minutosDespues`). Antes se ve apagado y
/// dice a qué hora abre la sala; después ya no se ve. Se vuelve a mirar el
/// reloj cada 30 segundos, así el botón se enciende solo con la pantalla
/// abierta. Con la sala abierta, entrar es [EntrarASala].
class BotonVideoconsulta extends StatefulWidget {
  final Cita cita;

  /// Más compacto, para la tarjeta de la próxima cita.
  final bool compacto;

  final ServicioVideollamada? servicio;
  final RelojClinica? reloj;

  const BotonVideoconsulta({
    super.key,
    required this.cita,
    this.compacto = false,
    this.servicio,
    this.reloj,
  });

  @override
  State<BotonVideoconsulta> createState() => _BotonVideoconsultaState();
}

class _BotonVideoconsultaState extends State<BotonVideoconsulta> {
  late final ServicioVideollamada _servicio =
      widget.servicio ?? Servicios.videollamada;
  late final RelojClinica _reloj = widget.reloj ?? Servicios.reloj;

  Timer? _vigilancia;

  @override
  void initState() {
    super.initState();
    _vigilancia = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _vigilancia?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ahora = _reloj.ahora();
    final ventana = VentanaDeSala.de(context.config.telemedicina);
    final estado = estadoDeSala(widget.cita, ahora, ventana);

    if (estado == EstadoSala.noAplica || estado == EstadoSala.cerrada) {
      return const SizedBox.shrink();
    }

    if (!_servicio.disponible) {
      return const RecuadroAviso.informacion(
        'El enlace de la videollamada te llega por correo antes de la cita.',
        icono: Icons.videocam_outlined,
      );
    }

    if (estado == EstadoSala.abierta) {
      return EntrarASala(
        citaId: widget.cita.id,
        compacto: widget.compacto,
        servicio: _servicio,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        BotonSecundario(
          key: const Key('boton-videoconsulta'),
          texto: 'Entrar a la videoconsulta',
          icono: Icons.videocam_outlined,
          color: AppColors.violeta,
          onPressed: null,
        ),
        const SizedBox(height: 8),
        NotaDeVideo(
          icono: Icons.lock_clock_outlined,
          texto:
              '${cuandoAbreLaSala(widget.cita, ahora, ventana)} '
              '$avisoPermisosDeVideo',
        ),
      ],
    );
  }
}

/// El botón que entra a la sala de una cita, con lo que hace falta saber:
/// los permisos, si no hay red, si se abrió en el navegador integrado (el
/// respaldo) y, si el servidor dijo que no, su explicación con el contacto
/// de la clínica.
///
/// La sala se pide al servidor al tocarlo: él decide si la cita es de quien
/// entra y si la sala está abierta (409) o configurada (503). Entra con el
/// nombre de quien tiene la sesión y el asunto con el nombre de la clínica.
class EntrarASala extends StatefulWidget {
  final String citaId;
  final bool compacto;
  final ServicioVideollamada? servicio;

  const EntrarASala({
    super.key,
    required this.citaId,
    this.compacto = false,
    this.servicio,
  });

  @override
  State<EntrarASala> createState() => _EntrarASalaState();
}

class _EntrarASalaState extends State<EntrarASala> {
  late final ServicioVideollamada _servicio =
      widget.servicio ?? Servicios.videollamada;

  bool _entrando = false;
  bool _enElNavegador = false;
  String? _error;

  Future<void> _entrar() async {
    if (_entrando) return;

    final nombre = context.leerSiHay<AuthBloc>()?.usuario?.nombre ?? '';
    final clinica = context.read<ConfigPublicaCubit>().config.clinica.nombre;

    setState(() {
      _entrando = true;
      _enElNavegador = false;
      _error = null;
    });

    try {
      final donde = await _servicio.unirse(
        widget.citaId,
        nombreVisible: nombre,
        asunto: asuntoDeLaSala(clinica),
      );
      if (mounted) {
        setState(() => _enElNavegador = donde == SalaAbierta.enElNavegador);
      }
    } on ErrorDeVideollamada catch (error) {
      if (mounted) setState(() => _error = error.mensaje);
    } catch (error) {
      if (mounted) setState(() => _error = mensajeDeVideollamada(error));
    } finally {
      if (mounted) setState(() => _entrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    return ConRed(
      builder: (context, hayRed) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          BotonPrincipal(
            key: const Key('boton-videoconsulta'),
            texto: 'Entrar a la videoconsulta',
            icono: Icons.videocam_rounded,
            cargando: _entrando,
            textoCargando: 'Abriendo la sala…',
            alto: widget.compacto ? 50 : 56,
            onPressed: hayRed ? _entrar : null,
          ),
          const SizedBox(height: 8),
          NotaDeVideo(
            icono: Icons.mic_none_rounded,
            texto: hayRed
                ? avisoPermisosDeVideo
                : 'Sin conexión: para entrar a la videoconsulta necesitas '
                      'Internet.',
          ),
          if (_enElNavegador) ...[
            const SizedBox(height: 10),
            const RecuadroAviso.alerta(
              avisoVideoEnElNavegador,
              icono: Icons.open_in_browser_rounded,
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 10),
            RecuadroAviso.error(error),
            const SizedBox(height: 4),
            const ContactoClinica(),
          ],
        ],
      ),
    );
  }
}

/// Una nota pequeña bajo el botón, con su icono.
class NotaDeVideo extends StatelessWidget {
  final IconData icono;
  final String texto;

  const NotaDeVideo({super.key, required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icono, size: 15, color: AppColors.textoSecundario),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              color: AppColors.textoSecundario,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
