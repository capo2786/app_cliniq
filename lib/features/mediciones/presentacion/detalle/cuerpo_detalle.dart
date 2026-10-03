// lib/features/mediciones/presentacion/detalle/cuerpo_detalle.dart

import 'package:flutter/material.dart';

import '../../../../core/presentacion/widgets/estados.dart';
import '../../../../core/presentacion/widgets/tarjetas.dart';
import '../../escaner/widgets/resultado/detalle_resultado.dart';
import '../../escaner/widgets/resultado/tarjetas_resultado.dart';
import '../../providers/detalle_medicion_cubit.dart';
import 'ficha_medicion.dart';

/// Lo que va debajo de la cabecera, según el caso ([casoDe]):
///
/// - el pulso de la cámara con su detalle: las mismas tarjetas y las mismas
///   seis gráficas del resultado del escáner (sus widgets, no una copia);
/// - de la cámara sin detalle: las tarjetas que haya y por qué no hay
///   gráficas (anterior al detalle, cargando o sin red);
/// - de un aparato o a mano: los datos, sin gráficas.
class CuerpoDelDetalle extends StatelessWidget {
  final DetalleMedicionState state;
  final VoidCallback alReintentar;

  const CuerpoDelDetalle({
    super.key,
    required this.state,
    required this.alReintentar,
  });

  @override
  Widget build(BuildContext context) {
    final m = state.medicion!;
    final caso = casoDe(m);

    if (caso == CasoDeDetalle.aparato) {
      return Column(
        key: const Key('detalle-datos'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const EtiquetaSeccion('Datos de la medición'),
          DatosPequenos(datosDeMedicion(m)),
        ],
      );
    }

    final valores = valoresDeTarjetas(m, companera: state.companera);
    final detalle = m.detalle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!valores.vacio) TarjetasResultado(valores: valores),
        const SizedBox(height: 16),
        switch (caso) {
          CasoDeDetalle.conDetalle => DetalleDeLaMedicion(
            detalle: detalle!,
            frValida: detalle.respiracion.isNotEmpty,
          ),
          CasoDeDetalle.anteriorAlDetalle => const RecuadroAviso.informacion(
            notaAnteriorAlDetalle,
            key: Key('detalle-anterior'),
            icono: Icons.history_rounded,
          ),
          CasoDeDetalle.respiracionDeCamara => const RecuadroAviso.informacion(
            notaRespiracionDeCamara,
            icono: Icons.info_outline,
          ),
          CasoDeDetalle.detalleSinCargar => _DetalleSinCargar(
            state: state,
            alReintentar: alReintentar,
          ),
          CasoDeDetalle.aparato => const SizedBox.shrink(),
        },
      ],
    );
  }
}

/// El pulso de la cámara tiene detalle en el servidor, pero no llegó.
class _DetalleSinCargar extends StatelessWidget {
  final DetalleMedicionState state;
  final VoidCallback alReintentar;

  const _DetalleSinCargar({required this.state, required this.alReintentar});

  @override
  Widget build(BuildContext context) {
    if (state.carga == CargaDetalle.cargando) {
      return const CargandoCentro(mensaje: 'Cargando el detalle…');
    }
    return EstadoError(
      key: const Key('detalle-sin-cargar'),
      mensaje:
          state.error ??
          'No pudimos leer el detalle de esta medición. Intenta de nuevo.',
      alReintentar: alReintentar,
    );
  }
}
