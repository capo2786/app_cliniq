// lib/features/mediciones/escaner/control_de_medicion.dart

import 'rostro/guia_encuadre.dart';
import 'serie_senal.dart';

/// En qué va la medición mientras la cámara está abierta.
enum FaseMedicion {
  /// Modo rostro: esperando que la cara esté bien encuadrada («Preparando…»).
  preparando,

  /// Contando: los cuadros entran en la serie.
  midiendo,

  /// Modo rostro: se perdió la cara más de [ControlDeMedicion.segundosParaPausar]
  /// y la cuenta espera a que vuelva.
  pausada,
}

/// Qué pasó con un cuadro.
enum EventoDeMedicion {
  ninguno,

  /// La cara estuvo bien encuadrada el tiempo pedido y empezó la cuenta.
  arranco,

  /// Se perdió la cara: la cuenta se pausa.
  pausa,

  /// Volvió bien encuadrada: la cuenta sigue.
  reanudo,

  /// La cara no volvió en [ControlDeMedicion.segundosParaPerder]: se detiene.
  perdida,

  /// Se completaron los segundos de la medición.
  completa,
}

/// La cuenta de la medición, cuadro a cuadro. Pura: todo va con el tiempo
/// de los propios cuadros, sin relojes.
///
/// - **Dedo** ([conEncuadre] en falso): mide desde el primer cuadro.
/// - **Rostro:** la cuenta arranca sola cuando la [GuiaDeEncuadre] dice
///   «Perfecto» durante [segundosParaArrancar] seguidos. Si la cara se
///   pierde más de [segundosParaPausar], se pausa y se quitan de la serie
///   los cuadros desde que se perdió (se medían con una región vieja); al
///   volver bien encuadrada, sigue donde iba, sin el hueco. Si no vuelve en
///   [segundosParaPerder], la medición se da por perdida.
class ControlDeMedicion {
  static const double segundosParaArrancar = 1;
  static const double segundosParaPausar = 2;
  static const double segundosParaPerder = 8;

  final int segundos;
  final bool conEncuadre;
  final GuiaDeEncuadre _guia;

  FaseMedicion _fase;
  InstruccionEncuadre? _instruccion;
  final List<CuadroPpg> _cuadros = [];
  double? _bienDesde;
  double? _ultimoConRostro;
  double? _ultimoGuardado;
  double _desfase = 0;
  double _intervalo = 1 / 30;

  ControlDeMedicion({
    required this.segundos,
    required this.conEncuadre,
    GuiaDeEncuadre? guia,
  }) : _guia = guia ?? GuiaDeEncuadre(),
       _fase = conEncuadre ? FaseMedicion.preparando : FaseMedicion.midiendo;

  FaseMedicion get fase => _fase;

  /// La instrucción de la guía para el último cuadro (modo rostro).
  InstruccionEncuadre? get instruccion => _instruccion;

  /// Los cuadros de la serie, con los tiempos ya sin los huecos de las
  /// pausas.
  List<CuadroPpg> get cuadros => List.unmodifiable(_cuadros);

  /// Los segundos medidos de verdad.
  double get medido => _cuadros.length < 2
      ? 0
      : _cuadros.last.segundos - _cuadros.first.segundos;

  int get restantes => (segundos - medido).ceil().clamp(0, segundos);

  EventoDeMedicion alCuadro(CuadroPpg cuadro) {
    final t = cuadro.segundos;
    if (!conEncuadre) return _guardar(cuadro);

    final instruccion = _guia.evaluar(cuadro);
    _instruccion = instruccion;
    final conRostro = instruccion.hayRostro;

    switch (_fase) {
      case FaseMedicion.preparando:
        if (!_listo(instruccion, t)) return EventoDeMedicion.ninguno;
        _fase = FaseMedicion.midiendo;
        _ultimoConRostro = t;
        _guardar(cuadro);
        return EventoDeMedicion.arranco;

      case FaseMedicion.midiendo:
        if (conRostro) {
          _ultimoConRostro = t;
        } else if (t - (_ultimoConRostro ?? t) > segundosParaPausar) {
          _pausar();
          return EventoDeMedicion.pausa;
        }
        return _guardar(cuadro);

      case FaseMedicion.pausada:
        if (conRostro) {
          _ultimoConRostro = t;
        } else if (t - (_ultimoConRostro ?? t) > segundosParaPerder) {
          return EventoDeMedicion.perdida;
        }
        if (!_listo(instruccion, t)) return EventoDeMedicion.ninguno;
        _reanudar(t);
        _fase = FaseMedicion.midiendo;
        _guardar(cuadro);
        return EventoDeMedicion.reanudo;
    }
  }

  /// Bien encuadrada durante [segundosParaArrancar] seguidos.
  bool _listo(InstruccionEncuadre instruccion, double t) {
    if (!instruccion.bien) {
      _bienDesde = null;
      return false;
    }
    _bienDesde ??= t;
    return t - _bienDesde! >= segundosParaArrancar;
  }

  EventoDeMedicion _guardar(CuadroPpg cuadro) {
    final t = cuadro.segundos;
    final anterior = _ultimoGuardado;
    if (anterior != null) {
      final dt = t - anterior;
      if (dt > 0 && dt < 0.2) _intervalo = 0.9 * _intervalo + 0.1 * dt;
    }
    _ultimoGuardado = t;
    _cuadros.add(
      _desfase == 0
          ? cuadro
          : cuadro.conMomento(
              cuadro.momento - Duration(microseconds: (_desfase * 1e6).round()),
            ),
    );
    return medido >= segundos
        ? EventoDeMedicion.completa
        : EventoDeMedicion.ninguno;
  }

  /// Se quitan los cuadros desde que se perdió la cara.
  void _pausar() {
    final desde = (_ultimoConRostro ?? double.infinity) - _desfase;
    _cuadros.removeWhere((c) => c.segundos > desde);
    _ultimoGuardado = _cuadros.isEmpty
        ? null
        : _cuadros.last.segundos + _desfase;
    _fase = FaseMedicion.pausada;
    _bienDesde = null;
  }

  /// El cuadro de [t] va justo después del último guardado.
  void _reanudar(double t) {
    final anterior = _ultimoGuardado;
    if (anterior != null) _desfase += (t - anterior) - _intervalo;
  }
}
