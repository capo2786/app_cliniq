import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Un llavero de pares clave–valor.
///
/// Existe como interfaz para que las pruebas usen uno en memoria: el
/// llavero de verdad es un complemento nativo y en una prueba no hay
/// teléfono detrás.
abstract class AlmacenClaves {
  Future<String?> leer(String clave);

  Future<void> escribir(String clave, String valor);

  Future<void> borrar(String clave);
}

/// El llavero del sistema: Keychain en iOS, almacenamiento cifrado en
/// Android. Aquí van la sesión, el perfil guardado y las credenciales del
/// acceso con huella: nada de eso se guarda nunca en texto plano.
class AlmacenClavesSeguro implements AlmacenClaves {
  final FlutterSecureStorage _almacen;

  const AlmacenClavesSeguro([this._almacen = const FlutterSecureStorage()]);

  @override
  Future<String?> leer(String clave) => _almacen.read(key: clave);

  @override
  Future<void> escribir(String clave, String valor) =>
      _almacen.write(key: clave, value: valor);

  @override
  Future<void> borrar(String clave) => _almacen.delete(key: clave);
}

/// Un llavero que vive solo mientras la aplicación está abierta.
///
/// Para las pruebas, y de respaldo si el llavero del sistema no responde:
/// mejor una sesión que no sobrevive al cierre que una aplicación que no
/// arranca.
class AlmacenClavesEnMemoria implements AlmacenClaves {
  final Map<String, String> valores;

  AlmacenClavesEnMemoria([Map<String, String>? iniciales])
    : valores = {...?iniciales};

  @override
  Future<String?> leer(String clave) async => valores[clave];

  @override
  Future<void> escribir(String clave, String valor) async =>
      valores[clave] = valor;

  @override
  Future<void> borrar(String clave) async => valores.remove(clave);
}
