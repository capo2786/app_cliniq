import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// La copia local de lo último que se descargó: citas, dependientes y
/// catálogos.
///
/// Sirve para dos cosas. Una, abrir la aplicación sin Internet y ver igual
/// las citas: la sala de espera de una clínica no siempre tiene cobertura.
/// Dos, que las pantallas abran con algo en vez de con una rueda.
///
/// Las claves llevan el identificador de la persona (`citas:<uid>`): dos
/// cuentas en el mismo teléfono no comparten lo guardado.
abstract class CacheLocal {
  Future<void> inicializar();

  /// El valor guardado, ya decodificado, o `null` si no hay.
  Future<Object?> leer(String clave);

  /// Guarda cualquier valor que se pueda escribir como JSON.
  Future<void> guardar(String clave, Object? valor);

  /// Borra lo que es de una persona y conserva lo de la clínica (catálogos).
  Future<void> vaciarDatosPersonales();
}

/// Los prefijos que guardan datos de la clínica y no de alguien: se quedan
/// al cerrar sesión, porque sin ellos un formulario no se puede ni empezar.
const Set<String> prefijosDeLaClinica = {'catalogos'};

bool esDatoDeLaClinica(String clave) {
  final corte = clave.indexOf(':');
  final prefijo = corte < 0 ? clave : clave.substring(0, corte);

  return prefijosDeLaClinica.contains(prefijo);
}

/// La caché cifrada en el teléfono, sobre Hive.
///
/// La clave de cifrado se genera la primera vez y vive en el llavero del
/// sistema: las citas y los datos clínicos de los dependientes no quedan
/// legibles aunque alguien copie los archivos de la aplicación.
class CacheHive implements CacheLocal {
  static const String _nombreCaja = 'cliniq_cache_v1';
  static const String _claveCifrado = 'cliniq_cache_clave_v1';

  /// Abrir la caja toca el llavero y el disco, y ninguno de los dos lanza
  /// un error cuando se atasca: simplemente no vuelve. Con este plazo, un
  /// atasco se convierte en una caché en memoria y la aplicación abre igual.
  static const Duration plazoDeApertura = Duration(seconds: 8);

  final FlutterSecureStorage _llavero;

  Box<String>? _caja;
  final Map<String, String> _respaldo = {};
  Future<void>? _apertura;

  CacheHive([this._llavero = const FlutterSecureStorage()]);

  @override
  Future<void> inicializar() => _apertura ??= _abrir();

  Future<void> _abrir() async {
    try {
      await Future(() async {
        await Hive.initFlutter();

        var clave = await _llavero.read(key: _claveCifrado);
        if (clave == null || clave.isEmpty) {
          clave = base64UrlEncode(Hive.generateSecureKey());
          await _llavero.write(key: _claveCifrado, value: clave);
        }

        _caja = await Hive.openBox<String>(
          _nombreCaja,
          encryptionCipher: HiveAesCipher(base64Url.decode(clave)),
        );
      }).timeout(plazoDeApertura);
    } catch (error) {
      // Sin caja en disco se sigue con la memoria: se pierde abrir sin red
      // la próxima vez, no la aplicación.
      debugPrint('Cliniq · la caché local no abrió: $error');
      _caja = null;
    }
  }

  @override
  Future<Object?> leer(String clave) async {
    await inicializar();

    final texto = _caja?.get(clave) ?? _respaldo[clave];
    if (texto == null) return null;

    try {
      return jsonDecode(texto);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> guardar(String clave, Object? valor) async {
    await inicializar();

    final texto = jsonEncode(valor);
    _respaldo[clave] = texto;

    try {
      await _caja?.put(clave, texto);
    } catch (error) {
      debugPrint('Cliniq · no se pudo guardar $clave: $error');
    }
  }

  @override
  Future<void> vaciarDatosPersonales() async {
    await inicializar();

    _respaldo.removeWhere((clave, _) => !esDatoDeLaClinica(clave));

    final caja = _caja;
    if (caja == null) return;

    final personales = caja.keys
        .map((clave) => clave.toString())
        .where((clave) => !esDatoDeLaClinica(clave))
        .toList();

    await caja.deleteAll(personales);
  }
}

/// Una caché que vive solo en memoria. Para las pruebas.
class CacheEnMemoria implements CacheLocal {
  final Map<String, String> valores = {};

  @override
  Future<void> inicializar() async {}

  @override
  Future<Object?> leer(String clave) async {
    final texto = valores[clave];
    return texto == null ? null : jsonDecode(texto);
  }

  @override
  Future<void> guardar(String clave, Object? valor) async =>
      valores[clave] = jsonEncode(valor);

  @override
  Future<void> vaciarDatosPersonales() async =>
      valores.removeWhere((clave, _) => !esDatoDeLaClinica(clave));
}
