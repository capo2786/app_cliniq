// test/dobles/mi_salud.dart

/// Mi salud, una receta y una orden con la forma exacta de la API
/// (`GET /portal/mi-salud`, `/portal/recetas/:id`, `/portal/ordenes/:id`).
library;

Map<String, dynamic> recetaJson({
  String id = 'r1',
  String estado = 'EMITIDA',
  String medicamento = 'Amoxicilina',
  String? anuladaMotivo,
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
  List<Map<String, dynamic>> adjuntos = const [],
  String? proximoControl = '2026-10-10',
}) => {
  '_id': id,
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
