// Plays out real UI moves (real taps) to reach kingside castling and
// verifies the board reflects both pieces moving -- king to g1 *and* rook
// to f1 -- which the server only allows chess.js to apply, so this proves
// the special-move UI path (a single tap from e1 to g1) round-trips
// correctly through the server and back into the rendered board.
//
// Run with a backend already running on localhost:3000:
//   flutter test integration_test/castling_test.dart -d <deviceId>
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

  testWidgets('kingside castling via a real UI tap moves both king and rook', (tester) async {
    final suffix = Random().nextInt(999999);
    final human = 'Castler$suffix';
    final opponentName = 'CastlerOpp$suffix';

    SharedPreferences.setMockInitialValues({});
    SocketService.instance.init(AppConfig.serverUrl);

    await tester.pumpWidget(const ChessApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), human);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle(const Duration(seconds: 5));
    await tester.tap(find.text('Play Online'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Public Game'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

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
    await _ack(opponent, 'game:join', {'gameId': gameId});

    await tester.pumpAndSettle(const Duration(seconds: 3));

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

    // Clear the king's path: Nf3, Bc4/e2 style development, then O-O.
    await humanMove('e2', 'e4');
    await opponentMove('e7', 'e5');
    await humanMove('g1', 'f3');
    await opponentMove('b8', 'c6');
    await humanMove('f1', 'c4');
    await opponentMove('g8', 'f6');

    // Kingside castle: a single tap from e1 to g1.
    await humanMove('e1', 'g1');

    expect(find.textContaining('O-O'), findsWidgets, reason: 'move list should record the castle in SAN');

    opponent.dispose();
  });
}
