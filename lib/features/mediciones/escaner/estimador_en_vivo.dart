// lib/features/mediciones/escaner/estimador_en_vivo.dart

import '../dominio/procesamiento_ppg.dart';
import 'motor_signos_camara.dart';
import 'serie_senal.dart';

/// Lo que se ve mientras se mide, cada [cada] segundos: la lectura del
/// motor sobre los últimos ~10 s (calidad, consejo, onda y FC en vivo), la
/// historia de la FC para la mini gráfica y los latidos detectados.
///
/// Es puro: recibe la serie (números) y el tiempo medido. La FC en vivo es
/// solo una guía visual; el valor que se guarda es el del análisis de la
/// medición entera al terminar.
class EstimadorEnVivo {
  final MotorSignosCamara motor;
  final double cada;

  /// Un latido nuevo tiene que estar al menos a esta distancia del último
  /// contado (210 lpm), y no en el último trozo de la ventana, donde el
  /// filtro todavía no se asentó.
  static const double separacionMinima = 0.27;
  static const double margenFinal = 0.4;

  double _ultima = -1;
  final List<PuntoFc> _historial = [];
  final List<double> _latidos = [];

  EstimadorEnVivo({required this.motor, this.cada = 1});

  /// La FC de cada lectura que se pudo enseñar, por segundo medido.
  List<PuntoFc> get historial => List.unmodifiable(_historial);

  /// Cuántos latidos se detectaron (sin contar dos veces los que caen en
  /// ventanas que se solapan).
  int get latidos => _latidos.length;

  /// Una lectura nueva si ya toca (o `null`), con la [serie] de lo medido
  /// hasta ahora y los [medido] segundos que lleva.
  LecturaEnVivo? avanzar(SerieSenal serie, double medido) {
    if (_ultima >= 0 && medido - _ultima < cada) return null;
    _ultima = medido;

    final lectura = motor.enVivo(serie);
    if (lectura.fcVisible) {
      _historial.add((segundo: medido, fc: lectura.fc!));
      _contar(lectura.latidos, serie.tiempos.isEmpty ? 0 : serie.tiempos.last);
    }
    return lectura;
  }

  void _contar(List<double> latidos, double fin) {
    for (final t in latidos) {
      if (t > fin - margenFinal) break;
      if (_latidos.isEmpty || t - _latidos.last >= separacionMinima) {
        _latidos.add(t);
      }
    }
  }

  void reiniciar() {
    _ultima = -1;
    _historial.clear();
    _latidos.clear();
  }
}
