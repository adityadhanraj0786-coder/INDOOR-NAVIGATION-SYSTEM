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
  RouteMetadata? _metadata;
  RouteResult? _routeResult;
  String? _error;
  bool _isLoading = false;
  bool _isMetadataLoading = true;
  bool _requestInFlight = false;
  bool _autoRefreshEnabled = false;
  int? _selectedUserFloor;
  int? _selectedTargetFloor;
  String? _selectedDestination;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadMetadata();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadMetadata() async {
    setState(() {
      _isMetadataLoading = true;
      _error = null;
    });

    try {
      final metadata = await RouteApi.fetchMetadata();
      final preferredFloor = metadata.floors.contains(3)
          ? 3
          : (metadata.defaultFloor ??
                (metadata.floors.isNotEmpty ? metadata.floors.first : null));

      if (!mounted) return;

      setState(() {
        _metadata = metadata;
        _selectedUserFloor = preferredFloor;
        _selectedTargetFloor = preferredFloor;
        final destinations = _destinationsForFloor(preferredFloor, metadata);
        _selectedDestination = destinations.isNotEmpty
            ? destinations.first
            : null;
        _isMetadataLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _cleanError(error);
        _isMetadataLoading = false;
      });
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

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission is required to calculate your route.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _getRoute({bool auto = false}) async {
    final targetName = _selectedDestination;
    if (targetName == null || targetName.isEmpty) {
      setState(() {
        _error = 'Please select a destination.';
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
        userFloor: _selectedUserFloor,
        targetName: targetName,
        targetFloor: _selectedTargetFloor,
      );

      if (!mounted) return;

      setState(() {
        _routeResult = result;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (!auto) {
        setState(() {
          _error = _cleanError(error);
        });
      }
    } finally {
      _requestInFlight = false;
      if (!auto && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _setAutoRefresh(bool enabled) {
    _timer?.cancel();
    if (enabled) {
      _timer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _getRoute(auto: true),
      );
    }

    setState(() {
      _autoRefreshEnabled = enabled;
    });
  }

  Widget _buildRouteInfo() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: Colors.red));
    }

    if (_routeResult == null) {
      return const Text(
        'Choose a floor, pick a destination, and tap Get Route.',
      );
    }

    final route = _routeResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('From: ${route.startName}'),
        Text('To: ${route.targetName}'),
        const SizedBox(height: 8),
        Text('Distance: ${route.distanceM.toStringAsFixed(1)} meters'),
        const SizedBox(height: 16),
        const Text(
          'Instructions:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        ...route.instructions.map((step) => Text('- $step')),
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
    if (_isMetadataLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Navigation'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final metadata = _metadata;
    final floors = metadata?.floors ?? const <int>[];
    final destinations = _destinationsForFloor(_selectedTargetFloor, metadata);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: metadata == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ?? 'Unable to load navigation data.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadMetadata,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Backend: ${RouteApi.baseUrl}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey(_selectedUserFloor),
                    initialValue: _selectedUserFloor,
                    decoration: const InputDecoration(
                      labelText: 'Your floor',
                      border: OutlineInputBorder(),
                    ),
                    items: floors
                        .map(
                          (floor) => DropdownMenuItem<int>(
                            value: floor,
                            child: Text('Floor $floor'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedUserFloor = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey(_selectedTargetFloor),
                    initialValue: _selectedTargetFloor,
                    decoration: const InputDecoration(
                      labelText: 'Destination floor',
                      border: OutlineInputBorder(),
                    ),
                    items: floors
                        .map(
                          (floor) => DropdownMenuItem<int>(
                            value: floor,
                            child: Text('Floor $floor'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      final floorDestinations = _destinationsForFloor(
                        value,
                        metadata,
                      );
                      setState(() {
                        _selectedTargetFloor = value;
                        _selectedDestination = floorDestinations.isNotEmpty
                            ? floorDestinations.first
                            : null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedDestination),
                    initialValue: destinations.contains(_selectedDestination)
                        ? _selectedDestination
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Destination',
                      border: OutlineInputBorder(),
                    ),
                    items: destinations
                        .map(
                          (destination) => DropdownMenuItem<String>(
                            value: destination,
                            child: Text(destination),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDestination = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto refresh every 5 seconds'),
                    value: _autoRefreshEnabled,
                    onChanged: _setAutoRefresh,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _getRoute(auto: false),
                      child: const Text('Get Route'),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadMetadata,
                    child: const Text('Reload floors and destinations'),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(child: _buildRouteInfo()),
                  ),
                ],
              ),
      ),
    );
  }

  List<String> _destinationsForFloor(int? floor, RouteMetadata? metadata) {
    if (floor == null || metadata == null) {
      return const [];
    }
    return metadata.destinationsByFloor[floor] ?? const [];
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}
