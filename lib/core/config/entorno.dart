/// Configuración que depende del entorno, en un solo lugar.
///
/// Los valores se pueden sobrescribir al compilar sin tocar el código:
///
/// ```bash
/// flutter build apk --dart-define=API_URL=http://192.168.1.10:3000/api
/// ```
///
/// Sin `--dart-define` se usan los del servidor actual, así que el flujo de
/// compilación de siempre no cambia.
class Entorno {
  const Entorno._();

  /// Dirección base de la API, con el prefijo `/api` incluido. Siempre HTTPS:
  /// Android e iOS bloquean el HTTP plano y la aplicación no lleva excepciones.
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api-cliniq.gcaicedo-proyectos.com/api',
  );

  /// Dónde vive el panel web, que publica el texto de los documentos legales.
  ///
  /// La aplicación no copia esos textos: los abre en el navegador, así que
  /// una versión nueva de un documento no obliga a publicar la aplicación.
  static const String webUrl = String.fromEnvironment(
    'WEB_URL',
    defaultValue: 'https://cliniq.gcaicedo-proyectos.com',
  );

  /// Dirección pública de un documento legal por su nombre corto.
  static String urlLegal(String slug) => '$webUrl/legal/$slug';

  /// El autorregistro de pacientes, en el panel web: la aplicación no copia
  /// ese formulario (cédula, términos, confirmación por correo), lo abre.
  static String get urlRegistro => '$webUrl/registro';

  /// Una ruta del panel web, para lo que la aplicación no tiene pantalla
  /// propia (un enlace del menú que no conoce): `/mi-salud` →
  /// `https://<web>/mi-salud`.
  static String urlWeb(String ruta) {
    final limpia = ruta.trim();
    return '$webUrl${limpia.startsWith('/') ? '' : '/'}$limpia';
  }
}
