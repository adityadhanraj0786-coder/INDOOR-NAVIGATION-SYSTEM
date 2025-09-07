import 'package:flutter/material.dart';
class Maps extends StatelessWidget {
  const Maps({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Maps'),
        ),
        body: Center(
          child: Text('Map content goes here'),
        ),
      ),
    );
  }
}
