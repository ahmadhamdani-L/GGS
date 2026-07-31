/// App configuration — API endpoints
class AppConfig {
  AppConfig._();

  // iOS Simulator CANNOT use localhost - must use actual IP
  // Android Emulator: use 10.0.2.2 (maps to host machine)
  // Physical Device: use your machine's IP address
  // Current machine IP: 10.168.69.185
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:8080/ws',
  );
}
