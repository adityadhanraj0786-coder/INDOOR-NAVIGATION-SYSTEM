import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coolapp/main.dart';

void main() {
  testWidgets('Home screen shows main navigation actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(enableMarquee: false)),
    );

    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Navigation'), findsOneWidget);
  });
}
