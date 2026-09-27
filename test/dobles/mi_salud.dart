// test/dobles/mi_salud.dart

/// Mi salud, una receta, una orden y un certificado de reposo con la forma
/// exacta de la API (`GET /portal/mi-salud`, `/portal/recetas/:id`,
/// `/portal/ordenes/:id`, `/portal/certificados/:id`), con la firma
/// electrónica del contrato de firma.
library;

/// La huella (sha256) de un PDF de prueba.
const String huellaDePrueba =
    'a3f1c2d4e5b60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

/// El subdocumento `firma` de un documento firmado, como lo guarda
/// agenda-ms (sin la clave ni el `.p12`, que nunca salen del equipo del
/// médico).
Map<String, dynamic> firmaJson({String? sha256 = huellaDePrueba}) => {
  'estado': 'FIRMADO',
  'formato': 'PKCS7-DETACHED-SHA256',
  'archivoId': 'arch-1',
  'sha256Firmado': ?sha256,
  'firmadoEn': '2026-09-26T15:15:00.000Z',
  'certificado': {
    'nombre': 'LUIS ALBERTO MORA SALAZAR',
    'cedula': '1712345678',
    'emisor': 'Security Data',
    'serie': '5A:3F',
    'huellaSha256': 'bb' * 32,
    'validoDesde': '2025-01-01T00:00:00.000Z',
    'validoHasta': '2027-01-01T00:00:00.000Z',
  },
  'revocacion': {'metodo': 'CRL', 'resultado': 'VALIDO'},
};

Map<String, dynamic> recetaJson({
  String id = 'r1',
  String estado = 'EMITIDA',
  String medicamento = 'Amoxicilina',
  String? anuladaMotivo,
  bool firmada = false,
  bool pdfDisponible = false,
}) => {
  '_id': id,
  'atencionId': 'at1',
  'pacienteId': 'u1',
  'pacienteNombre': 'Ana María Pérez',
  'pacienteCedula': '0914358825',
  'pacienteEdad': 34,
  'medicoId': 'doc1',
  'medicoNombre': 'Luis Mora',
  'medicoEspecialidad': 'Medicina Familiar',
  'medicoRegistro': '1005-2019-2081234',
  'fecha': '2026-09-25T23:21:20.000Z',
  'diagnosticos': [
    {
      'sistema': 'CIE10',
      'codigo': 'J03.9',
      'descripcion': 'Amigdalitis aguda, no especificada',
      'tipo': 'DEFINITIVO',
      'principal': true,
    },
  ],
  'items': [
    {
      'medicamento': medicamento,
      'concentracion': '500 mg',
      'formaFarmaceutica': 'Cápsula',
      'via': 'Oral',
      'dosis': '1 cápsula',
      'frecuencia': 'Cada 8 horas',
      'duracion': '10 días',
      'cantidad': '30',
      'indicaciones': 'Después de las comidas',
    },
  ],
  'codigoVerificacion': 'UC7F6DB5UU',
  'estado': estado,
  'anuladaMotivo': ?anuladaMotivo,
  'indicacionesNoFarmacologicas': 'Tomar abundante agua.',
  'createdAt': '2026-09-26T04:21:20.762Z',
  'firmado': firmada,
  'pdfDisponible': pdfDisponible,
  'firma': firmada ? firmaJson() : {'estado': 'SIN_FIRMA'},
};

Map<String, dynamic> certificadoJson({
  String id = 'c1',
  String estado = 'EMITIDA',
  int dias = 3,
  String? fechaHasta = '2026-09-28',
  String tipoReposo = 'ABSOLUTO',
  bool? mostrarDiagnostico = false,
  bool conDiagnostico = true,
  bool firmado = true,
  bool pdfDisponible = true,
  String? anuladoMotivo,
}) => {
  '_id': id,
  'atencionId': 'at1',
  'pacienteId': 'u1',
  'pacienteNombre': 'Ana María Pérez',
  'pacienteCedula': '0914358825',
  'pacienteEdad': 34,
  'medicoId': 'doc1',
  'medicoNombre': 'Luis Mora',
  'medicoEspecialidad': 'Medicina Familiar',
  'medicoRegistro': '1005-2019-2081234',
  'fecha': '2026-09-25T23:25:00.000Z',
  'diagnosticos': conDiagnostico
      ? [
          {
            'sistema': 'CIE10',
            'codigo': 'J03.9',
            'descripcion': 'Amigdalitis aguda, no especificada',
            'tipo': 'DEFINITIVO',
            'principal': true,
          },
        ]
      : <Object?>[],
  'items': <Object?>[],
  'codigoVerificacion': 'CR7Q2MXK9P',
  'estado': estado,
  'anuladaMotivo': ?anuladoMotivo,
  'tipo': 'REPOSO',
  'modalidad': 'TELEMEDICINA',
  'contingencia': 'ENFERMEDAD_GENERAL',
  'tipoReposo': tipoReposo,
  'dias': dias,
  'diasEnLetras': dias == 3 ? 'tres' : 'uno',
  'fechaDesde': '2026-09-26',
  'fechaHasta': ?fechaHasta,
  'mostrarDiagnostico': ?mostrarDiagnostico,
  'recomendaciones': 'Hidratación abundante y evitar el frío.',
  'destinatario': 'EMPLEADOR',
  'firmado': firmado,
  'pdfDisponible': pdfDisponible,
  'firma': firmado ? firmaJson() : {'estado': 'SIN_FIRMA'},
};

Map<String, dynamic> ordenJson({
  String id = 'o1',
  String tipo = 'LABORATORIO',
  String prioridad = 'RUTINA',
}) => {
  '_id': id,
  'atencionId': 'at1',
  'pacienteId': 'u1',
  'pacienteNombre': 'Ana María Pérez',
  'pacienteCedula': '0914358825',
  'pacienteEdad': 34,
  'medicoId': 'doc1',
  'medicoNombre': 'Luis Mora',
  'medicoEspecialidad': 'Medicina Familiar',
  'medicoRegistro': '1005-2019-2081234',
  'fecha': '2026-09-25T23:19:24.000Z',
  'diagnosticos': <Object?>[],
  'items': [
    {'nombre': 'Biometría hemática'},
    {
      'nombre': 'Proteína C reactiva (PCR)',
      'codigo': 'PCR',
      'indicaciones': 'En ayunas',
    },
  ],
  'codigoVerificacion': 'G2KKBTJTBK',
  'estado': 'EMITIDA',
  'tipo': tipo,
  'prioridad': prioridad,
  'observaciones': 'Traer resultados al control.',
};

Map<String, dynamic> atencionJson({
  String id = 'at1',
  String tipo = 'TELEMEDICINA',
  String inicio = '2026-09-25T23:18:52.000Z',
  List<Map<String, dynamic>>? recetas,
  List<Map<String, dynamic>>? ordenes,
  List<Map<String, dynamic>> certificados = const [],
  List<Map<String, dynamic>> adjuntos = const [],
  String? proximoControl = '2026-10-10',
}) => {
  '_id': id,
  'enCurso': false,
  'inicio': inicio,
  'medicoNombre': 'Luis Mora',
  'especialidad': 'Medicina Familiar',
  'tipo': tipo,
  'motivoConsulta': 'Dolor de garganta y fiebre',
  'diagnosticos': [
    {
      'sistema': 'CIE10',
      'codigo': 'J03.9',
      'descripcion': 'Amigdalitis aguda, no especificada',
      'tipo': 'DEFINITIVO',
      'principal': true,
    },
    {
      'sistema': 'CIE10',
      'codigo': 'R50.9',
      'descripcion': 'Fiebre, no especificada',
      'tipo': 'PRESUNTIVO',
      'principal': false,
    },
  ],
  'plan': 'Amoxicilina por 10 días.',
  'indicacionesNoFarmacologicas': 'Reposo relativo.',
  'proximoControl': proximoControl,
  'recetas': recetas ?? [recetaJson()],
  'ordenes': ordenes ?? [ordenJson()],
  'certificados': certificados,
  'adjuntos': adjuntos,
};

Map<String, dynamic> miSaludJson({
  String uid = 'u1',
  String nombre = 'Ana María Pérez',
  Map<String, dynamic>? embarazo,
  List<Map<String, dynamic>>? atenciones,
  bool conSignos = true,
}) => {
  'paciente': {
    'uid': uid,
    'nombre': nombre,
    'edad': 34,
    'sexo': 'F',
    'tipoSangre': 'O+',
    'fechaNacimiento': '1992-04-18',
    'alergias': 'Penicilina',
    'antecedentesPersonales': 'Asma en la infancia',
    'medicacionHabitual': 'Ninguna',
    'embarazo': embarazo ?? {'actual': false},
  },
  if (conSignos)
    'ultimosSignos': {
      'fecha': '2026-09-25T23:18:52.000Z',
      'presionSistolica': 150,
      'presionDiastolica': 95,
      'temperatura': 38.4,
      'pesoKg': 70,
      'tallaCm': 165,
      'imc': 25.7,
    },
  'atenciones': atenciones ?? [atencionJson()],
};

/// Una atención todavía abierta con un documento ya firmado: sin contenido
/// clínico, solo lo firmado (así la manda agenda-ms si la clínica entrega
/// los documentos al firmar).
Map<String, dynamic> atencionEnCursoJson({
  String id = 'at2',
  List<Map<String, dynamic>> recetas = const [],
  List<Map<String, dynamic>> certificados = const [],
}) => {
  '_id': id,
  'enCurso': true,
  'inicio': '2026-09-27T15:00:00.000Z',
  'medicoNombre': 'Luis Mora',
  'especialidad': 'Medicina Familiar',
  'tipo': 'PRESENCIAL',
  'recetas': recetas,
  'ordenes': <Object?>[],
  'certificados': certificados,
  'adjuntos': <Object?>[],
};
