import 'package:flutter/material.dart';

class Maps extends StatelessWidget {
  const Maps({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Building Map')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Pinch to zoom, drag to pan, and rotate your phone if you prefer a landscape map view.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    color: const Color(0xFFECE5D6),
                    child: InteractiveViewer(
                      boundaryMargin: const EdgeInsets.all(80),
                      minScale: 0.6,
                      maxScale: 4.5,
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: Image.asset(
                            'assets/map.jpg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
