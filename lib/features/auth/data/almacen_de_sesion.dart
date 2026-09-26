import 'dart:convert';

import '../../../core/storage/almacen_claves.dart';
import 'models/usuario.dart';

/// Una sesión guardada en el teléfono.
class SesionGuardada {
  final String token;

  /// Cuándo vence el token, como instante real (no hora de la clínica).
  final DateTime? venceEn;

  final Usuario usuario;

  const SesionGuardada({
    required this.token,
    required this.usuario,
    this.venceEn,
  });

  /// Si ya venció. Sin dato de vencimiento se le pregunta al servidor.
  bool vencida(DateTime ahora) {
    final vence = venceEn;
    return vence != null && !ahora.isBefore(vence);
  }
}

/// La sesión abierta, guardada en el llavero del sistema.
///
/// El token y el perfil van juntos al llavero y no a las preferencias: el
/// perfil lleva alergias, antecedentes y medicación, y el token abre todo lo
/// demás. Así, al volver a abrir la aplicación —también sin Internet— la
/// persona sigue dentro y ve su perfil.
class AlmacenDeSesion {
  static const String _clave = 'cliniq_sesion_v1';

  final AlmacenClaves _almacen;

  const AlmacenDeSesion([this._almacen = const AlmacenClavesSeguro()]);

  Future<void> guardar(SesionGuardada sesion) async {
    await _almacen.escribir(
      _clave,
      jsonEncode({
        'token': sesion.token,
        'venceEn': sesion.venceEn?.toUtc().toIso8601String(),
        'usuario': sesion.usuario.aJson(),
      }),
    );
  }

  Future<SesionGuardada?> leer() async {
    try {
      final texto = await _almacen.leer(_clave);
      if (texto == null || texto.isEmpty) return null;

      final datos = jsonDecode(texto);
      if (datos is! Map) return null;

      final token = datos['token']?.toString() ?? '';
      final usuario = datos['usuario'];
      if (token.isEmpty || usuario is! Map) return null;

      final vence = datos['venceEn']?.toString();

      return SesionGuardada(
        token: token,
        usuario: Usuario.desdeJson(usuario),
        venceEn: vence == null ? null : DateTime.tryParse(vence),
      );
    } catch (_) {
      // Una sesión ilegible es una sesión que no existe: se vuelve a entrar.
      return null;
    }
  }

  /// Cambia solo el perfil, conservando el token.
  Future<void> actualizarUsuario(Usuario usuario) async {
    final actual = await leer();
    if (actual == null) return;

    await guardar(
      SesionGuardada(
        token: actual.token,
        venceEn: actual.venceEn,
        usuario: usuario,
      ),
    );
  }

  Future<void> borrar() async {
    try {
      await _almacen.borrar(_clave);
    } catch (_) {
      // Si el llavero no responde, tampoco se podrá leer la sesión.
    }
  }
}
