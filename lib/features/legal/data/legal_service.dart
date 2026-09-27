import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

import '../../../core/config/entorno.dart';
import '../../../core/network/api_interceptor.dart';
import '../../../core/storage/cache_local.dart';

/*
 * Los documentos legales viven en la base de datos de la clínica: su clave,
 * su nombre corto (`slug`, el de la dirección pública), su versión y su
 * título salen de la API. La aplicación no guarda ninguno escrito: abre
 * `https://<web>/legal/<slug>` con el slug que llega.
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

  /// Dónde se lee, en el panel web.
  String get url => Entorno.urlLegal(slug);

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

  /// El nombre corto de su dirección, o `null` si la API no lo mandó.
  final String? slug;

  const DocumentoPendiente({
    required this.clave,
    required this.version,
    required this.titulo,
    this.slug,
  });

  /// Dónde se lee el texto completo, en el panel web; `null` sin slug.
  String? get url => slug == null ? null : Entorno.urlLegal(slug!);

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

  String? get url => slug == null ? null : Entorno.urlLegal(slug!);

  @override
  List<Object?> get props => [clave, version, aceptadoEn, titulo, slug];
}

class MisAceptaciones {
  final List<AceptacionLegal> aceptaciones;
  final List<DocumentoPendiente> pendientes;

  const MisAceptaciones({required this.aceptaciones, required this.pendientes});
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
