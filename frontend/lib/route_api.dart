import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    final path = (json['path'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RouteNode.fromJson)
        .toList();

    return RouteResult(
      start:
          json['start_name']?.toString() ??
          _resolveEndpointName(json['start'], path, isStart: true),
      target:
          json['target_name']?.toString() ??
          _resolveEndpointName(json['target'], path, isStart: false),
      distanceM: (json['distance_m'] as num? ?? 0).toDouble(),
      path: path,
      instructions: (json['instructions'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }

  static String _resolveEndpointName(
    Object? rawValue,
    List<RouteNode> path, {
    required bool isStart,
  }) {
    if (path.isNotEmpty) {
      return isStart ? path.first.name : path.last.name;
    }

    return rawValue?.toString() ?? '';
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
    final effectiveTargetFloor = targetFloor ?? userFloor;
    final targetCandidates = _buildTargetCandidates(targetName);
    Object? lastPayload;
    int? lastStatusCode;

    for (final candidate in targetCandidates) {
      try {
        final response = await _postRoute(
          userLat: userLat,
          userLon: userLon,
          userFloor: userFloor,
          targetName: candidate,
          targetFloor: effectiveTargetFloor,
        );

        return _handleRouteResponse(response);
      } on _ApiFailure catch (failure) {
        lastPayload = failure.payload;
        lastStatusCode = failure.statusCode;
        if (!_isRetryableTargetError(failure.message)) {
          throw Exception(failure.message);
        }
      } on SocketException {
        throw Exception(
          'Unable to reach the route server at http://$backendHost. Make sure the backend is running and your phone is on the same Wi-Fi network.',
        );
      } on TimeoutException {
        throw Exception(
          'The route server at http://$backendHost took too long to respond.',
        );
      }
    }

    try {
      final response = await _getRoute(
        userLat: userLat,
        userLon: userLon,
        userFloor: userFloor,
        targetName: targetCandidates.first,
        targetFloor: effectiveTargetFloor,
      );
      return _handleRouteResponse(response);
    } on _ApiFailure catch (failure) {
      lastPayload = failure.payload;
      lastStatusCode = failure.statusCode;
    }

    final fallbackMessage = 'Route request failed (status $lastStatusCode).';
    throw Exception(_extractMessage(lastPayload) ?? fallbackMessage);
  }

  static Future<http.Response> _postRoute({
    required double userLat,
    required double userLon,
    required int userFloor,
    required String targetName,
    required int targetFloor,
  }) {
    final uri = Uri.http(backendHost, '/route');
    return http
        .post(
          uri,
          headers: const {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'user_lat': userLat,
            'user_lon': userLon,
            'user_floor': userFloor,
            'target_name': targetName,
            'target_floor': targetFloor,
          }),
        )
        .timeout(AppConfig.requestTimeout);
  }

  static Future<http.Response> _getRoute({
    required double userLat,
    required double userLon,
    required int userFloor,
    required String targetName,
    required int targetFloor,
  }) {
    final uri = Uri.http(backendHost, '/route', {
      'user_lat': userLat.toString(),
      'user_lon': userLon.toString(),
      'user_floor': userFloor.toString(),
      'target_name': targetName,
      'target_floor': targetFloor.toString(),
    });

    return http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(AppConfig.requestTimeout);
  }

  static RouteResult _handleRouteResponse(http.Response response) {
    final payload = _decodeJson(response.body);

    if (response.statusCode != 200) {
      throw _ApiFailure(
        statusCode: response.statusCode,
        payload: payload,
        message: _extractMessage(payload) ?? 'Request failed.',
      );
    }

    if (payload is! Map<String, dynamic>) {
      throw Exception('Backend returned an unexpected response.');
    }

    if (payload['error'] != null) {
      throw Exception(payload['error'].toString());
    }

    return RouteResult.fromJson(payload);
  }

  static List<String> _buildTargetCandidates(String input) {
    final trimmed = input.trim();
    final variants = <String>{
      trimmed,
      _insertSpacesBetweenLettersAndDigits(trimmed),
      _normalizeWhitespace(trimmed),
      _normalizeWhitespace(_insertSpacesBetweenLettersAndDigits(trimmed)),
    };

    return variants.where((value) => value.isNotEmpty).toList();
  }

  static String _insertSpacesBetweenLettersAndDigits(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'([A-Za-z])(\d)'),
          (match) => '${match.group(1)} ${match.group(2)}',
        )
        .replaceAllMapped(
          RegExp(r'(\d)([A-Za-z])'),
          (match) => '${match.group(1)} ${match.group(2)}',
        );
  }

  static String _normalizeWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _isRetryableTargetError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('target not found') ||
        normalized.contains('not found on floor');
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

class _ApiFailure implements Exception {
  _ApiFailure({
    required this.statusCode,
    required this.payload,
    required this.message,
  });

  final int statusCode;
  final Object? payload;
  final String message;
}
