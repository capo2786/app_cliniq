// lib/features/mi_salud/data/models/mi_salud.dart

import 'package:equatable/equatable.dart';

import '../../../../core/archivos/archivo_meta.dart';
import '../../../../core/fechas/fecha_local.dart';

/*
 * «Mi salud»: lo que el paciente tiene derecho a ver de su historia clínica,
 * con la forma de `GET /portal/mi-salud` (ver `MiSalud` en el panel,
 * core/models/clinica.model.ts).
 *
 * Las fechas clínicas —el inicio de una atención, la fecha de una receta,
 * las últimas mediciones— son hora local de la clínica «congelada» como UTC,
 * igual que las citas: se leen con `leerFechaLocal`, que descarta la zona.
 * El próximo control es un día suelto (`AAAA-MM-DD`).
 */

String? _texto(Object? valor) {
  final texto = valor?.toString().trim();
  return texto == null || texto.isEmpty ? null : texto;
}

/// Un número de la API, o `null`: un signo vital que no se midió no es cero.
num? _numero(Object? valor) {
  if (valor is num) return valor.isFinite ? valor : null;
  if (valor is String) return num.tryParse(valor.trim());
  return null;
}

List<Map<dynamic, dynamic>> _mapas(Object? valor) => [
  if (valor is List)
    for (final item in valor)
      if (item is Map) item,
];

/// Un diagnóstico (CIE) de una atención o de un documento.
class DiagnosticoClinico extends Equatable {
  /// `CIE10` o `CIE11`.
  final String sistema;
  final String codigo;
  final String descripcion;

  /// `PRESUNTIVO` o `DEFINITIVO`.
  final String tipo;
  final bool principal;

  const DiagnosticoClinico({
    required this.codigo,
    required this.descripcion,
    this.sistema = '',
    this.tipo = '',
    this.principal = false,
  });

  /// Presuntivo: el médico todavía no lo confirmó.
  bool get porConfirmar => tipo.toUpperCase() == 'PRESUNTIVO';

  static DiagnosticoClinico? desdeJson(Map<dynamic, dynamic> json) {
    final codigo = _texto(json['codigo']) ?? '';
    final descripcion = _texto(json['descripcion']) ?? '';
    if (codigo.isEmpty && descripcion.isEmpty) return null;

    return DiagnosticoClinico(
      sistema: _texto(json['sistema']) ?? '',
      codigo: codigo,
      descripcion: descripcion.isEmpty ? codigo : descripcion,
      tipo: _texto(json['tipo']) ?? '',
      principal: json['principal'] == true,
    );
  }

  @override
  List<Object?> get props => [sistema, codigo, descripcion, tipo, principal];
}

List<DiagnosticoClinico> _diagnosticos(Object? valor) => [
  for (final json in _mapas(valor)) ?DiagnosticoClinico.desdeJson(json),
];

/// Un medicamento de una receta.
class ItemReceta extends Equatable {
  final String medicamento;
  final String? concentracion;
  final String? formaFarmaceutica;
  final String? via;
  final String dosis;
  final String frecuencia;
  final String duracion;
  final String? cantidad;
  final String? indicaciones;

  const ItemReceta({
    required this.medicamento,
    this.concentracion,
    this.formaFarmaceutica,
    this.via,
    this.dosis = '',
    this.frecuencia = '',
    this.duracion = '',
    this.cantidad,
    this.indicaciones,
  });

  /// «Amoxicilina 500 mg Cápsula»: lo que se pide en la farmacia.
  String get nombreCompleto =>
      [medicamento, ?concentracion, ?formaFarmaceutica].join(' ');

  /// «1 cápsula, cada 8 horas, 10 días»: cómo se toma.
  String get posologia => [
    dosis,
    frecuencia,
    duracion,
  ].where((parte) => parte.isNotEmpty).join(', ');

  static ItemReceta? desdeJson(Map<dynamic, dynamic> json) {
    final medicamento = _texto(json['medicamento']);
    if (medicamento == null) return null;

    return ItemReceta(
      medicamento: medicamento,
      concentracion: _texto(json['concentracion']),
      formaFarmaceutica: _texto(json['formaFarmaceutica']),
      via: _texto(json['via']),
      dosis: _texto(json['dosis']) ?? '',
      frecuencia: _texto(json['frecuencia']) ?? '',
      duracion: _texto(json['duracion']) ?? '',
      cantidad: _texto(json['cantidad']),
      indicaciones: _texto(json['indicaciones']),
    );
  }

  @override
  List<Object?> get props => [
    medicamento,
    concentracion,
    formaFarmaceutica,
    via,
    dosis,
    frecuencia,
    duracion,
    cantidad,
    indicaciones,
  ];
}

/// Un examen de una orden.
class ItemOrden extends Equatable {
  final String nombre;
  final String? codigo;
  final String? indicaciones;

  const ItemOrden({required this.nombre, this.codigo, this.indicaciones});

  static ItemOrden? desdeJson(Map<dynamic, dynamic> json) {
    final nombre = _texto(json['nombre']);
    if (nombre == null) return null;

    return ItemOrden(
      nombre: nombre,
      codigo: _texto(json['codigo']),
      indicaciones: _texto(json['indicaciones']),
    );
  }

  @override
  List<Object?> get props => [nombre, codigo, indicaciones];
}

/// Lo común a una receta y a una orden: quién la emitió, para quién, cuándo
/// y con qué código se verifica.
abstract class DocumentoClinico extends Equatable {
  final String id;
  final String atencionId;
  final String pacienteId;
  final String pacienteNombre;
  final String? pacienteCedula;
  final int? pacienteEdad;
  final String medicoNombre;
  final String? medicoEspecialidad;
  final String? medicoRegistro;

  /// Fecha de emisión, hora local de la clínica.
  final DateTime? fecha;

  final List<DiagnosticoClinico> diagnosticos;

  /// El código con que la farmacia o el laboratorio comprueban que es
  /// auténtico.
  final String codigoVerificacion;

  /// `EMITIDA` o `ANULADA`.
  final String estado;
  final String? anuladaMotivo;

  const DocumentoClinico({
    required this.id,
    this.atencionId = '',
    this.pacienteId = '',
    this.pacienteNombre = '',
    this.pacienteCedula,
    this.pacienteEdad,
    this.medicoNombre = '',
    this.medicoEspecialidad,
    this.medicoRegistro,
    this.fecha,
    this.diagnosticos = const [],
    this.codigoVerificacion = '',
    this.estado = 'EMITIDA',
    this.anuladaMotivo,
  });

  bool get anulada => estado.toUpperCase() == 'ANULADA';

  @override
  List<Object?> get props => [
    id,
    atencionId,
    pacienteId,
    pacienteNombre,
    pacienteCedula,
    pacienteEdad,
    medicoNombre,
    medicoEspecialidad,
    medicoRegistro,
    fecha,
    diagnosticos,
    codigoVerificacion,
    estado,
    anuladaMotivo,
  ];
}

/// Una receta (`GET /portal/recetas/:id` o dentro de Mi salud).
class Receta extends DocumentoClinico {
  final List<ItemReceta> items;
  final String? indicacionesNoFarmacologicas;

  const Receta({
    required super.id,
    super.atencionId,
    super.pacienteId,
    super.pacienteNombre,
    super.pacienteCedula,
    super.pacienteEdad,
    super.medicoNombre,
    super.medicoEspecialidad,
    super.medicoRegistro,
    super.fecha,
    super.diagnosticos,
    super.codigoVerificacion,
    super.estado,
    super.anuladaMotivo,
    this.items = const [],
    this.indicacionesNoFarmacologicas,
  });

  /// Lee una receta; lanza [FormatException] si no tiene identificador.
  factory Receta.desdeJson(Map<dynamic, dynamic> json) {
    final id = _texto(json['_id']);
    if (id == null) throw const FormatException('Receta sin identificador');

    final edad = _numero(json['pacienteEdad']);

    return Receta(
      id: id,
      atencionId: _texto(json['atencionId']) ?? '',
      pacienteId: _texto(json['pacienteId']) ?? '',
      pacienteNombre: _texto(json['pacienteNombre']) ?? '',
      pacienteCedula: _texto(json['pacienteCedula']),
      pacienteEdad: edad?.toInt(),
      medicoNombre: _texto(json['medicoNombre']) ?? '',
      medicoEspecialidad: _texto(json['medicoEspecialidad']),
      medicoRegistro: _texto(json['medicoRegistro']),
      fecha: leerFechaLocal(json['fecha']),
      diagnosticos: _diagnosticos(json['diagnosticos']),
      codigoVerificacion: _texto(json['codigoVerificacion']) ?? '',
      estado: _texto(json['estado'])?.toUpperCase() ?? 'EMITIDA',
      anuladaMotivo: _texto(json['anuladaMotivo']),
      items: [
        for (final item in _mapas(json['items'])) ?ItemReceta.desdeJson(item),
      ],
      indicacionesNoFarmacologicas: _texto(
        json['indicacionesNoFarmacologicas'],
      ),
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    items,
    indicacionesNoFarmacologicas,
  ];
}

/// De qué es una orden. Solo el código y su lógica, como en el panel.
enum TipoOrden {
  laboratorio('LABORATORIO'),
  imagen('IMAGEN'),
  otro('OTRO');

  final String codigo;

  const TipoOrden(this.codigo);

  static TipoOrden desdeCodigo(Object? codigo) {
    final texto = codigo?.toString().toUpperCase().trim();

    return TipoOrden.values.firstWhere(
      (tipo) => tipo.codigo == texto,
      orElse: () => TipoOrden.otro,
    );
  }
}

/// Una orden de laboratorio, de imagen u otra (`GET /portal/ordenes/:id` o
/// dentro de Mi salud).
class Orden extends DocumentoClinico {
  final TipoOrden tipo;
  final List<ItemOrden> items;

  /// `RUTINA` o `URGENTE`.
  final String prioridad;
  final String? observaciones;

  const Orden({
    required super.id,
    super.atencionId,
    super.pacienteId,
    super.pacienteNombre,
    super.pacienteCedula,
    super.pacienteEdad,
    super.medicoNombre,
    super.medicoEspecialidad,
    super.medicoRegistro,
    super.fecha,
    super.diagnosticos,
    super.codigoVerificacion,
    super.estado,
    super.anuladaMotivo,
    this.tipo = TipoOrden.otro,
    this.items = const [],
    this.prioridad = 'RUTINA',
    this.observaciones,
  });

  bool get urgente => prioridad.toUpperCase() == 'URGENTE';

  /// Lee una orden; lanza [FormatException] si no tiene identificador.
  factory Orden.desdeJson(Map<dynamic, dynamic> json) {
    final id = _texto(json['_id']);
    if (id == null) throw const FormatException('Orden sin identificador');

    final edad = _numero(json['pacienteEdad']);

    return Orden(
      id: id,
      atencionId: _texto(json['atencionId']) ?? '',
      pacienteId: _texto(json['pacienteId']) ?? '',
      pacienteNombre: _texto(json['pacienteNombre']) ?? '',
      pacienteCedula: _texto(json['pacienteCedula']),
      pacienteEdad: edad?.toInt(),
      medicoNombre: _texto(json['medicoNombre']) ?? '',
      medicoEspecialidad: _texto(json['medicoEspecialidad']),
      medicoRegistro: _texto(json['medicoRegistro']),
      fecha: leerFechaLocal(json['fecha']),
      diagnosticos: _diagnosticos(json['diagnosticos']),
      codigoVerificacion: _texto(json['codigoVerificacion']) ?? '',
      estado: _texto(json['estado'])?.toUpperCase() ?? 'EMITIDA',
      anuladaMotivo: _texto(json['anuladaMotivo']),
      tipo: TipoOrden.desdeCodigo(json['tipo']),
      items: [
        for (final item in _mapas(json['items'])) ?ItemOrden.desdeJson(item),
      ],
      prioridad: _texto(json['prioridad'])?.toUpperCase() ?? 'RUTINA',
      observaciones: _texto(json['observaciones']),
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    tipo,
    items,
    prioridad,
    observaciones,
  ];
}

/// Las últimas mediciones registradas en una atención cerrada.
class SignosVitales extends Equatable {
  /// Cuándo se midieron (la atención), hora local de la clínica.
  final DateTime? fecha;

  final num? presionSistolica;
  final num? presionDiastolica;
  final num? frecuenciaCardiaca;
  final num? temperatura;
  final num? saturacionO2;
  final num? pesoKg;
  final num? tallaCm;
  final num? imc;
  final num? glucemiaMgDl;

  const SignosVitales({
    this.fecha,
    this.presionSistolica,
    this.presionDiastolica,
    this.frecuenciaCardiaca,
    this.temperatura,
    this.saturacionO2,
    this.pesoKg,
    this.tallaCm,
    this.imc,
    this.glucemiaMgDl,
  });

  static SignosVitales? desdeJson(Object? json) {
    if (json is! Map) return null;

    return SignosVitales(
      fecha: leerFechaLocal(json['fecha']),
      presionSistolica: _numero(json['presionSistolica']),
      presionDiastolica: _numero(json['presionDiastolica']),
      frecuenciaCardiaca: _numero(json['frecuenciaCardiaca']),
      temperatura: _numero(json['temperatura']),
      saturacionO2: _numero(json['saturacionO2']),
      pesoKg: _numero(json['pesoKg']),
      tallaCm: _numero(json['tallaCm']),
      imc: _numero(json['imc']),
      glucemiaMgDl: _numero(json['glucemiaMgDl']),
    );
  }

  @override
  List<Object?> get props => [
    fecha,
    presionSistolica,
    presionDiastolica,
    frecuenciaCardiaca,
    temperatura,
    saturacionO2,
    pesoKg,
    tallaCm,
    imc,
    glucemiaMgDl,
  ];
}

/// La ficha del paciente que se enseña en Mi salud.
class FichaClinica extends Equatable {
  final String uid;
  final String nombre;
  final int? edad;

  /// Códigos de los catálogos `SEXO` y `TIPO_SANGRE`.
  final String? sexo;
  final String? tipoSangre;

  final String? alergias;
  final String? antecedentesPersonales;
  final String? medicacionHabitual;

  /// Embarazo en curso y la fecha de la última menstruación (`AAAA-MM-DD`).
  final bool embarazoActual;
  final String? fum;

  const FichaClinica({
    required this.uid,
    required this.nombre,
    this.edad,
    this.sexo,
    this.tipoSangre,
    this.alergias,
    this.antecedentesPersonales,
    this.medicacionHabitual,
    this.embarazoActual = false,
    this.fum,
  });

  factory FichaClinica.desdeJson(Map<dynamic, dynamic> json) {
    final embarazo = json['embarazo'];
    final edad = _numero(json['edad']);

    return FichaClinica(
      uid: _texto(json['uid']) ?? '',
      nombre: _texto(json['nombre']) ?? '',
      edad: edad?.toInt(),
      sexo: _texto(json['sexo']),
      tipoSangre: _texto(json['tipoSangre']),
      alergias: _texto(json['alergias']),
      antecedentesPersonales: _texto(json['antecedentesPersonales']),
      medicacionHabitual: _texto(json['medicacionHabitual']),
      embarazoActual: embarazo is Map && embarazo['actual'] == true,
      fum: embarazo is Map ? _texto(embarazo['fum']) : null,
    );
  }

  @override
  List<Object?> get props => [
    uid,
    nombre,
    edad,
    sexo,
    tipoSangre,
    alergias,
    antecedentesPersonales,
    medicacionHabitual,
    embarazoActual,
    fum,
  ];
}

/// Una atención cerrada, con lo que el paciente puede ver de ella.
class AtencionMiSalud extends Equatable {
  final String id;

  /// Hora local de la clínica.
  final DateTime? inicio;

  final String medicoNombre;
  final String especialidad;

  /// Código del catálogo `MODALIDAD_CITA`.
  final String tipo;

  final String motivoConsulta;
  final List<DiagnosticoClinico> diagnosticos;

  /// Las indicaciones del médico.
  final String plan;

  /// Las recomendaciones que no son medicamentos.
  final String indicacionesNoFarmacologicas;

  /// El día del próximo control, si lo hay.
  final DateTime? proximoControl;

  final List<Receta> recetas;
  final List<Orden> ordenes;

  /// Los adjuntos clínicos (fotos, exámenes).
  final List<ArchivoMeta> adjuntos;

  const AtencionMiSalud({
    required this.id,
    this.inicio,
    this.medicoNombre = '',
    this.especialidad = '',
    this.tipo = '',
    this.motivoConsulta = '',
    this.diagnosticos = const [],
    this.plan = '',
    this.indicacionesNoFarmacologicas = '',
    this.proximoControl,
    this.recetas = const [],
    this.ordenes = const [],
    this.adjuntos = const [],
  });

  static AtencionMiSalud? desdeJson(Map<dynamic, dynamic> json) {
    final id = _texto(json['_id']);
    if (id == null) return null;

    return AtencionMiSalud(
      id: id,
      inicio: leerFechaLocal(json['inicio']),
      medicoNombre: _texto(json['medicoNombre']) ?? '',
      especialidad: _texto(json['especialidad']) ?? '',
      tipo: _texto(json['tipo'])?.toUpperCase() ?? '',
      motivoConsulta: _texto(json['motivoConsulta']) ?? '',
      diagnosticos: _diagnosticos(json['diagnosticos']),
      plan: _texto(json['plan']) ?? '',
      indicacionesNoFarmacologicas:
          _texto(json['indicacionesNoFarmacologicas']) ?? '',
      proximoControl: deFechaIso(_texto(json['proximoControl'])),
      recetas: [
        for (final receta in _mapas(json['recetas']))
          ?_intentar(() => Receta.desdeJson(receta)),
      ],
      ordenes: [
        for (final orden in _mapas(json['ordenes']))
          ?_intentar(() => Orden.desdeJson(orden)),
      ],
      adjuntos: interpretarArchivos(json['adjuntos']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    inicio,
    medicoNombre,
    especialidad,
    tipo,
    motivoConsulta,
    diagnosticos,
    plan,
    indicacionesNoFarmacologicas,
    proximoControl,
    recetas,
    ordenes,
    adjuntos,
  ];
}

T? _intentar<T>(T Function() leer) {
  try {
    return leer();
  } on FormatException {
    return null;
  }
}

/// Todo Mi salud: la ficha, las últimas mediciones y las atenciones, las
/// recientes primero (así las ordena el servidor).
class MiSalud extends Equatable {
  final FichaClinica paciente;
  final SignosVitales? ultimosSignos;
  final List<AtencionMiSalud> atenciones;

  const MiSalud({
    required this.paciente,
    this.ultimosSignos,
    this.atenciones = const [],
  });

  /// Lee la respuesta; lanza [FormatException] si no trae al paciente.
  /// Una atención ilegible se salta: las demás se enseñan igual.
  factory MiSalud.desdeJson(Object? json) {
    if (json is! Map || json['paciente'] is! Map) {
      throw const FormatException('Mi salud sin paciente');
    }

    return MiSalud(
      paciente: FichaClinica.desdeJson(json['paciente'] as Map),
      ultimosSignos: SignosVitales.desdeJson(json['ultimosSignos']),
      atenciones: [
        for (final atencion in _mapas(json['atenciones']))
          ?AtencionMiSalud.desdeJson(atencion),
      ],
    );
  }

  @override
  List<Object?> get props => [paciente, ultimosSignos, atenciones];
}
