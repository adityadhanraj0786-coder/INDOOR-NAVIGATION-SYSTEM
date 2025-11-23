import 'dart:convert';
import 'package:http/http.dart' as http;

class RouteNode {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final int floor;

  RouteNode({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.floor,
  });

  factory RouteNode.fromJson(Map<String, dynamic> json) {
    return RouteNode(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      floor: json['floor'] ?? 0,
    );
  }
}

class RouteResult {
  final String start;
  final String target;
  final double distanceM;
  final List<RouteNode> path;
  final List<String> instructions;

  RouteResult({
    required this.start,
    required this.target,
    required this.distanceM,
    required this.path,
    required this.instructions,
  });

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    return RouteResult(
      start: json['start'] ?? '',
      target: json['target'] ?? '',
      distanceM: (json['distance_m'] as num).toDouble(),
      path: (json['path'] as List)
          .map((item) => RouteNode.fromJson(item))
          .toList(),
      instructions: (json['instructions'] as List)
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class RouteApi {
  // 👉 CHANGE THIS to your laptop's IP
  // Example: '192.168.1.5:8000'
  static const String baseUrl = '192.168.0.110:8000';

  static Future<RouteResult> fetchRoute({
    required double userLat,
    required double userLon,
    required int userFloor,
    required String targetName,
    int? targetFloor,
  }) async {
    final queryParams = {
      'user_lat': userLat.toString(),
      'user_lon': userLon.toString(),
      'user_floor': userFloor.toString(),
      'target_name': targetName,
      if (targetFloor != null) 'target_floor': targetFloor.toString(),
    };

    final uri = Uri.http(baseUrl, '/route', queryParams);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        throw Exception('Backend error: ${data['error']}');
      }

      return RouteResult.fromJson(data);
    } else {
      throw Exception(
          'Failed to load route. Status code: ${response.statusCode}');
    }
  }
}
