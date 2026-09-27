import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/configuracion/config_publica_cubit.dart';
import '../../../../core/configuracion/en_contexto.dart';
import '../../../../core/fechas/fecha_local.dart';
import '../../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/contacto_clinica.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/servicios.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/cita.dart';
import '../../data/videollamada_service.dart';
import '../../dominio/videoconsulta.dart';
import 'sala_de_videoconsulta.dart';

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

  /// Entrar sin tocar el botón, si la sala ya está abierta al llegar (la
  /// pantalla de `/portal/videoconsulta/:citaId`). Si la sala abre después,
  /// con la pantalla ya a la vista, se espera a que la persona toque.
  final EntradaAutomatica? entradaAutomatica;

  final ServicioVideollamada? servicio;
  final RelojClinica? reloj;

  const BotonVideoconsulta({
    super.key,
    required this.cita,
    this.compacto = false,
    this.entradaAutomatica,
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

  /// Si todavía vale entrar solo: deja de valer si se vio la sala por abrir.
  bool _sinEsperar = true;

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
        cita: widget.cita,
        compacto: widget.compacto,
        entradaAutomatica: _sinEsperar ? widget.entradaAutomatica : null,
        servicio: _servicio,
      );
    }

    _sinEsperar = false;

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

/// Entrar solo, una vez: la pantalla de `/portal/videoconsulta/:citaId`
/// abre la sala al llegar, sin que haya que tocar el botón. Se gasta la
/// primera vez, aunque la pantalla se vuelva a dibujar.
class EntradaAutomatica {
  bool _gastada = false;

  /// `true` solo la primera vez.
  bool gastar() {
    if (_gastada) return false;
    _gastada = true;
    return true;
  }
}

/// El botón que entra a la sala de una cita, con lo que hace falta saber:
/// los permisos, si no hay red y, si el servidor dijo que no, su
/// explicación con el contacto de la clínica.
///
/// La sala se pide al servidor al tocarlo: él decide si la cita es de quien
/// entra y si la sala está abierta (409) o configurada (503). Con la sala,
/// se abre la ventana de la videoconsulta encima de esta pantalla
/// ([abrirVideoconsulta]), con el médico y la hora de fin de [cita] y el
/// asunto con el nombre de la clínica; al colgar, se vuelve aquí.
class EntrarASala extends StatefulWidget {
  final String citaId;

  /// La cita, si se tiene: pone el médico y la hora de fin en la cabecera.
  final Cita? cita;
  final bool compacto;

  /// Ver [BotonVideoconsulta.entradaAutomatica].
  final EntradaAutomatica? entradaAutomatica;
  final ServicioVideollamada? servicio;

  const EntrarASala({
    super.key,
    required this.citaId,
    this.cita,
    this.compacto = false,
    this.entradaAutomatica,
    this.servicio,
  });

  @override
  State<EntrarASala> createState() => _EntrarASalaState();
}

class _EntrarASalaState extends State<EntrarASala> {
  late final ServicioVideollamada _servicio =
      widget.servicio ?? Servicios.videollamada;

  bool _entrando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.entradaAutomatica?.gastar() ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _entrar();
      });
    }
  }

  Future<void> _entrar() async {
    if (_entrando) return;

    final config = context.read<ConfigPublicaCubit>().config;
    final asunto = asuntoDeLaSala(config.clinica.nombre);
    final ventana = VentanaDeSala.de(config.telemedicina);

    setState(() {
      _entrando = true;
      _error = null;
    });

    DatosDeSala? datos;
    try {
      datos = await _servicio.pedirSala(widget.citaId);
    } on ErrorDeVideollamada catch (error) {
      if (mounted) setState(() => _error = error.mensaje);
    } catch (error) {
      if (mounted) setState(() => _error = mensajeDeVideollamada(error));
    } finally {
      if (mounted) setState(() => _entrando = false);
    }

    if (datos == null || !mounted) return;

    await abrirVideoconsulta(
      context,
      datos: datos,
      servicio: _servicio,
      asunto: asunto,
      medico: widget.cita?.medico,
      termina: finDeLaVideoconsulta(
        cita: widget.cita,
        cierraEn: datos.cierraEn,
        ventana: ventana,
      ),
    );
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
