// lib/features/mediciones/escaner/escaner_state.dart

import 'package:equatable/equatable.dart';

import '../data/cola_mediciones.dart';
import '../data/models/medicion.dart';
import '../dominio/destinos_medico.dart';
import '../dominio/procesamiento_ppg.dart';
import 'control_de_medicion.dart';
import 'motor_signos_camara.dart';
import 'rostro/guia_encuadre.dart';
import 'serie_senal.dart';

export 'control_de_medicion.dart' show FaseMedicion;
export 'rostro/guia_encuadre.dart' show InstruccionEncuadre;

/// En qué paso va el escáner.
enum PasoEscaner {
  /// Mirando si ya aceptó el aviso.
  cargando,

  /// La primera vez: el aviso de función experimental.
  aviso,

  /// Elegir entre rostro y dedo (solo con el modo dedo encendido).
  modo,

  /// Cómo poner el dedo o la cara.
  instrucciones,

  /// Pidiendo el permiso y encendiendo la cámara.
  abriendo,

  /// La cámara está abierta: preparando, midiendo o en pausa ([FaseMedicion]).
  midiendo,

  /// La medición terminó; se calcula (en el teléfono y, si hay red, en el
  /// servidor).
  analizando,

  resultado,

  /// No se pudo medir: un consejo y «Reintentar».
  fallo,

  /// Se guardó (o quedó pendiente de enviar).
  guardado,
}

class EscanerState extends Equatable {
  final PasoEscaner paso;
  final ModoEscaner modo;

  /// Si la clínica ofrece el modo dedo (`telemedicina.escanerDedoActivo`):
  /// sin él no hay selector de modo.
  final bool dedoActivo;

  /// Cuánto dura la medición (`telemedicina.escanerSegundos`).
  final int segundos;
  final int segundosRestantes;

  /// Mientras la cámara está abierta.
  final FaseMedicion fase;

  /// Modo rostro: la instrucción de la guía de encuadre.
  final InstruccionEncuadre? instruccion;

  /// Modo rostro: ML Kit no está y el rostro se busca por el color de la
  /// piel (no hay malla).
  final bool porColorDePiel;

  final LecturaEnVivo lectura;

  /// La FC en vivo de cada segundo, para la mini gráfica.
  final List<PuntoFc> historialFc;

  /// Los latidos detectados hasta ahora.
  final int latidos;

  final ResultadoEscaner? resultado;

  /// Por qué no se pudo medir, y qué hacer.
  final String? fallo;

  /// El fallo se arregla en los ajustes del teléfono (el permiso).
  final bool fallaPorPermiso;

  /// En qué momento se midió (lo elige la persona en el resultado).
  final ContextoMedicion? contexto;

  final bool guardando;
  final ResultadoRegistro? registro;

  /// A quién se mandó, si se mandó al médico.
  final DestinoMedico? enviadaA;

  final String? errorAlGuardar;

  const EscanerState({
    this.paso = PasoEscaner.cargando,
    this.modo = ModoEscaner.rostro,
    this.dedoActivo = false,
    this.segundos = 30,
    this.segundosRestantes = 30,
    this.fase = FaseMedicion.preparando,
    this.instruccion,
    this.porColorDePiel = false,
    this.lectura = const LecturaEnVivo(),
    this.historialFc = const [],
    this.latidos = 0,
    this.resultado,
    this.fallo,
    this.fallaPorPermiso = false,
    this.contexto,
    this.guardando = false,
    this.registro,
    this.enviadaA,
    this.errorAlGuardar,
  });

  /// La fracción ya medida, de 0 a 1.
  double get avance => segundos <= 0
      ? 0
      : ((segundos - segundosRestantes) / segundos).clamp(0, 1).toDouble();

  EscanerState copiarCon({
    PasoEscaner? paso,
    ModoEscaner? modo,
    int? segundosRestantes,
    FaseMedicion? fase,
    InstruccionEncuadre? instruccion,
    bool limpiarInstruccion = false,
    bool? porColorDePiel,
    LecturaEnVivo? lectura,
    List<PuntoFc>? historialFc,
    int? latidos,
    ResultadoEscaner? resultado,
    bool limpiarResultado = false,
    String? fallo,
    bool limpiarFallo = false,
    bool? fallaPorPermiso,
    ContextoMedicion? contexto,
    bool limpiarContexto = false,
    bool? guardando,
    ResultadoRegistro? registro,
    bool limpiarRegistro = false,
    DestinoMedico? enviadaA,
    String? errorAlGuardar,
    bool limpiarError = false,
  }) {
    return EscanerState(
      paso: paso ?? this.paso,
      modo: modo ?? this.modo,
      dedoActivo: dedoActivo,
      segundos: segundos,
      segundosRestantes: segundosRestantes ?? this.segundosRestantes,
      fase: fase ?? this.fase,
      instruccion: limpiarInstruccion
          ? null
          : (instruccion ?? this.instruccion),
      porColorDePiel: porColorDePiel ?? this.porColorDePiel,
      lectura: lectura ?? this.lectura,
      historialFc: historialFc ?? this.historialFc,
      latidos: latidos ?? this.latidos,
      resultado: limpiarResultado ? null : (resultado ?? this.resultado),
      fallo: limpiarFallo ? null : (fallo ?? this.fallo),
      fallaPorPermiso: limpiarFallo
          ? false
          : (fallaPorPermiso ?? this.fallaPorPermiso),
      contexto: limpiarContexto ? null : (contexto ?? this.contexto),
      guardando: guardando ?? this.guardando,
      registro: limpiarRegistro ? null : (registro ?? this.registro),
      enviadaA: limpiarRegistro ? null : (enviadaA ?? this.enviadaA),
      errorAlGuardar: limpiarError
          ? null
          : (errorAlGuardar ?? this.errorAlGuardar),
    );
  }

  @override
  List<Object?> get props => [
    paso,
    modo,
    dedoActivo,
    segundos,
    segundosRestantes,
    fase,
    instruccion,
    porColorDePiel,
    lectura,
    historialFc,
    latidos,
    resultado,
    fallo,
    fallaPorPermiso,
    contexto,
    guardando,
    registro,
    enviadaA,
    errorAlGuardar,
  ];
}
