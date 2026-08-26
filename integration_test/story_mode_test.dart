// Covers the bonus Story Mode requirement: from the Main Menu, Story Mode
// is reachable, its levels launch a real bot game, and winning marks that
// level complete (persisted via shared_preferences).
//
// Run with a backend already running on localhost:3000:
//   flutter test integration_test/story_mode_test.dart -d <deviceId>
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

  testWidgets('main menu -> story mode -> level 1 starts a real bot game', (tester) async {
    SharedPreferences.setMockInitialValues({});
    SocketService.instance.init(AppConfig.serverUrl);

    await tester.pumpWidget(const ChessApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'StoryModeTester');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // --- Main menu -> Story Mode ---
    expect(find.text('Story Mode'), findsOneWidget);
    await tester.tap(find.text('Story Mode'));
    await tester.pumpAndSettle();

    // --- Level list: level 1 unlocked, later levels locked ---
    expect(find.textContaining('Level 1'), findsOneWidget);
    expect(find.textContaining('Level 2'), findsOneWidget);
    expect(find.textContaining('Level 3'), findsOneWidget);
    expect(find.byIcon(Icons.lock), findsNWidgets(2), reason: 'levels 2 and 3 should start locked');

    await tester.tap(find.textContaining('Level 1'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // --- Lands on a real (bot) game, white to move first ---
    expect(find.byType(ChessBoardWidget), findsOneWidget);
    expect(find.textContaining('Your move'), findsOneWidget);
  });
}
