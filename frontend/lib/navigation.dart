import 'package:flutter/material.dart';
class Navigation extends StatelessWidget {
  const Navigation({super.key});

  @override
  Widget build(BuildContext context) {
    return  MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Navigation'),
        ),
        body: Center(
          child: Text('Navigation content goes here'),
        ),
      ),
    );
  }
}