// lib/features/mediciones/escaner/widgets/paso_aviso.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/configuracion/en_contexto.dart';
import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../escaner_cubit.dart';
import 'pasos_comunes.dart';

/// La primera vez: «Función experimental, no es un dispositivo médico…»,
/// qué mide y qué no, y «Entiendo».
class PasoAviso extends StatelessWidget {
  const PasoAviso({super.key});

  @override
  Widget build(BuildContext context) {
    final emergencia = context.config.clinica.telefonoEmergencia;

    return CuerpoConBoton(
      boton: BotonPrincipal(
        key: const Key('escaner-entiendo'),
        texto: 'Entiendo',
        icono: Icons.check_rounded,
        onPressed: () => context.read<EscanerCubit>().aceptarAviso(),
      ),
      children: [
        const TarjetaEncabezado(
          icono: Icons.science_outlined,
          titulo: 'Función experimental',
          descripcion: 'Antes de usarla, lee esto con calma.',
        ),
        const SizedBox(height: 18),
        RecuadroAviso.alerta(
          'Función experimental: no es un dispositivo médico. Los valores '
          'son referenciales; no la uses para decidir tratamientos. Ante '
          'síntomas de alarma llama al $emergencia.',
          icono: Icons.warning_amber_rounded,
        ),
        const SizedBox(height: 14),
        const TarjetaTranslucida(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Qué mide y qué no',
                style: TextStyle(
                  color: AppColors.texto,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Mide tu pulso (frecuencia cardiaca) con la cámara y, si la '
                'señal es muy buena, tus respiraciones por minuto de forma '
                'aproximada.\n\nLa presión arterial, la saturación de '
                'oxígeno, la temperatura y la glucosa no se pueden medir con '
                'la cámara: regístralas desde tus aparatos de casa en «Mis '
                'signos vitales».',
                style: TextStyle(
                  color: AppColors.textoSuave,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const LineaPrivacidad(),
      ],
    );
  }
}
