import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class Navigation extends StatefulWidget {
  const Navigation({super.key});

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  double? lat;
  double? lng;


  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    Position pos = await Geolocator.getCurrentPosition(
      //desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      lat = pos.latitude;
      lng = pos.longitude;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Navigation')),
        body: Center(
          child: lat == null
              ? const CircularProgressIndicator()
              : Text('Latitude: $lat, Longitude: $lng'),
        ),
      ),
    );
  }
}
