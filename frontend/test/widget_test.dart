import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coolapp/main.dart';

void main() {
  testWidgets('shows the main dashboard after splash', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
