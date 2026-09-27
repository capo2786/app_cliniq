import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/fechas/fecha_local.dart';
import '../../../../core/integraciones/costuras.dart';
import '../../../../core/presentacion/widgets/aviso_sin_conexion.dart';
import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/servicios.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/models/cita.dart';
import '../../data/videollamada_service.dart';
import '../../dominio/videoconsulta.dart';

/// «Entrar a la videoconsulta», para una cita de telemedicina.
///
/// Se enciende 120 minutos antes del inicio y se apaga 240 minutos después
/// del fin: la ventana más amplia que la clínica puede configurar (ver
/// `maximoMinutosAntesDeLaSala`). Antes se ve apagado y dice desde cuándo se
/// podrá entrar; después ya no se ve. Se vuelve a mirar el reloj cada 30
/// segundos, así el botón se enciende solo con la pantalla abierta. Al
/// tocarlo se pide la sala al servidor y se abre en el navegador; si el
/// servidor dice que no —la sala todavía no abre o ya cerró con la
/// configuración de la clínica (409), o no está configurada (503)—, se
/// enseña su explicación.
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
  bool _entrando = false;
  String? _error;

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

  Future<void> _entrar() async {
    if (_entrando) return;

    setState(() {
      _entrando = true;
      _error = null;
    });

    try {
      await _servicio.unirse(widget.cita.id);
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
    final ahora = _reloj.ahora();
    final estado = estadoDeSala(widget.cita, ahora);

    if (estado == EstadoSala.noAplica || estado == EstadoSala.cerrada) {
      return const SizedBox.shrink();
    }

    if (!_servicio.disponible) {
      return const RecuadroAviso.informacion(
        'El enlace de la videollamada te llega por correo antes de la cita.',
        icono: Icons.videocam_outlined,
      );
    }

    final abierta = estado == EstadoSala.abierta;

    return ConRed(
      builder: (context, hayRed) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (abierta)
            BotonPrincipal(
              key: const Key('boton-videoconsulta'),
              texto: 'Entrar a la videoconsulta',
              icono: Icons.videocam_rounded,
              cargando: _entrando,
              textoCargando: 'Abriendo la sala…',
              alto: widget.compacto ? 50 : 56,
              onPressed: hayRed ? _entrar : null,
            )
          else
            BotonSecundario(
              key: const Key('boton-videoconsulta'),
              texto: 'Entrar a la videoconsulta',
              icono: Icons.videocam_outlined,
              color: AppColors.violeta,
              onPressed: null,
            ),
          const SizedBox(height: 8),
          _Nota(
            icono: abierta ? Icons.mic_none_rounded : Icons.lock_clock_outlined,
            texto: !hayRed && abierta
                ? 'Sin conexión: para entrar a la videoconsulta necesitas '
                      'Internet.'
                : abierta
                ? avisoPermisosDeVideo
                : '${cuandoAbreLaSala(widget.cita, ahora)} '
                      '$avisoPermisosDeVideo',
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            RecuadroAviso.error(_error!),
          ],
        ],
      ),
    );
  }
}

class _Nota extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _Nota({required this.icono, required this.texto});

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
