class AppConfig {
  const AppConfig._();

  static const String appName = 'NavU';

  static const String backendHost = String.fromEnvironment(
    'NAVU_API_HOST',
    defaultValue: '192.168.1.70:8000',
  );

  static const Duration requestTimeout = Duration(seconds: 12);

  static const List<int> floors = [3];

  static const List<String> floorThreeDestinations = [
    'Room 301',
    'Room 302',
    'Lab 3',
    'Lab 4',
    'Corridor C',
    'Lift 3',
    'Stairs 3',
    'Washroom',
    'Water',
  ];

  static const List<String> announcements = [
    'The app is configured for the updated local backend host 192.168.1.7:8000.',
    'Floor selection is currently fixed to floor 3 because the active backend route data is being served for floor 3.',
    'Keep your phone on the same Wi-Fi network as the routing server for live indoor navigation.',
    'Use exact room names when possible to help the route engine match the correct destination.',
  ];
}
