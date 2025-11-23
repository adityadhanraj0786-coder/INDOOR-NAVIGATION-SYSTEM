import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'route_api.dart';

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  final TextEditingController _targetController = TextEditingController();
  RouteResult? _routeResult;
  String? _error;
  bool _isLoading = false;

  Timer? _timer;   // ⬅️ NEW: Timer for auto-update
  bool _autoStarted = false;


  @override
  void dispose() {
    _timer?.cancel();  // ⬅️ STOP TIMER WHEN SCREEN CLOSES
    _targetController.dispose();
    super.dispose();
  }

  Future<Position> _getCurrentPosition() async {
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _getRoute({bool auto = false}) async {
    final targetName = _targetController.text.trim();
    if (targetName.isEmpty) {
      setState(() {
        _error = 'Please enter destination room name.';
      });
      return;
    }

    // ⬅️ Only show loading spinner on manual button press
    if (!auto) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final position = await _getCurrentPosition();

      const int userFloor = 0;
      const int targetFloor = 2;

      final result = await RouteApi.fetchRoute(
        userLat: position.latitude,
        userLon: position.longitude,
        userFloor: userFloor,
        targetName: targetName,
        targetFloor: targetFloor,
      );

      setState(() {
        _routeResult = result;
      });

      // ⬅️ Start refreshing every 5 secs AFTER first successful route
      if (!_autoStarted) {
        _startAutoUpdate();
      }

    } catch (e) {
      if (!auto) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (!auto) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startAutoUpdate() {
    _autoStarted = true;

    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _getRoute(auto: true),   // ⬅️ auto refresh
    );
  }

  Widget _buildRouteInfo() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Text(
        _error!,
        style: const TextStyle(color: Colors.red),
      );
    }

    if (_routeResult == null) {
      return const Text('Enter a destination and tap "Get Route".');
    }

    final route = _routeResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('From: ${route.start}'),
        Text('To: ${route.target}'),
        const SizedBox(height: 8),
        Text('Distance: ${route.distanceM.toStringAsFixed(1)} meters'),
        const SizedBox(height: 16),

        const Text(
          'Instructions:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        ...route.instructions.map((s) => Text('• $s')),

        const SizedBox(height: 16),
        const Text(
          'Path nodes:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),

        ...route.path.map(
          (node) => Text(
            '${node.name} (floor ${node.floor})\n'
            '[${node.lat.toStringAsFixed(6)}, ${node.lon.toStringAsFixed(6)}]',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _targetController,
              decoration: const InputDecoration(
                labelText: 'Destination room',
                hintText: 'e.g. Room 302',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _getRoute(auto: false),
                child: const Text('Get Route'),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: SingleChildScrollView(
                child: _buildRouteInfo(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
