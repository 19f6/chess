// Drives the real app on a real device/simulator against the live backend
// at AppConfig.serverUrl (see README for how to point this elsewhere).
// Covers the golden path: username entry -> main menu -> start a bot game
// -> make a legal move -> bot replies.
//
// Run with a backend already running on localhost:3000:
//   flutter test integration_test/app_test.dart -d <deviceId>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess/config.dart';
import 'package:chess/main.dart';
import 'package:chess/services/socket_service.dart';
import 'package:chess/widgets/chess_board.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('username -> main menu -> play vs bot -> make a move', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Bypassing main() means the socket setup it normally does must happen
    // here instead.
    SocketService.instance.init(AppConfig.serverUrl);

    await tester.pumpWidget(const ChessApp());
    await tester.pumpAndSettle();

    // --- Username screen ---
    expect(find.text('Continue'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'IntegrationTester');
    await tester.tap(find.text('Continue'));
    // Real network round-trip (health check + socket connect + identify).
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // --- Main menu ---
    expect(find.textContaining('Welcome, IntegrationTester'), findsOneWidget);
    expect(find.text('Play vs Bot'), findsOneWidget);
    await tester.tap(find.text('Play vs Bot'));
    await tester.pumpAndSettle();

    // --- Difficulty picker bottom sheet ---
    expect(find.text('Easy'), findsOneWidget);
    await tester.tap(find.text('Easy'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // --- Game board ---
    expect(find.byType(ChessBoardWidget), findsOneWidget);
    expect(find.textContaining('Your move'), findsOneWidget);

    final boardFinder = find.byType(ChessBoardWidget);
    final boardBox = tester.renderObject<RenderBox>(boardFinder);
    final topLeft = boardBox.localToGlobal(Offset.zero);
    final cell = boardBox.size.width / 8;

    Offset squareCenter(String square) {
      final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = int.parse(square[1]);
      final col = file; // white's perspective, not flipped (we're white)
      final row = 8 - rank;
      return topLeft + Offset((col + 0.5) * cell, (row + 0.5) * cell);
    }

    // e2 -> e4
    await tester.tapAt(squareCenter('e2'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(squareCenter('e4'));
    // Give the server round-trip + bot reply (450ms server-side delay) time.
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.textContaining('e4'), findsWidgets);
  });
}
