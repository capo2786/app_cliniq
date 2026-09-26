import 'almacen_claves.dart';

/// Correo y contraseña de la última persona que entró en este teléfono.
class CredencialesLocales {
  final String email;
  final String password;

  const CredencialesLocales({required this.email, required this.password});
}

/// Las credenciales del acceso con huella, en el llavero del sistema.
///
/// Se guardan **solo después de un acceso correcto**: guardar lo que alguien
/// escribió antes de que el servidor lo acepte sería guardar una contraseña
/// equivocada, y la huella la mandaría una y otra vez hasta bloquear la
/// cuenta.
///
/// La contraseña nunca sale del llavero para rellenar el formulario: sale
/// únicamente después de que el teléfono verificó la huella o el rostro.
class CredencialesService {
  static const String _emailKey = 'cliniq_email_guardado';
  static const String _passwordKey = 'cliniq_password_guardada';
  static const String _biometriaKey = 'cliniq_biometria_activa';

  final AlmacenClaves _almacen;

  const CredencialesService([this._almacen = const AlmacenClavesSeguro()]);

  Future<void> guardar({
    required String email,
    required String password,
  }) async {
    await _almacen.escribir(_emailKey, email.trim().toLowerCase());
    await _almacen.escribir(_passwordKey, password);
  }

  Future<CredencialesLocales?> leer() async {
    try {
      final email = await _almacen.leer(_emailKey);
      final password = await _almacen.leer(_passwordKey);

      if (email == null ||
          email.isEmpty ||
          password == null ||
          password.isEmpty) {
        return null;
      }

      return CredencialesLocales(email: email, password: password);
    } catch (_) {
      // Un llavero que no contesta equivale a no tener nada guardado: se
      // entra escribiendo, que siempre funciona.
      return null;
    }
  }

  /// Olvida lo guardado: va a entrar otra persona, o se apagó la huella.
  Future<void> borrar() async {
    try {
      await _almacen.borrar(_emailKey);
      await _almacen.borrar(_passwordKey);
    } catch (_) {
      // Nada que hacer: si el llavero no responde tampoco se puede leer.
    }
  }

  /// Si la persona quiere entrar con huella. Encendido si nunca dijo lo
  /// contrario: es un atajo que se suma, no algo que haya que descubrir.
  Future<bool> biometriaActiva() async {
    try {
      return await _almacen.leer(_biometriaKey) != 'no';
    } catch (_) {
      return true;
    }
  }

  Future<void> fijarBiometriaActiva(bool activa) async {
    try {
      await _almacen.escribir(_biometriaKey, activa ? 'si' : 'no');
    } catch (_) {
      // Se queda como estaba; la pantalla vuelve a leerlo.
    }
  }
}
