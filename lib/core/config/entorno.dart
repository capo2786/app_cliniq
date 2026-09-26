/// Configuración que depende del entorno, en un solo lugar.
///
/// Los valores se pueden sobrescribir al compilar sin tocar el código:
///
/// ```bash
/// flutter build apk --dart-define=API_URL=https://api.cliniq.ec/api
/// ```
///
/// Sin `--dart-define` se usan los del servidor actual, así que el flujo de
/// compilación de siempre no cambia.
class Entorno {
  const Entorno._();

  /// Dirección base de la API, con el prefijo `/api` incluido.
  ///
  /// Hoy es HTTP plano hacia una IP: por eso Android y iOS llevan una
  /// excepción de tráfico sin cifrar limitada a esa dirección. Cuando la API
  /// pase a HTTPS, se cambia aquí (o con `API_URL`) y se borran las dos
  /// excepciones; el README explica dónde están.
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://195.7.5.134:3000/api',
  );

  /// Dónde vive el panel web, que publica el texto de los documentos legales.
  ///
  /// La aplicación no copia esos textos: los abre en el navegador, así que
  /// una versión nueva de un documento no obliga a publicar la aplicación.
  static const String webUrl = String.fromEnvironment(
    'WEB_URL',
    defaultValue: 'http://195.7.5.134:4500',
  );

  /// Dirección pública de un documento legal por su nombre corto.
  static String urlLegal(String slug) => '$webUrl/legal/$slug';

  /// La zona de la clínica. Ecuador continental no aplica horario de verano.
  static const String zonaHoraria = 'America/Guayaquil';

  /// Diferencia fija de la clínica con UTC (Ecuador continental: UTC−5).
  static const Duration desfaseClinica = Duration(hours: -5);
}
