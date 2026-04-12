import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class RouteMetadata {
  final List<int> floors;
  final int? defaultFloor;
  final Map<int, List<String>> destinationsByFloor;

  RouteMetadata({
    required this.floors,
    required this.defaultFloor,
    required this.destinationsByFloor,
  });

  factory RouteMetadata.fromJson(Map<String, dynamic> json) {
    final rawDestinations =
        (json['destinations_by_floor'] as Map<String, dynamic>? ?? {});

    return RouteMetadata(
      floors: (json['floors'] as List<dynamic>? ?? const [])
          .map((item) => (item as num).toInt())
          .toList(),
      defaultFloor: (json['default_floor'] as num?)?.toInt(),
      destinationsByFloor: rawDestinations.map(
        (key, value) => MapEntry(
          int.parse(key),
          (value as List<dynamic>).map((item) => item.toString()).toList(),
        ),
      ),
    );
  }
}

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
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      floor: (json['floor'] as num?)?.toInt() ?? 0,
    );
  }
}

class RouteResult {
  final String start;
  final String startName;
  final String target;
  final String targetName;
  final double distanceM;
  final List<RouteNode> path;
  final List<String> instructions;

  RouteResult({
    required this.start,
    required this.startName,
    required this.target,
    required this.targetName,
    required this.distanceM,
    required this.path,
    required this.instructions,
  });

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    return RouteResult(
      start: json['start']?.toString() ?? '',
      startName:
          json['start_name']?.toString() ?? json['start']?.toString() ?? '',
      target: json['target']?.toString() ?? '',
      targetName:
          json['target_name']?.toString() ?? json['target']?.toString() ?? '',
      distanceM: (json['distance_m'] as num).toDouble(),
      path: (json['path'] as List<dynamic>)
          .map((item) => RouteNode.fromJson(item as Map<String, dynamic>))
          .toList(),
      instructions: (json['instructions'] as List<dynamic>)
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class RouteApi {
  static const String baseUrl = String.fromEnvironment(
    'ROUTE_API_BASE_URL',
    defaultValue: '192.168.1.7:8000',
  );
  static const Duration _timeout = Duration(seconds: 10);

  static Future<RouteMetadata> fetchMetadata() async {
    final uri = Uri.http(baseUrl, '/metadata');

    try {
      final response = await http.get(uri).timeout(_timeout);
      final data = _decodeObject(response.body);

      if (response.statusCode != 200) {
        throw Exception(
          _extractErrorMessage(
            data,
            fallback: 'Failed to load navigation metadata.',
          ),
        );
      }

      return RouteMetadata.fromJson(data);
    } on TimeoutException {
      throw Exception('Timed out while contacting the backend at $baseUrl.');
    } on http.ClientException catch (error) {
      throw Exception(
        'Could not reach the backend at $baseUrl. Make sure the server is '
        'running on your laptop and your phone is on the same Wi-Fi. '
        '${error.message}',
      );
    }
  }

  static Future<RouteResult> fetchRoute({
    required double userLat,
    required double userLon,
    int? userFloor,
    required String targetName,
    int? targetFloor,
  }) async {
    final queryParams = {
      'user_lat': userLat.toString(),
      'user_lon': userLon.toString(),
      'target_name': targetName,
      if (userFloor != null) 'user_floor': userFloor.toString(),
      if (targetFloor != null) 'target_floor': targetFloor.toString(),
    };

    final uri = Uri.http(baseUrl, '/route', queryParams);

    try {
      final response = await http.get(uri).timeout(_timeout);
      final data = _decodeObject(response.body);

      if (response.statusCode == 200) {
        return RouteResult.fromJson(data);
      }

      throw Exception(
        _extractErrorMessage(
          data,
          fallback: 'Failed to load route. Status code: ${response.statusCode}',
        ),
      );
    } on TimeoutException {
      throw Exception('Timed out while contacting the backend at $baseUrl.');
    } on http.ClientException catch (error) {
      throw Exception(
        'Could not reach the backend at $baseUrl. Make sure the server is '
        'running on your laptop and your phone is on the same Wi-Fi. '
        '${error.message}',
      );
    }
  }

  static Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    throw Exception('Unexpected backend response format.');
  }

  static String _extractErrorMessage(
    Map<String, dynamic> data, {
    required String fallback,
  }) {
    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail;
    }

    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error;
    }

    return fallback;
  }
}
