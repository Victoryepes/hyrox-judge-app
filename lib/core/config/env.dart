/// Configuración de entorno — equivalente a VITE_API_URL / VITE_WS_URL del frontend web.
/// Se inyectan en build time: flutter build apk --dart-define=API_BASE_URL=... --dart-define=WS_BASE_URL=...
class Env {
  Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
