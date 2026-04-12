class AppConfig {
  const AppConfig._();

  static const String appName = 'NavU';

  static const String backendHost = String.fromEnvironment(
    'NAVU_API_HOST',
    defaultValue: '192.168.1.7:8000',
  );

  static const Duration requestTimeout = Duration(seconds: 12);

  static const List<int> floors = [0, 1, 2];

  static const List<String> announcements = [
    'The app is configured for the updated local backend host 192.168.1.7:8000.',
    'Keep your phone on the same Wi-Fi network as the routing server for live indoor navigation.',
    'Use exact room names when possible to help the route engine match the correct destination.',
  ];
}
