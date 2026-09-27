import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../core/fechas/instante.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/network/errores.dart';
import '../../../core/storage/cache_local.dart';

/*
 * Los documentos legales viven en la base de datos de la clínica: su clave,
 * su nombre corto (`slug`), su versión, su título y su texto salen de la API.
 * La aplicación no guarda ninguno escrito: pide el texto con el slug que
 * llega (`GET /legal/documentos/:slug`) y lo pinta ella misma, con una copia
 * para leerlo sin red.
 */

/// Un documento legal vigente (`GET /legal/documentos`).
class DocumentoLegal extends Equatable {
  final String clave;
  final String slug;
  final String version;
  final String titulo;
  final String resumen;

  /// A qué tipos de usuario aplica, como los manda la API.
  final List<String> tipos;

  const DocumentoLegal({
    required this.clave,
    required this.slug,
    required this.version,
    required this.titulo,
    this.resumen = '',
    this.tipos = const [],
  });

  /// Si le toca a esta persona: por su tipo de usuario (`3`) o por el
  /// nombre de uno de sus roles (`PACIENTE`), que es como el contrato dice
  /// que la API puede mandarlo. Sin tipos, a todos.
  bool aplicaA({required int tipoDeUsuario, List<String> roles = const []}) {
    if (tipos.isEmpty) return true;

    final buscados = {'$tipoDeUsuario', for (final r in roles) r.toUpperCase()};
    return tipos.any((t) => buscados.contains(t.toUpperCase()));
  }

  static DocumentoLegal? desdeJson(Object? json) {
    if (json is! Map) return null;

    String texto(String campo) => json[campo]?.toString().trim() ?? '';

    final clave = texto('clave');
    final slug = texto('slug');
    if (clave.isEmpty || slug.isEmpty) return null;

    final titulo = texto('titulo');

    return DocumentoLegal(
      clave: clave,
      slug: slug,
      version: texto('version'),
      titulo: titulo.isEmpty ? clave : titulo,
      resumen: texto('resumen'),
      tipos: [
        for (final t in (json['tipos'] as List?) ?? const []) t.toString(),
      ],
    );
  }

  Map<String, dynamic> aJson() => {
    'clave': clave,
    'slug': slug,
    'version': version,
    'titulo': titulo,
    'resumen': resumen,
    'tipos': tipos,
  };

  @override
  List<Object?> get props => [clave, slug, version, titulo, resumen, tipos];
}

/// Un documento legal por aceptar.
class DocumentoPendiente extends Equatable {
  final String clave;
  final String version;
  final String titulo;

  /// El nombre corto con que se pide su texto, o `null` si la API no lo
  /// mandó (entonces no hay «Leer»).
  final String? slug;

  const DocumentoPendiente({
    required this.clave,
    required this.version,
    required this.titulo,
    this.slug,
  });

  @override
  List<Object?> get props => [clave, version, titulo, slug];
}

/// Un documento ya aceptado.
class AceptacionLegal extends Equatable {
  final String clave;
  final String version;
  final DateTime? aceptadoEn;

  /// Título y nombre corto de la API (`mis-aceptaciones` los trae; si no,
  /// los de la lista de documentos). Sin ninguno de los dos, el título es
  /// la clave y no hay enlace: nada inventado.
  final String titulo;
  final String? slug;

  const AceptacionLegal({
    required this.clave,
    required this.version,
    required this.titulo,
    this.slug,
    this.aceptadoEn,
  });

  @override
  List<Object?> get props => [clave, version, aceptadoEn, titulo, slug];
}

class MisAceptaciones {
  final List<AceptacionLegal> aceptaciones;
  final List<DocumentoPendiente> pendientes;

  const MisAceptaciones({required this.aceptaciones, required this.pendientes});
}

/// El texto completo de un documento legal vigente
/// (`GET /legal/documentos/:slug`): Markdown con los datos de la clínica ya
/// sustituidos por el servidor.
class TextoLegal extends Equatable {
  final String clave;
  final String slug;
  final String version;
  final String titulo;
  final String resumen;

  /// Desde cuándo rige (un instante real: la medianoche en la zona de la
  /// clínica).
  final DateTime? vigenteDesde;

  final String contenido;

  /// Salió de la copia del teléfono porque el servidor no respondió.
  final bool desdeCache;

  const TextoLegal({
    required this.clave,
    required this.slug,
    required this.version,
    required this.titulo,
    required this.contenido,
    this.resumen = '',
    this.vigenteDesde,
    this.desdeCache = false,
  });

  static TextoLegal? desdeJson(Object? json, {bool desdeCache = false}) {
    if (json is! Map) return null;

    String texto(String campo) => json[campo]?.toString().trim() ?? '';

    final slug = texto('slug');
    final contenido = json['contenido'];
    if (slug.isEmpty || contenido is! String) return null;

    final clave = texto('clave');
    final titulo = texto('titulo');

    return TextoLegal(
      clave: clave,
      slug: slug,
      version: texto('version'),
      titulo: titulo.isEmpty ? (clave.isEmpty ? slug : clave) : titulo,
      resumen: texto('resumen'),
      vigenteDesde: leerInstante(json['vigenteDesde']),
      contenido: contenido,
      desdeCache: desdeCache,
    );
  }

  Map<String, dynamic> aJson() => {
    'clave': clave,
    'slug': slug,
    'version': version,
    'titulo': titulo,
    'resumen': resumen,
    'vigenteDesde': aTextoInstante(vigenteDesde),
    'contenido': contenido,
  };

  @override
  List<Object?> get props => [
    clave,
    slug,
    version,
    titulo,
    resumen,
    vigenteDesde,
    contenido,
    desdeCache,
  ];
}

/// El documento no existe o ya no está vigente (404).
class DocumentoLegalNoEncontrado implements Exception {
  final String slug;

  const DocumentoLegalNoEncontrado(this.slug);

  @override
  String toString() => 'DocumentoLegalNoEncontrado($slug)';
}

/// `/legal`: los documentos vigentes, qué aceptó la persona y qué le falta.
class LegalService {
  static const String rutaDocumentos = '/legal/documentos';

  /// Con el prefijo `legal`, que es de la clínica: sobrevive al cierre de
  /// sesión.
  static const String claveCache = 'legal:documentos';

  final Dio _dio;
  final CacheLocal? _cache;

  LegalService(this._dio, [this._cache]);

  /// `GET /legal/documentos` (pública): los documentos vigentes. Sin red, la
  /// última copia; sin copia, el error.
  Future<List<DocumentoLegal>> documentos() async {
    try {
      final respuesta = await _dio.get<dynamic>(
        rutaDocumentos,
        options: Options(extra: const {rutaPublica: true}),
      );

      final datos = respuesta.data;
      if (datos is! List) {
        throw const FormatException('La lista de documentos no es una lista');
      }

      final documentos = interpretarDocumentos(datos);
      await _cache?.guardar(claveCache, [
        for (final d in documentos) d.aJson(),
      ]);

      return documentos;
    } catch (_) {
      final copia = await _cache?.leer(claveCache);
      if (copia is List) return interpretarDocumentos(copia);

      rethrow;
    }
  }

  /// La clave de la copia del texto de un documento. Con el prefijo `legal`:
  /// es de la clínica y sobrevive al cierre de sesión.
  static String claveTexto(String slug) => 'legal:texto:$slug';

  /// `GET /legal/documentos/:slug` (pública): el texto vigente de un
  /// documento. Sin red, la última copia; sin copia, el error. Un 404 no usa
  /// la copia: el documento ya no está vigente, y leer una versión vieja
  /// como si fuera la actual sería peor que no leer nada
  /// ([DocumentoLegalNoEncontrado]).
  Future<TextoLegal> texto(String slug) async {
    try {
      final respuesta = await _dio.get<dynamic>(
        '$rutaDocumentos/${Uri.encodeComponent(slug)}',
        options: Options(extra: const {rutaPublica: true}),
      );

      final documento = TextoLegal.desdeJson(respuesta.data);
      if (documento == null) {
        throw const FormatException('El documento legal no trae su texto');
      }

      await _cache?.guardar(claveTexto(slug), documento.aJson());

      return documento;
    } catch (error) {
      if (estadoDe(error) == 404) throw DocumentoLegalNoEncontrado(slug);

      final copia = TextoLegal.desdeJson(
        await _cache?.leer(claveTexto(slug)),
        desdeCache: true,
      );
      if (copia != null) return copia;

      rethrow;
    }
  }

  /// `GET /legal/mis-aceptaciones`. Los títulos y nombres cortos que la
  /// respuesta no traiga se completan con [documentos].
  Future<MisAceptaciones> misAceptaciones({
    List<DocumentoLegal> documentos = const [],
  }) async {
    final respuesta = await _dio.get<dynamic>('/legal/mis-aceptaciones');

    return interpretarAceptaciones(respuesta.data, documentos: documentos);
  }

  /// `POST /legal/aceptar`: acepta estos documentos en su versión vigente.
  Future<MisAceptaciones> aceptar(
    List<DocumentoPendiente> pendientes, {
    List<DocumentoLegal> documentos = const [],
  }) async {
    final respuesta = await _dio.post<dynamic>(
      '/legal/aceptar',
      data: {
        'documentos': [
          for (final d in pendientes) {'clave': d.clave, 'version': d.version},
        ],
      },
    );

    return interpretarAceptaciones(respuesta.data, documentos: documentos);
  }
}

List<DocumentoLegal> interpretarDocumentos(List<dynamic> datos) => [
  for (final d in datos) ?DocumentoLegal.desdeJson(d),
];

MisAceptaciones interpretarAceptaciones(
  Object? datos, {
  List<DocumentoLegal> documentos = const [],
}) {
  if (datos is! Map) {
    return const MisAceptaciones(aceptaciones: [], pendientes: []);
  }

  final porClave = {for (final d in documentos) d.clave: d};

  String? texto(Object? valor) {
    final t = valor?.toString().trim();
    return t == null || t.isEmpty ? null : t;
  }

  return MisAceptaciones(
    aceptaciones: [
      for (final a in (datos['aceptaciones'] as List?) ?? const [])
        if (a is Map && a['clave'] != null)
          AceptacionLegal(
            clave: a['clave'].toString(),
            version: a['version']?.toString() ?? '',
            titulo:
                texto(a['titulo']) ??
                porClave[a['clave'].toString()]?.titulo ??
                a['clave'].toString(),
            slug: texto(a['slug']) ?? porClave[a['clave'].toString()]?.slug,
            // `aceptadoEn` es un instante real, no una hora congelada.
            aceptadoEn: DateTime.tryParse(a['aceptadoEn']?.toString() ?? '')
                ?.toLocal(),
          ),
    ],
    pendientes: [
      for (final p in (datos['pendientes'] as List?) ?? const [])
        if (p is Map && p['clave'] != null)
          DocumentoPendiente(
            clave: p['clave'].toString(),
            version: p['version']?.toString() ?? '',
            titulo:
                texto(p['titulo']) ??
                porClave[p['clave'].toString()]?.titulo ??
                p['clave'].toString(),
            slug: texto(p['slug']) ?? porClave[p['clave'].toString()]?.slug,
          ),
    ],
  );
}
