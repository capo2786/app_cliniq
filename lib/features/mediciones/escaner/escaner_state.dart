// lib/features/mediciones/escaner/escaner_state.dart

import 'package:equatable/equatable.dart';

import '../data/cola_mediciones.dart';
import '../data/models/medicion.dart';
import '../dominio/destinos_medico.dart';
import 'motor_signos_camara.dart';
import 'serie_senal.dart';

/// En qué paso va el escáner.
enum PasoEscaner {
  /// Mirando si ya aceptó el aviso.
  cargando,

  /// La primera vez: el aviso de función experimental.
  aviso,

  /// Elegir entre dedo y rostro.
  modo,

  /// Cómo poner el dedo o la cara.
  instrucciones,

  /// Pidiendo el permiso y encendiendo la cámara.
  abriendo,

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

  /// Cuánto dura la medición (`telemedicina.escanerSegundos`).
  final int segundos;
  final int segundosRestantes;

  final LecturaEnVivo lectura;
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
    this.modo = ModoEscaner.dedo,
    this.segundos = 30,
    this.segundosRestantes = 30,
    this.lectura = const LecturaEnVivo(),
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
    LecturaEnVivo? lectura,
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
      segundos: segundos,
      segundosRestantes: segundosRestantes ?? this.segundosRestantes,
      lectura: lectura ?? this.lectura,
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
    segundos,
    segundosRestantes,
    lectura,
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
