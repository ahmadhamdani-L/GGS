/// App configuration — API endpoints
///
/// H-08 FIX: Default values no longer point to a developer's LAN IP.
/// In debug mode without --dart-define, the app connects to localhost
/// (works for Android emulator via 10.0.2.2 mapping or iOS simulator).
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
    defaultValue: 'http://localhost:8080', // Android emulator → host machine
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:8080/ws',
  );

  /// True when running a production build (API_URL points to https)
  static bool get isProduction => apiUrl.startsWith('https://');
}
