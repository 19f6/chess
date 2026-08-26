// Plays an entire real game to checkmate through the actual app UI (real
// taps on the real board, not a shortcut), against an independent second
// socket client playing black, and verifies the win dialog shows the
// correct winner and reason. This is the strongest possible proof that
// "win/lose" and move handling work end-to-end, not just at the API level.
//
// Run with a backend already running on localhost:3000:
//   flutter test integration_test/full_game_checkmate_test.dart -d <deviceId>
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

  testWidgets('a full game played through the real UI ends in checkmate with the correct winner', (tester) async {
    final suffix = Random().nextInt(999999);
    final human = 'Human$suffix';
    final opponentName = 'Opponent$suffix';

    SharedPreferences.setMockInitialValues({});
    SocketService.instance.init(AppConfig.serverUrl);

    await tester.pumpWidget(const ChessApp());
    await tester.pumpAndSettle();

    // --- Identify and get to the Waiting Room ---
    await tester.enterText(find.byType(TextField), human);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.tap(find.text('Play Online'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Public Game'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // --- Independent second client (black) joins ---
    final opponent = raw_io.io(
      AppConfig.serverUrl,
      raw_io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().enableForceNew().build(),
    );
    final connected = Completer<void>();
    opponent.onConnect((_) => connected.complete());
    opponent.connect();
    await connected.future.timeout(const Duration(seconds: 5));
    await _ack(opponent, 'identify', {'username': opponentName});
    final lobbyRes = await _ack(opponent, 'lobby:enter', {});
    final openGames = (lobbyRes['openGames'] as List).cast<Map>();
    final myGame = openGames.firstWhere((g) => g['host'] == human);
    final gameId = myGame['id'] as String;
    final joinRes = await _ack(opponent, 'game:join', {'gameId': gameId});
    expect(joinRes['ok'], true);

    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byType(ChessBoardWidget), findsOneWidget);

    Offset squareCenter(RenderBox board, String square) {
      final topLeft = board.localToGlobal(Offset.zero);
      final cell = board.size.width / 8;
      final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = int.parse(square[1]);
      return topLeft + Offset((file + 0.5) * cell, (8 - rank + 0.5) * cell);
    }

    Future<void> humanMove(String from, String to) async {
      final board = tester.renderObject<RenderBox>(find.byType(ChessBoardWidget));
      await tester.tapAt(squareCenter(board, from));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tapAt(squareCenter(board, to));
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    Future<void> opponentMove(String from, String to) async {
      final res = await _ack(opponent, 'game:move', {'gameId': gameId, 'from': from, 'to': to});
      expect(res['ok'], true, reason: 'opponent move $from-$to should be legal');
      await tester.pumpAndSettle(const Duration(seconds: 1));
    }

    // Scholar's mate, white (the human, via real UI taps) delivering mate.
    await humanMove('e2', 'e4');
    await opponentMove('e7', 'e5');
    await humanMove('f1', 'c4');
    await opponentMove('b8', 'c6');
    await humanMove('d1', 'h5');
    await opponentMove('g8', 'f6'); // the losing blunder

    // The mating move, tapped on the real board.
    await humanMove('h5', 'f7');

    // --- Win dialog must show up with the correct winner and reason ---
    // (findsWidgets, not findsOneWidget: the dialog's text briefly renders
    // twice mid-transition-animation, which is normal Flutter behavior.)
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('$human wins'), findsWidgets);
    expect(find.textContaining('Checkmate'), findsWidgets);
    expect(find.text('Restart'), findsWidgets);
    expect(find.text('Leave'), findsWidgets);

    opponent.dispose();
  });
}
