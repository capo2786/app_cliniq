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

  /// Dónde vive el panel web. La aplicación solo lo abre (en el navegador
  /// integrado) para el autorregistro y para el personal que entra por error.
  static const String webUrl = String.fromEnvironment(
    'WEB_URL',
    defaultValue: 'https://cliniq.gcaicedo-proyectos.com',
  );

  /// El autorregistro de pacientes, en el panel web: la aplicación no copia
  /// ese formulario (cédula, términos, confirmación por correo), lo abre.
  static String get urlRegistro => '$webUrl/registro';
}
