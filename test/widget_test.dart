// Basic smoke test: the app boots to the username/entry screen without
// crashing and without requiring a live backend connection.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess/main.dart';

void main() {
  testWidgets('App boots to the username screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ChessApp());
    await tester.pumpAndSettle();

    expect(find.text('Chess'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });
}
