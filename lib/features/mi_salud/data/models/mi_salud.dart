// lib/features/mi_salud/data/models/mi_salud.dart

import 'package:equatable/equatable.dart';

import '../../../../core/archivos/archivo_meta.dart';
import '../../../../core/fechas/fecha_local.dart';
import '../../../../core/fechas/instante.dart';

/*
 * «Mi salud»: lo que el paciente tiene derecho a ver de su historia clínica,
 * con la forma de `GET /portal/mi-salud` (ver `MiSalud` en el panel,
 * core/models/clinica.model.ts).
 *
 * Las fechas clínicas —el inicio de una atención, la fecha de una receta,
 * las últimas mediciones— son hora local de la clínica «congelada» como UTC,
 * igual que las citas: se leen con `leerFechaLocal`, que descarta la zona.
 * El próximo control es un día suelto (`AAAA-MM-DD`), igual que las fechas
 * de un certificado de reposo. El momento de una firma electrónica, en
 * cambio, es un instante de verdad y se lee con `leerInstante`.
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

/// Un día suelto (`AAAA-MM-DD`). Si llega con hora (`2026-09-28T00:00…`),
/// cuenta solo el día escrito: no se convierte de zona.
DateTime? _dia(Object? valor) {
  final texto = _texto(valor);
  if (texto == null || texto.length < 10) return null;

  return deFechaIso(texto.substring(0, 10));
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

  /// La cantidad en letras, como la escribe el servidor («treinta»). Las
  /// recetas viejas no la traen.
  final String? cantidadEnLetras;

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
    this.cantidadEnLetras,
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

  /// «500 mg · Cápsula»: la concentración y la forma farmacéutica, o
  /// `null` si no trae ninguna.
  String? get presentacion {
    final partes = [?concentracion, ?formaFarmaceutica];
    return partes.isEmpty ? null : partes.join(' · ');
  }

  /// «30 (treinta)»: la cantidad a dispensar en números y en letras, o
  /// `null` si la receta no la trae (las viejas).
  String? get cantidadADispensar {
    final numero = cantidad;
    if (numero == null) return null;

    final letras = cantidadEnLetras;
    return letras == null ? numero : '$numero ($letras)';
  }

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
      cantidadEnLetras: _texto(json['cantidadEnLetras']),
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
    cantidadEnLetras,
    indicaciones,
  ];
}

/// Un examen de una orden.
class ItemOrden extends Equatable {
  final String nombre;
  final String? codigo;

  /// El área del examen («Hematología», «Ecografía»): el grupo del catálogo
  /// de exámenes con que el médico lo eligió. Las órdenes viejas no la
  /// traen.
  final String? grupo;

  final String? indicaciones;

  const ItemOrden({
    required this.nombre,
    this.codigo,
    this.grupo,
    this.indicaciones,
  });

  static ItemOrden? desdeJson(Map<dynamic, dynamic> json) {
    final nombre = _texto(json['nombre']);
    if (nombre == null) return null;

    return ItemOrden(
      nombre: nombre,
      codigo: _texto(json['codigo']),
      grupo: _texto(json['grupo']),
      indicaciones: _texto(json['indicaciones']),
    );
  }

  @override
  List<Object?> get props => [nombre, codigo, grupo, indicaciones];
}

/// La firma electrónica de una receta o de un certificado: quién la firmó
/// (el nombre de su certificado), cuándo, qué entidad emitió ese certificado
/// y la huella (sha256) del PDF firmado.
///
/// Se lee de `firma` tal como la manda el portal. Acepta las dos formas del
/// contrato: la del documento (`certificado.nombre`, `certificado.emisor`,
/// `sha256Firmado`) y la resumida de la verificación pública (`firmadoPor`,
/// `emisor`, `sha256`). La clave privada y el `.p12` nunca pasan por aquí.
class FirmaElectronica extends Equatable {
  /// El nombre del certificado con que se firmó.
  final String? firmadoPor;

  /// La entidad certificadora que emitió ese certificado.
  final String? emisor;

  /// Cuándo se firmó: un instante real, en UTC.
  final DateTime? firmadoEn;

  /// La huella sha256 del PDF firmado, en hexadecimal y minúsculas, o `null`
  /// si no llegó o no es una huella.
  final String? sha256;

  const FirmaElectronica({
    this.firmadoPor,
    this.emisor,
    this.firmadoEn,
    this.sha256,
  });

  /// `null` si no es un objeto.
  static FirmaElectronica? desdeJson(Object? json) {
    if (json is! Map) return null;

    final certificado = json['certificado'];
    final delCertificado = certificado is Map ? certificado : const {};

    return FirmaElectronica(
      firmadoPor:
          _texto(json['firmadoPor']) ?? _texto(delCertificado['nombre']),
      emisor: _texto(json['emisor']) ?? _texto(delCertificado['emisor']),
      firmadoEn: leerInstante(json['firmadoEn']),
      sha256: huellaSha256(json['sha256Firmado'] ?? json['sha256']),
    );
  }

  @override
  List<Object?> get props => [firmadoPor, emisor, firmadoEn, sha256];
}

final RegExp _huella = RegExp(r'^[0-9a-f]{64}$');

/// Una huella sha256 en hexadecimal (64 caracteres), en minúsculas, o
/// `null` si [valor] no lo es.
String? huellaSha256(Object? valor) {
  final texto = _texto(valor)?.toLowerCase();
  return texto != null && _huella.hasMatch(texto) ? texto : null;
}

/// Los documentos que el médico firma y que el paciente puede bajar en PDF:
/// la receta, la orden de exámenes y el certificado de reposo.
enum TipoDocumentoFirmado {
  receta('recetas', 'receta'),
  orden('ordenes', 'orden'),
  certificado('certificados', 'certificado');

  /// El segmento de la ruta: `/portal/recetas/:id/pdf`.
  final String ruta;

  /// El comienzo del nombre del archivo guardado.
  final String prefijo;

  const TipoDocumentoFirmado(this.ruta, this.prefijo);
}

/// Lo común a una receta, una orden y un certificado: quién lo emitió, para
/// quién, cuándo, con qué código se verifica y, si lo firmó el médico, su
/// firma electrónica.
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

  /// El número secuencial del documento en la clínica (uno por tipo:
  /// recetas, órdenes y certificados), o `null` si el servidor no lo manda.
  final int? numero;

  /// La modalidad de la atención en que se emitió: código del catálogo
  /// `MODALIDAD_CITA` (`PRESENCIAL`, `TELEMEDICINA`, `ASINCRONA`), o vacío
  /// si el documento es viejo y no lo trae.
  final String modalidad;

  /// Fecha de emisión, hora local de la clínica.
  final DateTime? fecha;

  final List<DiagnosticoClinico> diagnosticos;

  /// El código con que la farmacia o el laboratorio comprueban que es
  /// auténtico.
  final String codigoVerificacion;

  /// `EMITIDA` o `ANULADA`.
  final String estado;
  final String? anuladaMotivo;

  /// El médico lo firmó electrónicamente (`firmado` del portal, o
  /// `firma.estado == 'FIRMADO'`).
  final bool firmado;

  /// La firma, si el portal la manda.
  final FirmaElectronica? firma;

  /// El servidor tiene el PDF firmado y deja que el paciente lo descargue
  /// (`pdfDisponible`: firmado, emitido y entregable según la clínica).
  /// Sin firma, el servidor arma al vuelo la vista previa (el mismo diseño,
  /// con el recuadro «Documento sin firma electrónica»), así que «Ver PDF»
  /// no depende de esto: ver [puedeVerPdf].
  final bool pdfDisponible;

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
    this.numero,
    this.modalidad = '',
    this.fecha,
    this.diagnosticos = const [],
    this.codigoVerificacion = '',
    this.estado = 'EMITIDA',
    this.anuladaMotivo,
    this.firmado = false,
    this.firma,
    this.pdfDisponible = false,
  });

  bool get anulada =>
      const {'ANULADA', 'ANULADO'}.contains(estado.toUpperCase());

  /// Se ofrece «Ver PDF» mientras el documento sigue vigente: firmado, el
  /// servidor entrega el PDF guardado; sin firma, la vista previa. Si el
  /// servidor no lo da (la clínica lo entrega solo firmado), el visor
  /// enseña su mensaje. Uno anulado ya no se entrega, aunque quede una
  /// copia vieja.
  bool get puedeVerPdf => !anulada;

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
    numero,
    modalidad,
    fecha,
    diagnosticos,
    codigoVerificacion,
    estado,
    anuladaMotivo,
    firmado,
    firma,
    pdfDisponible,
  ];
}

/// El número secuencial de un documento: un entero positivo (también si
/// llega como texto), o `null`.
int? _numeroDeDocumento(Object? valor) {
  final numero = _numero(valor);
  if (numero == null || numero <= 0 || numero != numero.roundToDouble()) {
    return null;
  }

  return numero.toInt();
}

/// Los datos de la firma de un documento del portal: `firmado`,
/// `pdfDisponible` y `firma`.
({bool firmado, FirmaElectronica? firma, bool pdfDisponible}) _firmaDe(
  Map<dynamic, dynamic> json,
) {
  final crudo = json['firma'];
  final estado = crudo is Map ? _texto(crudo['estado'])?.toUpperCase() : null;
  final firmado = json['firmado'] == true || estado == 'FIRMADO';

  return (
    firmado: firmado,
    // Una reserva en curso (`EN_CURSO`) no es una firma: no se enseña.
    firma: firmado ? FirmaElectronica.desdeJson(crudo) : null,
    pdfDisponible: json['pdfDisponible'] == true,
  );
}

/// Lo común de una receta, una orden y un certificado, leído una sola vez:
/// quién, para quién, cuándo, el número, la modalidad, el código, el estado
/// y la firma.
class _Comun {
  final String id;
  final Map<dynamic, dynamic> json;
  final ({bool firmado, FirmaElectronica? firma, bool pdfDisponible}) firma;

  _Comun(this.id, this.json) : firma = _firmaDe(json);

  String get atencionId => _texto(json['atencionId']) ?? '';
  String get pacienteId => _texto(json['pacienteId']) ?? '';
  String get pacienteNombre => _texto(json['pacienteNombre']) ?? '';
  String? get pacienteCedula => _texto(json['pacienteCedula']);
  int? get pacienteEdad => _numero(json['pacienteEdad'])?.toInt();
  String get medicoNombre => _texto(json['medicoNombre']) ?? '';
  String? get medicoEspecialidad => _texto(json['medicoEspecialidad']);
  String? get medicoRegistro => _texto(json['medicoRegistro']);
  int? get numero => _numeroDeDocumento(json['numero']);
  String get modalidad => _texto(json['modalidad'])?.toUpperCase() ?? '';
  DateTime? get fecha => leerFechaLocal(json['fecha']);
  List<DiagnosticoClinico> get diagnosticos =>
      _diagnosticos(json['diagnosticos']);
  String get codigoVerificacion => _texto(json['codigoVerificacion']) ?? '';
  String get estado => _texto(json['estado'])?.toUpperCase() ?? 'EMITIDA';

  /// El certificado lo escribía en masculino (`anuladoMotivo`).
  String? get anuladaMotivo =>
      _texto(json['anuladaMotivo']) ?? _texto(json['anuladoMotivo']);

  /// Lee el identificador; lanza [FormatException] si no hay.
  static _Comun de(Map<dynamic, dynamic> json, String que) {
    final id = _texto(json['_id']);
    if (id == null) throw FormatException('$que sin identificador');

    return _Comun(id, json);
  }
}

/// Una receta (`GET /portal/recetas/:id` o dentro de Mi salud), con sus dos
/// partes: la prescripción para la farmacia (cada medicamento por su nombre
/// genérico, concentración, forma y cantidad en números y letras) y las
/// indicaciones para el paciente (cómo tomarlo, recomendaciones y signos de
/// alarma).
class Receta extends DocumentoClinico {
  final List<ItemReceta> items;
  final String? indicacionesNoFarmacologicas;

  /// Ante qué volver a consultar o ir a emergencias.
  final String? signosAlarma;

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
    super.numero,
    super.modalidad,
    super.fecha,
    super.diagnosticos,
    super.codigoVerificacion,
    super.estado,
    super.anuladaMotivo,
    super.firmado,
    super.firma,
    super.pdfDisponible,
    this.items = const [],
    this.indicacionesNoFarmacologicas,
    this.signosAlarma,
  });

  /// Lee una receta; lanza [FormatException] si no tiene identificador.
  factory Receta.desdeJson(Map<dynamic, dynamic> json) {
    final c = _Comun.de(json, 'Receta');

    return Receta(
      id: c.id,
      atencionId: c.atencionId,
      pacienteId: c.pacienteId,
      pacienteNombre: c.pacienteNombre,
      pacienteCedula: c.pacienteCedula,
      pacienteEdad: c.pacienteEdad,
      medicoNombre: c.medicoNombre,
      medicoEspecialidad: c.medicoEspecialidad,
      medicoRegistro: c.medicoRegistro,
      numero: c.numero,
      modalidad: c.modalidad,
      fecha: c.fecha,
      diagnosticos: c.diagnosticos,
      codigoVerificacion: c.codigoVerificacion,
      estado: c.estado,
      anuladaMotivo: c.anuladaMotivo,
      firmado: c.firma.firmado,
      firma: c.firma.firma,
      pdfDisponible: c.firma.pdfDisponible,
      items: [
        for (final item in _mapas(json['items'])) ?ItemReceta.desdeJson(item),
      ],
      indicacionesNoFarmacologicas: _texto(
        json['indicacionesNoFarmacologicas'],
      ),
      signosAlarma: _texto(json['signosAlarma']),
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    items,
    indicacionesNoFarmacologicas,
    signosAlarma,
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

  /// Por qué la pide el médico (la justificación clínica).
  final String? indicacionesClinicas;

  /// Cómo prepararse para los exámenes («Ayuno de 8 horas»).
  final String? preparacion;

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
    super.numero,
    super.modalidad,
    super.fecha,
    super.diagnosticos,
    super.codigoVerificacion,
    super.estado,
    super.anuladaMotivo,
    super.firmado,
    super.firma,
    super.pdfDisponible,
    this.tipo = TipoOrden.otro,
    this.items = const [],
    this.prioridad = 'RUTINA',
    this.indicacionesClinicas,
    this.preparacion,
    this.observaciones,
  });

  bool get urgente => prioridad.toUpperCase() == 'URGENTE';

  /// Lee una orden; lanza [FormatException] si no tiene identificador.
  factory Orden.desdeJson(Map<dynamic, dynamic> json) {
    final c = _Comun.de(json, 'Orden');

    return Orden(
      id: c.id,
      atencionId: c.atencionId,
      pacienteId: c.pacienteId,
      pacienteNombre: c.pacienteNombre,
      pacienteCedula: c.pacienteCedula,
      pacienteEdad: c.pacienteEdad,
      medicoNombre: c.medicoNombre,
      medicoEspecialidad: c.medicoEspecialidad,
      medicoRegistro: c.medicoRegistro,
      numero: c.numero,
      modalidad: c.modalidad,
      fecha: c.fecha,
      diagnosticos: c.diagnosticos,
      codigoVerificacion: c.codigoVerificacion,
      estado: c.estado,
      anuladaMotivo: c.anuladaMotivo,
      firmado: c.firma.firmado,
      firma: c.firma.firma,
      pdfDisponible: c.firma.pdfDisponible,
      tipo: TipoOrden.desdeCodigo(json['tipo']),
      items: [
        for (final item in _mapas(json['items'])) ?ItemOrden.desdeJson(item),
      ],
      prioridad: _texto(json['prioridad'])?.toUpperCase() ?? 'RUTINA',
      indicacionesClinicas: _texto(json['indicacionesClinicas']),
      preparacion: _texto(json['preparacion']),
      observaciones: _texto(json['observaciones']),
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    tipo,
    items,
    prioridad,
    indicacionesClinicas,
    preparacion,
    observaciones,
  ];
}

/// Un certificado médico de reposo (`GET /portal/certificados/:id` o dentro
/// de Mi salud): cuántos días, desde y hasta cuándo, de qué tipo y por qué
/// contingencia, con las recomendaciones del médico.
///
/// Los códigos (`tipoReposo`, `contingencia`, `destinatario`) son del
/// sistema, como el tipo de una orden; sus nombres están en
/// `dominio/reglas_mi_salud.dart`.
class CertificadoReposo extends DocumentoClinico {
  /// `ABSOLUTO` o `RELATIVO`.
  final String tipoReposo;

  /// `ENFERMEDAD_GENERAL`, `ACCIDENTE_TRABAJO`, `ENFERMEDAD_PROFESIONAL`,
  /// `MATERNIDAD` u `OTRA`.
  final String contingencia;

  final int dias;

  /// Los días en palabras, como los escribe el servidor («tres»).
  final String? diasEnLetras;

  /// El primer y el último día de reposo (días sueltos, sin hora).
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;

  /// Si el diagnóstico va en el certificado. `null` si no llegó: entonces
  /// se enseña el que mande el servidor, si manda alguno.
  final bool? mostrarDiagnostico;

  final String? recomendaciones;

  /// `EMPLEADOR`, `INSTITUCION_EDUCATIVA` u `OTRO`, o `null`.
  final String? destinatario;

  const CertificadoReposo({
    required super.id,
    super.atencionId,
    super.pacienteId,
    super.pacienteNombre,
    super.pacienteCedula,
    super.pacienteEdad,
    super.medicoNombre,
    super.medicoEspecialidad,
    super.medicoRegistro,
    super.numero,
    super.modalidad,
    super.fecha,
    super.diagnosticos,
    super.codigoVerificacion,
    super.estado,
    super.anuladaMotivo,
    super.firmado,
    super.firma,
    super.pdfDisponible,
    this.tipoReposo = '',
    this.contingencia = '',
    this.dias = 0,
    this.diasEnLetras,
    this.fechaDesde,
    this.fechaHasta,
    this.mostrarDiagnostico,
    this.recomendaciones,
    this.destinatario,
  });

  bool get absoluto => tipoReposo.toUpperCase() == 'ABSOLUTO';

  /// El diagnóstico se enseña solo si el servidor lo manda y el certificado
  /// no lo reserva: la pantalla dice lo mismo que el PDF.
  bool get diagnosticoVisible =>
      diagnosticos.isNotEmpty && mostrarDiagnostico != false;

  /// El certificado dice «Diagnóstico reservado».
  bool get diagnosticoReservado => mostrarDiagnostico == false;

  /// Lee un certificado; lanza [FormatException] si no tiene identificador.
  factory CertificadoReposo.desdeJson(Map<dynamic, dynamic> json) {
    final c = _Comun.de(json, 'Certificado');
    final dias = _numero(json['dias'])?.toInt() ?? 0;
    final desde = _dia(json['fechaDesde']);
    final mostrar = json['mostrarDiagnostico'];

    return CertificadoReposo(
      id: c.id,
      atencionId: c.atencionId,
      pacienteId: c.pacienteId,
      pacienteNombre: c.pacienteNombre,
      pacienteCedula: c.pacienteCedula,
      pacienteEdad: c.pacienteEdad,
      medicoNombre: c.medicoNombre,
      medicoEspecialidad: c.medicoEspecialidad,
      medicoRegistro: c.medicoRegistro,
      numero: c.numero,
      modalidad: c.modalidad,
      fecha: c.fecha,
      diagnosticos: c.diagnosticos,
      codigoVerificacion: c.codigoVerificacion,
      estado: c.estado,
      anuladaMotivo: c.anuladaMotivo,
      firmado: c.firma.firmado,
      firma: c.firma.firma,
      pdfDisponible: c.firma.pdfDisponible,
      tipoReposo: _texto(json['tipoReposo'])?.toUpperCase() ?? '',
      contingencia: _texto(json['contingencia'])?.toUpperCase() ?? '',
      dias: dias,
      diasEnLetras: _texto(json['diasEnLetras']),
      fechaDesde: desde,
      // Si no llega, se calcula como el servidor: hasta = desde + días − 1.
      fechaHasta:
          _dia(json['fechaHasta']) ??
          (desde != null && dias > 0 ? sumarDias(desde, dias - 1) : null),
      mostrarDiagnostico: mostrar is bool ? mostrar : null,
      recomendaciones: _texto(json['recomendaciones']),
      destinatario: _texto(json['destinatario'])?.toUpperCase(),
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    tipoReposo,
    contingencia,
    dias,
    diasEnLetras,
    fechaDesde,
    fechaHasta,
    mostrarDiagnostico,
    recomendaciones,
    destinatario,
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
///
/// También puede ser una atención todavía abierta ([enCurso]) en la que el
/// médico ya firmó una receta o un certificado: la clínica los entrega al
/// firmar, así que llegan sus documentos firmados y nada del contenido
/// clínico de la consulta.
class AtencionMiSalud extends Equatable {
  final String id;

  /// La consulta sigue abierta: solo trae lo que ya está firmado.
  final bool enCurso;

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
  final List<CertificadoReposo> certificados;

  /// Los adjuntos clínicos (fotos, exámenes).
  final List<ArchivoMeta> adjuntos;

  const AtencionMiSalud({
    required this.id,
    this.enCurso = false,
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
    this.certificados = const [],
    this.adjuntos = const [],
  });

  static AtencionMiSalud? desdeJson(Map<dynamic, dynamic> json) {
    final id = _texto(json['_id']);
    if (id == null) return null;

    return AtencionMiSalud(
      id: id,
      enCurso: json['enCurso'] == true,
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
      certificados: [
        for (final certificado in _mapas(json['certificados']))
          ?_intentar(() => CertificadoReposo.desdeJson(certificado)),
      ],
      adjuntos: interpretarArchivos(json['adjuntos']),
    );
  }

  @override
  List<Object?> get props => [
    id,
    enCurso,
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
    certificados,
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
