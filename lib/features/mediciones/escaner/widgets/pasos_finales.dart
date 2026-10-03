// lib/features/mediciones/escaner/widgets/pasos_finales.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/tema/tokens.dart';
import '../../data/cola_mediciones.dart';
import '../escaner_cubit.dart';
import '../motor_signos_camara.dart';
import 'pasos_comunes.dart';

/// No se pudo medir: el consejo, «Reintentar» y, si es el permiso,
/// «Abrir ajustes».
class PasoFallo extends StatelessWidget {
  final EscanerState state;

  const PasoFallo({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EscanerCubit>();

    return CuerpoConBoton(
      boton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotonPrincipal(
            key: const Key('escaner-reintentar'),
            texto: 'Reintentar',
            icono: Icons.refresh_rounded,
            onPressed: cubit.empezar,
          ),
          if (state.fallaPorPermiso) ...[
            const SizedBox(height: 10),
            BotonSecundario(
              texto: 'Abrir ajustes',
              icono: Icons.settings_outlined,
              onPressed: cubit.abrirAjustes,
            ),
          ],
          TextButton(
            onPressed: cubit.volverAModos,
            child: const Text(
              'Cambiar de modo',
              style: TextStyle(color: AppColors.textoSecundario),
            ),
          ),
        ],
      ),
      children: [
        EstadoVacio(
          icono: Icons.heart_broken_outlined,
          titulo: 'No pudimos medir esta vez',
          descripcion:
              state.fallo ?? ConsejosEscaner.paraElMotivo(null, state.modo),
          color: AppColors.alerta,
        ),
        const LineaPrivacidad(),
      ],
    );
  }
}

/// Guardada, enviada al médico o pendiente de enviar (sin red).
class PasoGuardado extends StatelessWidget {
  final EscanerState state;

  const PasoGuardado({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final pendiente = state.registro is RegistroPendiente;
    final destino = state.enviadaA;

    final titulo = pendiente
        ? 'Quedó guardada en este teléfono'
        : destino == null
        ? 'Guardada en tus signos vitales'
        : 'Enviada a tu médico';
    final descripcion = pendiente
        ? 'No hay conexión. La enviaremos sola en cuanto vuelva; mientras '
              'tanto la verás como «Pendiente de enviar».'
        : destino == null
        ? 'La verás en «Mis signos vitales», marcada como medida con la '
              'cámara (experimental).'
        : 'Quedó adjunta a: ${destino.titulo}. Tu médico decide si la usa.';

    return CuerpoConBoton(
      boton: BotonPrincipal(
        key: const Key('escaner-listo'),
        texto: 'Listo',
        icono: Icons.check_rounded,
        onPressed: () => Navigator.of(context).pop(true),
      ),
      children: [
        EstadoVacio(
          icono: pendiente
              ? Icons.cloud_upload_outlined
              : Icons.check_circle_outline_rounded,
          titulo: titulo,
          descripcion: descripcion,
          color: pendiente ? AppColors.alerta : AppColors.exito,
        ),
      ],
    );
  }
}
