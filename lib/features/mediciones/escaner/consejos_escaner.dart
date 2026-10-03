// lib/features/mediciones/escaner/consejos_escaner.dart

import '../dominio/procesamiento_ppg.dart';
import 'serie_senal.dart';

/// Los consejos del escáner, en un solo lugar.
class ConsejosEscaner {
  const ConsejosEscaner._();

  static const cubreLaCamara = 'Cubre bien la cámara y el flash con la yema';
  static const noAprietes = 'Apoya el dedo sin apretar';
  static const quedateQuieto = 'Quédate quieto';
  static const masLuz = 'Busca un lugar con más luz';
  static const rostroEnElMarco = 'Pon tu cara dentro del marco';

  /// Qué hacer cuando la medición no salió, según el motivo.
  static String paraElMotivo(MotivoCalidad? motivo, ModoEscaner modo) =>
      switch (motivo) {
        MotivoCalidad.sinCobertura =>
          'La yema no cubría la cámara. Apoya el dedo índice sobre la cámara '
              'y el flash a la vez, sin apretar, y no lo muevas.',
        MotivoCalidad.saturada =>
          'La imagen salió demasiado brillante. Apoya el dedo sin apretar: '
              'si aprietas, la sangre no pasa y no se ve el pulso.',
        MotivoCalidad.movimiento =>
          modo == ModoEscaner.dedo
              ? 'Hubo movimiento. Apoya la mano en una mesa y quédate quieto '
                    'durante toda la medición.'
              : 'Hubo movimiento. Apoya la espalda, sostén el teléfono con '
                    'las dos manos y quédate quieto.',
        MotivoCalidad.pocosCuadros =>
          'La cámara entregó muy pocas imágenes por segundo. Cierra otras '
              'aplicaciones y prueba de nuevo.',
        MotivoCalidad.pocosDatos =>
          'La medición fue demasiado corta. Inténtalo de nuevo.',
        MotivoCalidad.senalPlana || null =>
          modo == ModoEscaner.dedo
              ? 'No llegamos a ver tu pulso. Cubre por completo la cámara y '
                    'el flash con la yema, sin apretar.'
              : 'No llegamos a ver tu pulso. Busca una luz pareja de frente '
                    '(una ventana), acércate un poco y quédate quieto.',
      };
}
