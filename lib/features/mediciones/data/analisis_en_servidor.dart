// lib/features/mediciones/data/analisis_en_servidor.dart

import 'dart:async';

import 'package:dio/dio.dart';

import '../dominio/procesamiento_ppg.dart' show calidadMinimaFr;
import 'models/medicion.dart';
import '../dominio/reglas_mediciones.dart';
import '../escaner/motor_signos_camara.dart';
import '../escaner/serie_senal.dart';

/// El análisis experimental en el servidor de la clínica:
/// `POST /portal/mediciones/analizar`.
///
/// Se le manda **solo la serie de números** de la medición
/// ([SerieSenal.aJsonParaAnalisis]: el método, los tiempos en ms y los
/// promedios por cuadro), nunca imágenes. El servidor no guarda nada:
/// calcula y responde `{fc, fr?, vfc?: {sdnn, rmssd}, calidad, motor,
/// advertencias}`. Si no responde en [plazo], quien lo usa sigue con el
/// cálculo del teléfono.
class AnalisisEnServidor {
  static const String ruta = '/portal/mediciones/analizar';

  /// Lo que se espera al servidor.
  static const Duration plazo = Duration(seconds: 10);

  /// El servidor acepta de 10 a 90 segundos.
  static const double segundosMinimos = 10;
  static const double segundosMaximos = 90;

  final Dio _dio;

  AnalisisEnServidor(this._dio);

  /// Si la serie se puede mandar (el servidor rechaza lo que no cumple).
  static bool admite(SerieSenal serie) =>
      serie.duracion >= segundosMinimos &&
      serie.duracion <= segundosMaximos &&
      serie.length <= 6000;

  Future<ResultadoEscaner> analizar(SerieSenal serie) async {
    final respuesta = await _dio
        .post<dynamic>(
          ruta,
          data: serie.aJsonParaAnalisis(),
          options: Options(sendTimeout: plazo, receiveTimeout: plazo),
        )
        .timeout(plazo);
    return leerResultado(respuesta.data, serie.modo);
  }

  /// Lee la respuesta con las reglas de la aplicación: sin la calidad
  /// mínima no hay valor que enseñar, y la FR solo con calidad ≥ 0,6.
  static ResultadoEscaner leerResultado(Object? datos, ModoEscaner modo) {
    if (datos is! Map) {
      throw const FormatException('El análisis no es un objeto');
    }

    num? numero(Object? valor) => valor is num && valor.isFinite ? valor : null;

    final calidad = numero(datos['calidad'])?.toDouble();
    if (calidad == null) {
      throw const FormatException('El análisis no trae la calidad');
    }
    final motor = datos['motor']?.toString().trim();
    final advertencias = [
      if (datos['advertencias'] is List)
        for (final a in datos['advertencias'] as List)
          if (a.toString().trim().isNotEmpty) a.toString().trim(),
    ];

    final c = calidad.clamp(0, 1).toDouble();
    final fc = numero(datos['fc']);
    final fr = numero(datos['fr']);
    final valido =
        fc != null &&
        c >= calidadMinimaParaMostrar &&
        rangoDelTipo(TipoMedicion.fc).contiene(fc);

    Vfc? vfc;
    final crudo = datos['vfc'];
    if (valido && crudo is Map) {
      final sdnn = numero(crudo['sdnn']);
      final rmssd = numero(crudo['rmssd']);
      if (sdnn != null && rmssd != null) {
        vfc = Vfc(sdnn: sdnn.toDouble(), rmssd: rmssd.toDouble());
      }
    }

    return ResultadoEscaner(
      modo: modo,
      fc: valido ? fc.round() : null,
      fr:
          valido &&
              c >= calidadMinimaFr &&
              fr != null &&
              rangoDelTipo(TipoMedicion.fr).contiene(fr)
          ? fr.round()
          : null,
      calidad: c,
      vfc: vfc,
      motor: motor == null || motor.isEmpty ? 'senales-ms' : motor,
      origen: OrigenAnalisis.servidor,
      advertencias: advertencias,
      consejo: valido
          ? null
          : advertencias.isNotEmpty
          ? advertencias.join(' ')
          : ConsejosEscaner.paraElMotivo(null, modo),
    );
  }
}
