import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emergency_assistant/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const EmergencyAssistantApp());
    // Just verify it rendered something — a real widget tree, not blank.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
