import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test for basic widget rendering', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('LibraryPlus'),
        ),
      ),
    );
    expect(find.text('LibraryPlus'), findsOneWidget);
  });
}
