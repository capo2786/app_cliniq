// lib/features/fotos_perfil/data/fotos_perfil_service.dart

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../dominio/foto_perfil.dart';

/// Las fotos de perfil: `GET/PUT/DELETE /auth/:id/foto` y `/auth/me/foto`.
///
/// Una `<img>` o un `Image.network` sin más no llevarían el token, así que
/// la foto se pide con el Dio de la aplicación (el que pone el token) y se
/// pinta desde los bytes.
///
/// **Caché.** Cada foto se guarda por usuario y versión (`fotoVersion`, que
/// sube con cada cambio): una versión nunca cambia de contenido, así que la
/// copia sirve para siempre y no se vuelve a pedir. Vive en memoria —las
/// últimas [maximoEnMemoria]— y en la carpeta de caché del teléfono, de
/// donde el sistema la puede borrar cuando falte espacio. Al guardar una
/// versión nueva se borran las anteriores del mismo usuario, y al cerrar
/// sesión se borran todas ([borrarTodo]): en un teléfono compartido, la
/// siguiente persona no tiene por qué ver las fotos de los dependientes de
/// la anterior.
///
/// Sin versión no se pide nada: sin `fotoVersion` la persona no tiene foto
/// y el avatar muestra sus iniciales. La excepción es el médico de una cita
/// o de una consulta, que no traen su versión: esa se pide sin `v`
/// ([obtenerVigente]), solo se guarda en memoria y se vuelve a pedir pasados
/// [vigenciaSinVersion], lo mismo que su `Cache-Control: max-age=300`.
class FotosPerfilService {
  final Dio _dio;
  final Future<Directory> Function() _carpetaBase;
  final DateTime Function() _ahora;
  final int maximoEnMemoria;

  /// Cuánto vale una foto pedida sin versión.
  static const Duration vigenciaSinVersion = Duration(minutes: 5);

  /// Las fotos pedidas sin versión: los bytes (o `null`, «no tiene») y
  /// cuándo se pidieron.
  final Map<String, ({Uint8List? bytes, DateTime cuando})> _vigentes = {};

  /// En memoria, del uso más viejo al más reciente. `null` es «la API dijo
  /// que no hay foto» (404), para no volver a preguntar en cada pantalla.
  final Map<String, Uint8List?> _memoria = {};

  /// Las peticiones en curso: diez tarjetas del mismo médico piden una vez.
  final Map<String, Future<Uint8List?>> _enCurso = {};

  FotosPerfilService(
    this._dio, {
    Future<Directory> Function()? carpetaBase,
    DateTime Function()? ahora,
    this.maximoEnMemoria = 80,
  }) : _carpetaBase = carpetaBase ?? getApplicationCacheDirectory,
       _ahora = ahora ?? DateTime.now;

  static String _clave(String uid, int version) => '$uid@$version';

  /// El uid como nombre de archivo: solo letras, números, guion y guion bajo.
  static String _seguro(String uid) =>
      uid.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  Future<Directory> _carpeta() async =>
      Directory('${(await _carpetaBase()).path}/fotos_perfil');

  Future<File> _archivo(String uid, int version) async =>
      File('${(await _carpeta()).path}/${_seguro(uid)}_v$version.jpg');

  void _recordarEnMemoria(String clave, Uint8List? bytes) {
    _memoria
      ..remove(clave)
      ..[clave] = bytes;

    while (_memoria.length > maximoEnMemoria) {
      _memoria.remove(_memoria.keys.first);
    }
  }

  /// La foto ya cargada, sin esperar: para pintarla en el primer cuadro y no
  /// ver un parpadeo de iniciales al volver a una pantalla.
  Uint8List? enMemoria(String uid, int? version) =>
      version == null ? null : _memoria[_clave(uid, version)];

  /// La foto de [uid] en su [version]: de la memoria, del disco o de la API.
  ///
  /// `null` si no tiene, si no se puede ver (la API responde 404 también
  /// cuando no hay permiso) o si falló la red; en esos casos el avatar se
  /// queda con las iniciales. Nunca lanza.
  Future<Uint8List?> obtener(String uid, int? version) {
    if (uid.isEmpty || version == null) return Future.value(null);

    final clave = _clave(uid, version);

    if (_memoria.containsKey(clave)) {
      final bytes = _memoria[clave];
      _recordarEnMemoria(clave, bytes);
      return Future.value(bytes);
    }

    // Con llaves a propósito: si la acción devolviera el futuro quitado del
    // mapa, `whenComplete` se esperaría a sí mismo.
    return _enCurso[clave] ??= _buscar(uid, version).whenComplete(() {
      _enCurso.remove(clave);
    });
  }

  Future<Uint8List?> _buscar(String uid, int version) async {
    final clave = _clave(uid, version);

    final guardada = await _leerDelDisco(uid, version);
    if (guardada != null) {
      _recordarEnMemoria(clave, guardada);
      return guardada;
    }

    try {
      final respuesta = await _dio.get<List<int>>(
        '/auth/$uid/foto',
        queryParameters: {'v': version},
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Accept': 'image/*'},
        ),
      );

      final datos = respuesta.data;
      if (datos == null || datos.isEmpty) return null;

      final bytes = datos is Uint8List ? datos : Uint8List.fromList(datos);
      _recordarEnMemoria(clave, bytes);
      await _guardarEnDisco(uid, version, bytes);

      return bytes;
    } on DioException catch (error) {
      // Sin foto o sin permiso para verla: se recuerda. Un fallo de red, no:
      // la próxima pantalla lo vuelve a intentar.
      if (error.response?.statusCode == 404) _recordarEnMemoria(clave, null);
      return null;
    } catch (error) {
      debugPrint('Cliniq · no se pudo traer una foto de perfil: $error');
      return null;
    }
  }

  // ── Sin versión (el médico de una cita o de una consulta) ────────────

  ({Uint8List? bytes, DateTime cuando})? _vigente(String uid) {
    final guardada = _vigentes[uid];
    if (guardada == null) return null;

    if (_ahora().difference(guardada.cuando) >= vigenciaSinVersion) {
      _vigentes.remove(uid);
      return null;
    }

    return guardada;
  }

  /// La foto vigente ya cargada, sin esperar.
  Uint8List? vigenteEnMemoria(String uid) => _vigente(uid)?.bytes;

  /// La foto de [uid] sin saber su versión: `GET /auth/:id/foto` sin `v`.
  ///
  /// Solo en memoria. Un 404 es «sin foto» y se recuerda igual que una
  /// foto; un fallo de red no. Nunca lanza.
  Future<Uint8List?> obtenerVigente(String uid) {
    if (uid.isEmpty) return Future.value(null);

    final guardada = _vigente(uid);
    if (guardada != null) return Future.value(guardada.bytes);

    final clave = '$uid@vigente';
    return _enCurso[clave] ??= _buscarVigente(uid).whenComplete(() {
      _enCurso.remove(clave);
    });
  }

  Future<Uint8List?> _buscarVigente(String uid) async {
    try {
      final respuesta = await _dio.get<List<int>>(
        '/auth/$uid/foto',
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {'Accept': 'image/*'},
        ),
      );

      final datos = respuesta.data;
      final bytes = datos == null || datos.isEmpty
          ? null
          : (datos is Uint8List ? datos : Uint8List.fromList(datos));
      _vigentes[uid] = (bytes: bytes, cuando: _ahora());

      return bytes;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        _vigentes[uid] = (bytes: null, cuando: _ahora());
      }
      return null;
    } catch (error) {
      debugPrint('Cliniq · no se pudo traer una foto de perfil: $error');
      return null;
    }
  }

  Future<Uint8List?> _leerDelDisco(String uid, int version) async {
    try {
      final archivo = await _archivo(uid, version);
      if (!await archivo.exists()) return null;

      final bytes = await archivo.readAsBytes();
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _guardarEnDisco(String uid, int version, Uint8List bytes) async {
    try {
      final carpeta = await _carpeta();
      await carpeta.create(recursive: true);
      await _borrarDelDisco(uid, excepto: version);

      final definitivo = await _archivo(uid, version);
      final temporal = File('${definitivo.path}.part');
      await temporal.writeAsBytes(bytes, flush: true);
      await temporal.rename(definitivo.path);
    } catch (error) {
      // Sin disco la foto sigue en memoria: solo se volverá a pedir mañana.
      debugPrint('Cliniq · no se pudo guardar una foto de perfil: $error');
    }
  }

  Future<void> _borrarDelDisco(String uid, {int? excepto}) async {
    try {
      final carpeta = await _carpeta();
      if (!await carpeta.exists()) return;

      final prefijo = '${_seguro(uid)}_v';
      final conservar = excepto == null ? null : '$prefijo$excepto.jpg';

      await for (final entrada in carpeta.list()) {
        final nombre = entrada.uri.pathSegments.last;
        if (nombre.startsWith(prefijo) && nombre != conservar) {
          await entrada.delete();
        }
      }
    } catch (_) {
      // Lo que no se borra ahora lo borra el sistema o el próximo cambio.
    }
  }

  /// Guarda en la caché una foto recién subida, para verla sin pedirla.
  Future<void> recordar(String uid, int version, Uint8List bytes) async {
    _olvidarDeMemoria(uid);
    _recordarEnMemoria(_clave(uid, version), bytes);
    await _guardarEnDisco(uid, version, bytes);
  }

  void _olvidarDeMemoria(String uid) {
    _memoria.removeWhere((clave, _) => clave.startsWith('$uid@'));
    _vigentes.remove(uid);
  }

  /// Borra todas las copias de [uid]: tras quitar su foto.
  Future<void> olvidar(String uid) async {
    _olvidarDeMemoria(uid);
    await _borrarDelDisco(uid);
  }

  /// Borra todas las fotos guardadas: al cerrar sesión.
  Future<void> borrarTodo() async {
    _memoria.clear();
    _vigentes.clear();
    try {
      final carpeta = await _carpeta();
      if (await carpeta.exists()) await carpeta.delete(recursive: true);
    } catch (_) {
      // Sin carpeta no hay nada que borrar.
    }
  }

  // ── Subir y quitar ─────────────────────────────────────────────────

  /// `PUT /auth/me/foto` (sin [uid]) o `PUT /auth/:id/foto` (de un
  /// dependiente): multipart con el campo `foto`, en JPEG.
  ///
  /// Devuelve la versión nueva y deja la foto en la caché. Los errores
  /// (tamaño, tipo, permiso) llegan como `DioException` con el mensaje de la
  /// API.
  Future<int?> subir(Uint8List jpeg, {String? uid, String? uidPropio}) async {
    final formulario = FormData.fromMap({
      'foto': MultipartFile.fromBytes(
        jpeg,
        filename: 'foto.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });

    final respuesta = await _dio.put<dynamic>(
      uid == null ? '/auth/me/foto' : '/auth/$uid/foto',
      data: formulario,
      options: Options(sendTimeout: const Duration(minutes: 1)),
    );

    final version = versionEnRespuesta(respuesta.data);
    final duenio = uid ?? uidPropio;

    if (duenio != null && duenio.isNotEmpty) {
      if (version != null) {
        await recordar(duenio, version, jpeg);
      } else {
        await olvidar(duenio);
      }
    }

    return version;
  }

  /// `DELETE /auth/me/foto` (sin [uid]) o `DELETE /auth/:id/foto`.
  Future<void> quitar({String? uid, String? uidPropio}) async {
    await _dio.delete<dynamic>(
      uid == null ? '/auth/me/foto' : '/auth/$uid/foto',
    );

    final duenio = uid ?? uidPropio;
    if (duenio != null && duenio.isNotEmpty) await olvidar(duenio);
  }
}
