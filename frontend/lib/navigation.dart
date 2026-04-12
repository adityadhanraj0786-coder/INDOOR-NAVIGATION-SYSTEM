import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'app_config.dart';
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
  bool _requestInFlight = false;
  bool _autoRefreshEnabled = true;
  int _userFloor = AppConfig.floors.first;
  int _targetFloor = AppConfig.floors.last;
  DateTime? _lastUpdatedAt;
  Timer? _autoRefreshTimer;

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _fetchRoute({bool auto = false}) async {
    final targetName = _targetController.text.trim();
    if (targetName.isEmpty) {
      setState(() {
        _error = 'Enter a destination room before requesting a route.';
      });
      return;
    }

    if (_requestInFlight) {
      return;
    }

    _requestInFlight = true;
    if (!auto) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final position = await _getCurrentPosition();
      final result = await RouteApi.fetchRoute(
        userLat: position.latitude,
        userLon: position.longitude,
        userFloor: _userFloor,
        targetName: targetName,
        targetFloor: _targetFloor,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _routeResult = result;
        _error = null;
        _lastUpdatedAt = DateTime.now();
      });

      if (_autoRefreshEnabled) {
        _startAutoRefreshTimer();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      _requestInFlight = false;
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Position> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled on this device.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is permanently denied. Enable it from settings.',
      );
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Location permission is required to fetch a route.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchRoute(auto: true),
    );
  }

  void _toggleAutoRefresh(bool value) {
    setState(() {
      _autoRefreshEnabled = value;
    });

    if (!value) {
      _autoRefreshTimer?.cancel();
      return;
    }

    if (_routeResult != null) {
      _startAutoRefreshTimer();
    }
  }

  String _formatClock(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  Widget _buildResultArea() {
    final theme = Theme.of(context);

    if (_isLoading && _routeResult == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _routeResult == null) {
      return _StatusCard(
        icon: Icons.error_outline,
        title: 'Unable to build route',
        message: _error!,
        color: const Color(0xFF9D1F35),
      );
    }

    if (_routeResult == null) {
      return _StatusCard(
        icon: Icons.route,
        title: 'Ready to navigate',
        message:
            'Enter the destination room name, choose the target floor, and tap "Find route".',
        color: Theme.of(context).colorScheme.primary,
      );
    }

    final route = _routeResult!;
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route Summary',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text('From: ${route.start}'),
                Text('To: ${route.target}'),
                Text('Distance: ${route.distanceM.toStringAsFixed(1)} meters'),
                if (_lastUpdatedAt != null)
                  Text('Last updated: ${_formatClock(_lastUpdatedAt!)}'),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Color(0xFF9D1F35)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instructions',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < route.instructions.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          child: Text(
                            '${index + 1}',
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(route.instructions[index])),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Path Nodes',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (final node in route.path)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F0E6),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.place_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  node.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Floor ${node.floor} - ${node.lat.toStringAsFixed(6)}, ${node.lon.toStringAsFixed(6)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Indoor Navigation')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Find a route',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The app uses your live position, your current floor, and a destination room name to request an indoor route.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _targetController,
                      decoration: InputDecoration(
                        labelText: 'Destination room',
                        hintText: 'Example: Room 302',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            _targetController.clear();
                          },
                          icon: const Icon(Icons.clear),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _userFloor,
                            decoration: const InputDecoration(
                              labelText: 'Your floor',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final floor in AppConfig.floors)
                                DropdownMenuItem<int>(
                                  value: floor,
                                  child: Text('Floor $floor'),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _userFloor = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _targetFloor,
                            decoration: const InputDecoration(
                              labelText: 'Target floor',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final floor in AppConfig.floors)
                                DropdownMenuItem<int>(
                                  value: floor,
                                  child: Text('Floor $floor'),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _targetFloor = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto refresh every 5 seconds'),
                      subtitle: const Text(
                        'Useful while walking so the route can follow your updated position.',
                      ),
                      value: _autoRefreshEnabled,
                      onChanged: _toggleAutoRefresh,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isLoading
                                ? null
                                : () => _fetchRoute(auto: false),
                            icon: const Icon(Icons.route),
                            label: Text(
                              _isLoading ? 'Finding...' : 'Find route',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          tooltip: 'Refresh now',
                          onPressed: _isLoading
                              ? null
                              : () => _fetchRoute(auto: false),
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildResultArea(),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
