/// App configuration — API endpoints
///
/// H-08 FIX: Default values point to localhost for safe local development.
/// For Android emulator, use 10.0.2.2 mapping.
/// For physical device testing, pass:
///   flutter run --dart-define=API_URL=http://<your-ip>:8080
///             --dart-define=WS_URL=ws://<your-ip>:8080/ws
/// For production builds:
///   flutter build apk --dart-define=API_URL=https://api.yourproductiondomain.com
///                     --dart-define=WS_URL=wss://api.yourproductiondomain.com/ws
class AppConfig {
  AppConfig._();

  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:8080/ws',
  );


  // Local dev override — uncomment for local testing:
  // static const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');
  // static const String wsUrl = String.fromEnvironment('WS_URL', defaultValue: 'ws://localhost:8080/ws');

  /// True when running a production build (API_URL points to https)
  static bool get isProduction => apiUrl.startsWith('https://');
}
