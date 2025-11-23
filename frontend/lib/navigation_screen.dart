import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/route_api.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final TextEditingController _targetController = TextEditingController();
  RouteResult? _routeResult;
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<Position> _getCurrentPosition() async {
    // 1. Check location service
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    // 2. Check permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied, please enable them in settings.',
      );
    }

    // 3. Get current position
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Future<void> _getRoute() async {
    final targetName = _targetController.text.trim();
    if (targetName.isEmpty) {
      setState(() {
        _error = 'Please enter destination room name.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _routeResult = null;
    });

    try {
      // Example: user floor and target floor – you can change these or make dropdowns
      const int userFloor = 0;
      const int targetFloor = 2;

      final position = await _getCurrentPosition();

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
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
        const SizedBox(height: 8),
        const Text(
          'Instructions:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...route.instructions.map((s) => Text('• $s')),
        const SizedBox(height: 8),
        const Text(
          'Path nodes:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...route.path.map(
          (node) => Text(
            '${node.name} (floor ${node.floor}) – [${node.lat.toStringAsFixed(6)}, ${node.lon.toStringAsFixed(6)}]',
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
        title: const Text('Indoor Navigation'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _targetController,
              decoration: const InputDecoration(
                labelText: 'Destination room name',
                hintText: 'e.g. Room 302',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _getRoute,
                child: const Text('Get Route'),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: SingleChildScrollView(child: _buildRouteInfo())),
          ],
        ),
      ),
    );
  }
}
