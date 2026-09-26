import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../core/config/entorno.dart';

/// Un documento legal por aceptar.
class DocumentoPendiente extends Equatable {
  final String clave;
  final String version;
  final String titulo;

  const DocumentoPendiente({
    required this.clave,
    required this.version,
    required this.titulo,
  });

  /// Dónde se lee el texto completo, en el panel web.
  String get url => Entorno.urlLegal(slugDe(clave));

  @override
  List<Object?> get props => [clave, version, titulo];
}

/// Un documento ya aceptado.
class AceptacionLegal extends Equatable {
  final String clave;
  final String version;
  final DateTime? aceptadoEn;

  const AceptacionLegal({
    required this.clave,
    required this.version,
    this.aceptadoEn,
  });

  String get titulo => tituloDe(clave);

  String get url => Entorno.urlLegal(slugDe(clave));

  @override
  List<Object?> get props => [clave, version, aceptadoEn];
}

class MisAceptaciones {
  final List<AceptacionLegal> aceptaciones;
  final List<DocumentoPendiente> pendientes;

  const MisAceptaciones({required this.aceptaciones, required this.pendientes});
}

/// El nombre corto de cada documento en la dirección del panel web.
const Map<String, String> slugsLegales = {
  'TERMINOS': 'terminos',
  'PRIVACIDAD': 'privacidad',
  'AVISO_LEGAL': 'aviso-legal',
  'USO_ACEPTABLE': 'uso-aceptable',
  'CONSENTIMIENTO_TELEMEDICINA': 'consentimiento-telemedicina',
  'CONTRATO_MEDICO': 'contrato-medico',
};

/// Los títulos, por si una aceptación llega sin él (la API no lo manda en
/// `aceptaciones`, solo en `pendientes`).
const Map<String, String> titulosLegales = {
  'TERMINOS': 'Términos y condiciones de uso',
  'PRIVACIDAD': 'Política de privacidad y protección de datos',
  'AVISO_LEGAL': 'Aviso legal',
  'USO_ACEPTABLE': 'Política de uso aceptable para pacientes',
  'CONSENTIMIENTO_TELEMEDICINA': 'Consentimiento informado para telemedicina',
  'CONTRATO_MEDICO': 'Condiciones para profesionales de la salud',
};

/// Un documento que esta versión no conoce se abre por su clave en
/// minúsculas y con guiones: es la regla con la que se nombraron los demás.
String slugDe(String clave) =>
    slugsLegales[clave] ?? clave.toLowerCase().replaceAll('_', '-');

String tituloDe(String clave) => titulosLegales[clave] ?? clave;

/// `/legal`: qué aceptó la persona y qué le falta.
class LegalService {
  final Dio _dio;

  LegalService(this._dio);

  /// `GET /legal/mis-aceptaciones`.
  Future<MisAceptaciones> misAceptaciones() async {
    final respuesta = await _dio.get<dynamic>('/legal/mis-aceptaciones');

    return interpretarAceptaciones(respuesta.data);
  }

  /// `POST /legal/aceptar`: acepta estos documentos en su versión vigente.
  Future<MisAceptaciones> aceptar(List<DocumentoPendiente> documentos) async {
    final respuesta = await _dio.post<dynamic>(
      '/legal/aceptar',
      data: {
        'documentos': [
          for (final d in documentos) {'clave': d.clave, 'version': d.version},
        ],
      },
    );

    return interpretarAceptaciones(respuesta.data);
  }
}

MisAceptaciones interpretarAceptaciones(Object? datos) {
  if (datos is! Map) {
    return const MisAceptaciones(aceptaciones: [], pendientes: []);
  }

  return MisAceptaciones(
    aceptaciones: [
      for (final a in (datos['aceptaciones'] as List?) ?? const [])
        if (a is Map && a['clave'] != null)
          AceptacionLegal(
            clave: a['clave'].toString(),
            version: a['version']?.toString() ?? '',
            // `aceptadoEn` es un instante real, no una hora congelada.
            aceptadoEn: DateTime.tryParse(
              a['aceptadoEn']?.toString() ?? '',
            )?.toLocal(),
          ),
    ],
    pendientes: [
      for (final p in (datos['pendientes'] as List?) ?? const [])
        if (p is Map && p['clave'] != null)
          DocumentoPendiente(
            clave: p['clave'].toString(),
            version: p['version']?.toString() ?? '',
            titulo: p['titulo']?.toString() ?? tituloDe(p['clave'].toString()),
          ),
    ],
  );
}
