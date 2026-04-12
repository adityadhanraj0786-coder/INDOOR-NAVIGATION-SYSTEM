import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'app_config.dart';

class RouteNode {
  const RouteNode({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.floor,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final int floor;

  factory RouteNode.fromJson(Map<String, dynamic> json) {
    return RouteNode(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      lat: (json['lat'] as num? ?? 0).toDouble(),
      lon: (json['lon'] as num? ?? 0).toDouble(),
      floor: (json['floor'] as num? ?? 0).toInt(),
    );
  }
}

class RouteResult {
  const RouteResult({
    required this.start,
    required this.target,
    required this.distanceM,
    required this.path,
    required this.instructions,
  });

  final String start;
  final String target;
  final double distanceM;
  final List<RouteNode> path;
  final List<String> instructions;

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    return RouteResult(
      start: json['start_name']?.toString() ?? json['start']?.toString() ?? '',
      target:
          json['target_name']?.toString() ?? json['target']?.toString() ?? '',
      distanceM: (json['distance_m'] as num? ?? 0).toDouble(),
      path: (json['path'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RouteNode.fromJson)
          .toList(),
      instructions: (json['instructions'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class RouteApi {
  const RouteApi._();

  static String get backendHost => AppConfig.backendHost;

  static Future<RouteResult> fetchRoute({
    required double userLat,
    required double userLon,
    required int userFloor,
    required String targetName,
    int? targetFloor,
  }) async {
    final queryParams = <String, String>{
      'user_lat': userLat.toString(),
      'user_lon': userLon.toString(),
      'user_floor': userFloor.toString(),
      'target_name': targetName,
      if (targetFloor != null) 'target_floor': targetFloor.toString(),
    };

    final uri = Uri.http(backendHost, '/route', queryParams);
    final response = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(AppConfig.requestTimeout);

    final payload = _decodeJson(response.body);

    if (response.statusCode != 200) {
      throw Exception(_extractMessage(payload) ?? 'Request failed.');
    }

    if (payload is! Map<String, dynamic>) {
      throw Exception('Backend returned an unexpected response.');
    }

    if (payload['error'] != null) {
      throw Exception(payload['error'].toString());
    }

    return RouteResult.fromJson(payload);
  }

  static Object? _decodeJson(String body) {
    if (body.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static String? _extractMessage(Object? payload) {
    if (payload is Map<String, dynamic>) {
      final detail = payload['detail'];
      final error = payload['error'];
      if (detail != null) {
        return detail.toString();
      }
      if (error != null) {
        return error.toString();
      }
    }

    return null;
  }
}
