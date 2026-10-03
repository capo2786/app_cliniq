// lib/features/mediciones/escaner/widgets/pasos_preparacion.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentacion/widgets/botones.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../../../core/tema/tokens.dart';
import '../escaner_cubit.dart';
import '../serie_senal.dart';
import 'dibujos_escaner.dart';
import 'pasos_comunes.dart';

/// Elegir el modo: dedo (recomendado) o rostro (beta).
class PasoElegirModo extends StatelessWidget {
  final String? pacienteNombre;

  const PasoElegirModo({super.key, required this.pacienteNombre});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EscanerCubit>();

    Widget opcion({
      required Key key,
      required IconData icono,
      required String titulo,
      required String etiqueta,
      required Color color,
      required String descripcion,
      required ModoEscaner modo,
    }) => TarjetaTranslucida(
      key: key,
      tinte: color,
      onTap: () => cubit.elegirModo(modo),
      child: Row(
        children: [
          Icon(icono, color: color, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: AppColors.texto,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    Pastilla(texto: etiqueta, color: color),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: const TextStyle(
                    color: AppColors.textoSecundario,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textoTenue),
        ],
      ),
    );

    return CuerpoConBoton(
      children: [
        TarjetaEncabezado(
          icono: Icons.monitor_heart_outlined,
          titulo: 'Medir con la cámara',
          descripcion: pacienteNombre == null
              ? 'Tu pulso con la cámara del teléfono. Experimental y '
                    'referencial.'
              : 'El pulso de $pacienteNombre con la cámara del teléfono. '
                    'Experimental y referencial.',
        ),
        const SizedBox(height: 20),
        const EtiquetaSeccion('¿Cómo quieres medir?'),
        opcion(
          key: const Key('modo-dedo'),
          icono: Icons.fingerprint_rounded,
          titulo: 'Dedo',
          etiqueta: 'Recomendado',
          color: AppColors.exito,
          descripcion:
              'La yema sobre la cámara trasera, con el flash encendido. Es '
              'la forma más confiable.',
          modo: ModoEscaner.dedo,
        ),
        const SizedBox(height: 12),
        opcion(
          key: const Key('modo-rostro'),
          icono: Icons.face_retouching_natural_rounded,
          titulo: 'Rostro',
          etiqueta: 'Beta',
          color: AppColors.alerta,
          descripcion:
              'Tu cara frente a la cámara frontal. Menos precisa: necesita '
              'buena luz y que estés quieto.',
          modo: ModoEscaner.rostro,
        ),
        const LineaPrivacidad(),
      ],
    );
  }
}

/// Cómo poner el dedo o la cara, con su ilustración, y «Empezar a medir».
class PasoInstrucciones extends StatelessWidget {
  final ModoEscaner modo;
  final int segundos;

  const PasoInstrucciones({
    super.key,
    required this.modo,
    required this.segundos,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EscanerCubit>();
    final pasos = switch (modo) {
      ModoEscaner.dedo => [
        'Siéntate y apoya la mano en una mesa.',
        'Cubre la cámara trasera y el flash con la yema del dedo índice, sin '
            'apretar.',
        'No muevas el dedo durante $segundos segundos. El flash se calienta '
            'un poco: es normal.',
      ],
      ModoEscaner.rostro => [
        'Busca una luz pareja de frente (una ventana); evita el sol directo '
            'y la luz de atrás.',
        'Pon tu rostro dentro del óvalo, sin lentes de sol ni gorra.',
        'Quédate quieto y sin hablar durante $segundos segundos.',
      ],
    };

    return CuerpoConBoton(
      boton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BotonPrincipal(
            key: const Key('escaner-empezar'),
            texto: 'Empezar a medir',
            icono: Icons.play_arrow_rounded,
            onPressed: cubit.empezar,
          ),
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
        Center(
          child: modo == ModoEscaner.dedo
              ? const DibujoDedo()
              : const DibujoRostro(),
        ),
        const SizedBox(height: 18),
        EtiquetaSeccion(
          modo == ModoEscaner.dedo ? 'Con el dedo' : 'Con el rostro (beta)',
        ),
        for (final (i, paso) in pasos.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.acento.withValues(alpha: 0.25),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: AppColors.texto,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    paso,
                    style: const TextStyle(
                      color: AppColors.textoSuave,
                      fontSize: 14,
                      height: 1.4,
                    ),
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
