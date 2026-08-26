// Proves genuine real-time multiplayer sync: the app (as "PlayerA") creates
// a public game through the real Waiting Room UI, and a second, independent
// socket.io client ("PlayerB", standing in for a second device) joins and
// plays moves against the live backend. We assert the on-device UI reacts
// to that external player's actions -- i.e. this is not two mocked halves
// talking to each other, it's the shipped app reacting to a real opponent.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as raw_io;

import 'package:chess/config.dart';
import 'package:chess/main.dart';
import 'package:chess/services/socket_service.dart';
import 'package:chess/widgets/chess_board.dart';

Future<Map<String, dynamic>> _ack(raw_io.Socket socket, String event, [Map<String, dynamic>? data]) {
  final completer = Completer<Map<String, dynamic>>();
  socket.emitWithAck(event, data ?? {}, ack: (res) => completer.complete(Map<String, dynamic>.from(res as Map)));
  return completer.future;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a second real socket client joins and plays against the app UI', (tester) async {
    final suffix = Random().nextInt(999999);
    final playerA = 'PlayerA$suffix';
    final playerB = 'PlayerB$suffix';

    SharedPreferences.setMockInitialValues({});
    SocketService.instance.init(AppConfig.serverUrl);

    await tester.pumpWidget(const ChessApp());
    await tester.pumpAndSettle();

    // --- App: identify as PlayerA ---
    await tester.enterText(find.byType(TextField), playerA);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    expect(find.textContaining('Welcome, $playerA'), findsOneWidget);

    // --- App: Waiting Room -> Create Public Game ---
    await tester.tap(find.text('Play Online'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Public Game'));
    // Not pumpAndSettle(): the waiting-room spinner animates indefinitely
    // until an opponent joins, so "settle" would never be reached.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Waiting for an opponent'), findsOneWidget);

    // --- Independent second client: PlayerB finds and joins that game ---
    // forceNew is essential here: without it socket_io_client reuses the
    // Manager (and thus the live connection) the app itself already opened
    // to this same URL, so this would silently ride along on PlayerA's own
    // socket instead of being a genuinely independent second client.
    final opponent = raw_io.io(
      AppConfig.serverUrl,
      raw_io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );
    final connected = Completer<void>();
    opponent.onConnect((_) => connected.complete());
    opponent.connect();
    await connected.future.timeout(const Duration(seconds: 5));

    final identifyRes = await _ack(opponent, 'identify', {'username': playerB});
    expect(identifyRes['ok'], true);
    final lobbyRes = await _ack(opponent, 'lobby:enter', {});
    expect(lobbyRes['ok'], true);
    final openGames = (lobbyRes['openGames'] as List).cast<Map>();
    final myGame = openGames.firstWhere((g) => g['host'] == playerA);

    final joinRes = await _ack(opponent, 'game:join', {'gameId': myGame['id']});
    expect(joinRes['ok'], true, reason: 'PlayerB should be able to join PlayerA\'s public game');

    // --- App should react: navigate PlayerA straight into the Game Board ---
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.textContaining('vs $playerB'), findsOneWidget);
    expect(find.textContaining('Your move'), findsOneWidget); // white (PlayerA) moves first

    // --- PlayerB (black) tries to move out of turn -> server must reject ---
    final earlyMove = await _ack(opponent, 'game:move', {'gameId': myGame['id'], 'from': 'e7', 'to': 'e5'});
    expect(earlyMove['ok'], false);

    // --- PlayerA plays e2-e4 through the real board UI ---
    final boardBox = tester.renderObject<RenderBox>(find.byType(ChessBoardWidget));
    final topLeft = boardBox.localToGlobal(Offset.zero);
    final cell = boardBox.size.width / 8;
    Offset squareCenter(String square) {
      final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = int.parse(square[1]);
      final col = file;
      final row = 8 - rank;
      return topLeft + Offset((col + 0.5) * cell, (row + 0.5) * cell);
    }

    await tester.tapAt(squareCenter('e2'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(squareCenter('e4'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // --- PlayerB replies e7-e5 from the raw socket ---
    final blackMove = await _ack(opponent, 'game:move', {'gameId': myGame['id'], 'from': 'e7', 'to': 'e5'});
    expect(blackMove['ok'], true);

    // --- App must show the turn-notification banner (not just settle
    // straight past it -- catch it mid-flight, before its SnackBar
    // auto-dismisses) ---
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text("It's your turn to move!"), findsOneWidget);

    // --- ... and reflect the opponent's move once the banner clears ---
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.textContaining('e5'), findsWidgets);
    expect(find.textContaining('Your move'), findsOneWidget);

    opponent.dispose();
  });
}
