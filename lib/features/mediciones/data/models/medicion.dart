// lib/features/mediciones/data/models/medicion.dart

import 'package:equatable/equatable.dart';

import '../../../../core/fechas/instante.dart';

/*
 * Las mediciones del paciente, con la forma de `/portal/mediciones` (ver
 * `mediciones_paciente` en el contrato del API).
 *
 * `medidoEn` y `creadoEn` son **instantes reales** (cuándo se midió de
 * verdad), no la hora congelada de las citas: se leen con `leerInstante` y
 * se enseñan en la hora de la clínica. Los códigos (tipo, método, contexto)
 * son del sistema y no cambian; sus nombres están en
 * `dominio/reglas_mediciones.dart`.
 */

String? _texto(Object? valor) {
  final texto = valor?.toString().trim();
  return texto == null || texto.isEmpty ? null : texto;
}

/// Un número de la API, o `null`: un valor que no llegó no es cero.
num? _numero(Object? valor) {
  if (valor is num) return valor.isFinite ? valor : null;
  if (valor is String) return num.tryParse(valor.trim());
  return null;
}

/// Qué se midió.
enum TipoMedicion {
  /// Frecuencia cardiaca (el pulso).
  fc('FC'),

  /// Frecuencia respiratoria.
  fr('FR'),

  /// Presión arterial: sistólica en `valor`, diastólica en `valor2`.
  pa('PA'),

  /// Saturación de oxígeno.
  spo2('SPO2'),

  temp('TEMP'),
  glucosa('GLUCOSA'),
  peso('PESO');

  /// Como lo escribe la API.
  final String codigo;

  const TipoMedicion(this.codigo);

  static TipoMedicion? desdeCodigo(Object? codigo) {
    final texto = codigo?.toString().toUpperCase().trim();
    for (final tipo in values) {
      if (tipo.codigo == texto) return tipo;
    }
    return null;
  }
}

/// Cómo se midió.
enum MetodoMedicion {
  /// Con la cámara trasera y el flash, la yema sobre la cámara.
  camaraDedo('CAMARA_DEDO'),

  /// Con la cámara frontal, el rostro (rPPG).
  camaraRostro('CAMARA_ROSTRO'),

  /// Con un aparato de casa: tensiómetro, oxímetro, termómetro, glucómetro
  /// o balanza.
  dispositivo('DISPOSITIVO'),

  /// A mano: el pulso o las respiraciones contados con el reloj.
  manual('MANUAL');

  final String codigo;

  const MetodoMedicion(this.codigo);

  /// De la cámara: experimental y referencial.
  bool get esCamara =>
      this == MetodoMedicion.camaraDedo || this == MetodoMedicion.camaraRostro;

  static MetodoMedicion? desdeCodigo(Object? codigo) {
    final texto = codigo?.toString().toUpperCase().trim();
    for (final metodo in values) {
      if (metodo.codigo == texto) return metodo;
    }
    return null;
  }
}

/// En qué momento se midió (opcional).
enum ContextoMedicion {
  reposo('REPOSO'),
  trasActividad('TRAS_ACTIVIDAD'),
  ayunas('AYUNAS'),
  posprandial('POSPRANDIAL');

  final String codigo;

  const ContextoMedicion(this.codigo);

  static ContextoMedicion? desdeCodigo(Object? codigo) {
    final texto = codigo?.toString().toUpperCase().trim();
    for (final contexto in values) {
      if (contexto.codigo == texto) return contexto;
    }
    return null;
  }
}

/// Una medición guardada en el servidor.
class Medicion extends Equatable {
  final String id;
  final String pacienteId;
  final TipoMedicion tipo;
  final num valor;

  /// Solo en la presión: la diastólica.
  final num? valor2;

  /// La unidad que fijó el servidor según el tipo, o `null` si no llegó.
  final String? unidad;

  final MetodoMedicion metodo;

  /// De 0 a 1, solo en las de la cámara.
  final double? calidad;

  final ContextoMedicion? contexto;
  final String? notas;

  /// Cuándo se midió (instante real, UTC).
  final DateTime medidoEn;

  final String? citaId;
  final String? consultaId;

  /// De la cámara: el servidor la marca como experimental.
  final bool experimental;

  /// La atención en que el médico la usó, si la usó: ya no se puede borrar.
  final String? usadaEnAtencionId;

  final DateTime? creadoEn;

  const Medicion({
    required this.id,
    required this.tipo,
    required this.valor,
    required this.metodo,
    required this.medidoEn,
    this.pacienteId = '',
    this.valor2,
    this.unidad,
    this.calidad,
    this.contexto,
    this.notas,
    this.citaId,
    this.consultaId,
    this.experimental = false,
    this.usadaEnAtencionId,
    this.creadoEn,
  });

  bool get usada => usadaEnAtencionId != null;

  /// Lee una medición de la API; `null` si le falta lo indispensable (un
  /// tipo o un método que esta versión no conoce, sin valor o sin fecha).
  static Medicion? desdeJson(Map<dynamic, dynamic> json) {
    final id = _texto(json['_id']) ?? _texto(json['id']);
    final tipo = TipoMedicion.desdeCodigo(json['tipo']);
    final metodo = MetodoMedicion.desdeCodigo(json['metodo']);
    final valor = _numero(json['valor']);
    final medidoEn = leerInstante(json['medidoEn']);
    if (id == null ||
        tipo == null ||
        metodo == null ||
        valor == null ||
        medidoEn == null) {
      return null;
    }

    final calidad = _numero(json['calidad'])?.toDouble();
    return Medicion(
      id: id,
      pacienteId: _texto(json['pacienteId']) ?? '',
      tipo: tipo,
      valor: valor,
      valor2: _numero(json['valor2']),
      unidad: _texto(json['unidad']),
      metodo: metodo,
      calidad: calidad?.clamp(0, 1).toDouble(),
      contexto: ContextoMedicion.desdeCodigo(json['contexto']),
      notas: _texto(json['notas']),
      medidoEn: medidoEn,
      citaId: _texto(json['citaId']),
      consultaId: _texto(json['consultaId']),
      experimental: json['experimental'] == true || metodo.esCamara,
      usadaEnAtencionId: _texto(json['usadaEnAtencionId']),
      creadoEn: leerInstante(json['creadoEn']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    pacienteId,
    tipo,
    valor,
    valor2,
    unidad,
    metodo,
    calidad,
    contexto,
    notas,
    medidoEn,
    citaId,
    consultaId,
    experimental,
    usadaEnAtencionId,
    creadoEn,
  ];
}

/// Una medición por enviar: lo que va en `mediciones[]` de
/// `POST /portal/mediciones`. La unidad no se manda: la fija el servidor.
class MedicionNueva extends Equatable {
  final TipoMedicion tipo;
  final num valor;
  final num? valor2;
  final MetodoMedicion metodo;
  final double? calidad;
  final ContextoMedicion? contexto;
  final String? notas;

  /// Cuándo se midió (instante real).
  final DateTime medidoEn;

  final String? citaId;
  final String? consultaId;

  const MedicionNueva({
    required this.tipo,
    required this.valor,
    required this.metodo,
    required this.medidoEn,
    this.valor2,
    this.calidad,
    this.contexto,
    this.notas,
    this.citaId,
    this.consultaId,
  });

  /// La misma medición, adjunta a una cita o a una consulta en línea.
  MedicionNueva adjuntaA({String? citaId, String? consultaId}) => MedicionNueva(
    tipo: tipo,
    valor: valor,
    valor2: valor2,
    metodo: metodo,
    calidad: calidad,
    contexto: contexto,
    notas: notas,
    medidoEn: medidoEn,
    citaId: citaId,
    consultaId: consultaId,
  );

  Map<String, dynamic> aJson() => {
    'tipo': tipo.codigo,
    'valor': valor,
    'valor2': ?valor2,
    'metodo': metodo.codigo,
    'calidad': ?calidad,
    'contexto': ?contexto?.codigo,
    'notas': ?notas,
    'medidoEn': aTextoInstante(medidoEn),
    'citaId': ?citaId,
    'consultaId': ?consultaId,
  };

  /// Lee una medición de la cola del teléfono (la forma de [aJson]).
  static MedicionNueva? desdeJson(Object? json) {
    if (json is! Map) return null;

    final tipo = TipoMedicion.desdeCodigo(json['tipo']);
    final metodo = MetodoMedicion.desdeCodigo(json['metodo']);
    final valor = _numero(json['valor']);
    final medidoEn = leerInstante(json['medidoEn']);
    if (tipo == null || metodo == null || valor == null || medidoEn == null) {
      return null;
    }

    return MedicionNueva(
      tipo: tipo,
      valor: valor,
      valor2: _numero(json['valor2']),
      metodo: metodo,
      calidad: _numero(json['calidad'])?.toDouble(),
      contexto: ContextoMedicion.desdeCodigo(json['contexto']),
      notas: _texto(json['notas']),
      medidoEn: medidoEn,
      citaId: _texto(json['citaId']),
      consultaId: _texto(json['consultaId']),
    );
  }

  @override
  List<Object?> get props => [
    tipo,
    valor,
    valor2,
    metodo,
    calidad,
    contexto,
    notas,
    medidoEn,
    citaId,
    consultaId,
  ];
}
