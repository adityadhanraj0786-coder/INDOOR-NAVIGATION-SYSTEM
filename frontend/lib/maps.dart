import 'package:flutter/material.dart';

class Maps extends StatelessWidget {
  const Maps({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('Maps')),
        body: Center(
          child: InteractiveViewer(
            //quarterTurns: 1, // 1 = 90° rotation
            panEnabled: true, // can drag
            scaleEnabled: true, // can zoom
            minScale: 0.5,
            maxScale: 5.0,
            child: RotatedBox(
              quarterTurns: 1, // rotate 90° (landscape)
              child: Image.asset('assets/map.jpg'),
            ),
          ),
        ),
      ),
    );
  }
}
