// lib/features/mediciones/escaner/motor_signos_camara.dart

import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../dominio/procesamiento_ppg.dart';
import '../dominio/reglas_mediciones.dart';
import 'serie_senal.dart';

/// Dónde se calculó el resultado.
enum OrigenAnalisis {
  /// En el propio teléfono, con [MotorInterno].
  telefono,

  /// En el servidor de la clínica, con la serie de números (nunca imágenes).
  servidor,
}

/// La variabilidad de la frecuencia cardiaca, en milisegundos.
class Vfc extends Equatable {
  final double sdnn;
  final double rmssd;

  const Vfc({required this.sdnn, required this.rmssd});

  @override
  List<Object?> get props => [sdnn, rmssd];
}

/// El resultado de una medición con la cámara.
class ResultadoEscaner extends Equatable {
  final ModoEscaner modo;

  /// Latidos por minuto, o `null` si no se pudo medir.
  final int? fc;

  /// Respiraciones por minuto (aproximada), solo con calidad suficiente.
  final int? fr;

  /// De 0 a 1.
  final double calidad;

  /// Solo si el servidor la calculó (con buena calidad y 30 s o más).
  final Vfc? vfc;

  /// Quién midió, como queda en las notas: «interno-ppg v1»,
  /// «senales-ms 1.0.0».
  final String motor;

  final OrigenAnalisis origen;

  /// Lo que el motor quiere que se sepa («Señal con movimiento»).
  final List<String> advertencias;

  /// Si no se pudo medir: qué hacer para la próxima.
  final String? consejo;

  const ResultadoEscaner({
    required this.modo,
    required this.calidad,
    required this.motor,
    this.fc,
    this.fr,
    this.vfc,
    this.origen = OrigenAnalisis.telefono,
    this.advertencias = const [],
    this.consejo,
  });

  /// Hay un valor que enseñar: una FC con la calidad mínima.
  bool get valido => fc != null && calidad >= calidadMinimaParaMostrar;

  NivelCalidad get nivel => nivelDeCalidad(calidad);

  /// La línea de las notas de la medición: «motor: interno-ppg v1».
  String get notas => 'motor: $motor';

  @override
  List<Object?> get props => [
    modo,
    fc,
    fr,
    calidad,
    vfc,
    motor,
    origen,
    advertencias,
    consejo,
  ];
}

/// Lo que se sabe mientras se mide: la calidad, el consejo del momento y la
/// onda para dibujar.
class LecturaEnVivo extends Equatable {
  /// De 0 a 1, o `null` mientras no hay segundos suficientes.
  final double? calidad;

  /// «Cubre bien la cámara», «Quédate quieto», «Más luz»… o `null`.
  final String? consejo;

  /// La señal filtrada de los últimos segundos, normalizada a −1…1.
  final List<double> onda;

  const LecturaEnVivo({this.calidad, this.consejo, this.onda = const []});

  @override
  List<Object?> get props => [calidad, consejo, onda];
}

/// Quien convierte la serie de la cámara en signos vitales.
///
/// El de esta aplicación es [MotorInterno], en el teléfono. La interfaz
/// existe para poder cambiar el cálculo sin tocar las pantallas: todo motor
/// recibe solo la [SerieSenal] (números) y nunca imágenes.
abstract class MotorSignosCamara {
  /// El nombre del motor para un modo, con su versión, como queda en las
  /// notas de la medición.
  String nombre(ModoEscaner modo);

  /// Lo que se puede decir con los últimos segundos (en vivo).
  LecturaEnVivo enVivo(SerieSenal serie);

  /// El resultado de la medición entera.
  ResultadoEscaner analizar(SerieSenal serie);
}

/// Los consejos del escáner, en un solo lugar.
class ConsejosEscaner {
  const ConsejosEscaner._();

  static const cubreLaCamara = 'Cubre bien la cámara y el flash con la yema';
  static const noAprietes = 'Apoya el dedo sin apretar';
  static const quedateQuieto = 'Quédate quieto';
  static const masLuz = 'Más luz';
  static const rostroEnElOvalo = 'Coloca tu rostro dentro del óvalo';

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

/// El motor de la aplicación: `dominio/procesamiento_ppg.dart`, en el
/// teléfono. En el modo dedo analiza el rojo (o la luminancia, si el rojo
/// está quemado); en el rostro, los tres canales con POS.
class MotorInterno implements MotorSignosCamara {
  const MotorInterno();

  static const String version = 'v1';

  @override
  String nombre(ModoEscaner modo) => switch (modo) {
    ModoEscaner.dedo => 'interno-ppg $version',
    ModoEscaner.rostro => 'interno-pos $version',
  };

  static double _media(List<double> x) =>
      x.isEmpty ? 0 : x.reduce((a, b) => a + b) / x.length;

  /// El canal del dedo: el rojo, con el signo cambiado (más sangre, menos
  /// luz); si más de la mitad del rojo está quemado, la luminancia.
  static ({List<double> valores, CondicionesDedo condiciones}) _canalDedo(
    SerieSenal serie,
  ) {
    final saturacion = _media(serie.saturacion);
    final usarLuminancia = saturacion > 0.5;
    return (
      valores: [
        for (final v in usarLuminancia ? serie.luminancia : serie.rojo) -v,
      ],
      condiciones: CondicionesDedo(
        cobertura: _media(serie.cobertura),
        // La luminancia mezcla el verde y el azul, que con la yema delante
        // están lejos de quemarse.
        saturacion: usarLuminancia ? 0 : saturacion,
      ),
    );
  }

  AnalisisPpg _analizar(SerieSenal serie, {bool conFr = true}) {
    switch (serie.modo) {
      case ModoEscaner.dedo:
        final canal = _canalDedo(serie);
        return analizarSenal(
          serie.tiempos,
          canal.valores,
          dedo: canal.condiciones,
          conFr: conFr,
        );
      case ModoEscaner.rostro:
        return analizarRostro(
          serie.tiempos,
          serie.rojo,
          serie.verde,
          serie.azul,
          conFr: conFr,
        );
    }
  }

  @override
  LecturaEnVivo enVivo(SerieSenal serie) {
    final ultimo = serie.ultimos(1.5);
    String? consejo;

    switch (serie.modo) {
      case ModoEscaner.dedo:
        if (_media(ultimo.cobertura) < 0.6) {
          consejo = ConsejosEscaner.cubreLaCamara;
        } else if (_media(ultimo.saturacion) > 0.9 &&
            _media(ultimo.luminancia) > 240) {
          consejo = ConsejosEscaner.noAprietes;
        }
      case ModoEscaner.rostro:
        if (_media(ultimo.cobertura) < 0.35) {
          consejo = ConsejosEscaner.rostroEnElOvalo;
        } else if (_media(ultimo.luminancia) < 60) {
          consejo = ConsejosEscaner.masLuz;
        }
    }

    final ventana = serie.ultimos(10);
    if (ventana.duracion < segundosMinimos) {
      return LecturaEnVivo(consejo: consejo);
    }

    final analisis = _analizar(ventana, conFr: false);
    final calidad = analisis.calidad.valor;
    if (consejo == null && calidad < umbralCalidadRegular) {
      consejo = switch (analisis.calidad.motivo) {
        MotivoCalidad.sinCobertura => ConsejosEscaner.cubreLaCamara,
        MotivoCalidad.saturada => ConsejosEscaner.noAprietes,
        MotivoCalidad.senalPlana when serie.modo == ModoEscaner.rostro =>
          ConsejosEscaner.masLuz,
        MotivoCalidad.senalPlana => ConsejosEscaner.cubreLaCamara,
        _ => ConsejosEscaner.quedateQuieto,
      };
    }

    return LecturaEnVivo(
      calidad: calidad,
      consejo: consejo,
      onda: _normalizar(analisis.senal, segundos: 6),
    );
  }

  /// Los últimos [segundos] de la onda, entre −1 y 1, para dibujarla.
  static List<double> _normalizar(List<double> senal, {required int segundos}) {
    final n = (segundos * frecuenciaAnalisis).round();
    final tramo = senal.length > n ? senal.sublist(senal.length - n) : senal;
    if (tramo.isEmpty) return const [];
    final maximo = tramo.map((v) => v.abs()).reduce(math.max);
    if (maximo <= 0) return List.filled(tramo.length, 0);
    // Hacia arriba es más sangre: el pico del latido.
    return [for (final v in tramo) v / maximo];
  }

  @override
  ResultadoEscaner analizar(SerieSenal serie) {
    final analisis = _analizar(serie);
    final calidad = analisis.calidad.valor;
    final fc = analisis.fc;
    final valido = fc != null && calidad >= calidadMinimaParaMostrar;

    return ResultadoEscaner(
      modo: serie.modo,
      fc: valido ? fc.round() : null,
      fr: valido && calidad >= calidadMinimaFr && analisis.fr != null
          ? analisis.fr!.round()
          : null,
      calidad: calidad,
      motor: nombre(serie.modo),
      consejo: valido
          ? null
          : ConsejosEscaner.paraElMotivo(analisis.calidad.motivo, serie.modo),
    );
  }
}
