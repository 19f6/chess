import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chess_models.dart';
import '../services/socket_service.dart';
import '../utils/fen.dart';

class LegalTarget {
  final String to;
  final String? promotion; // null unless this target is a pawn promotion
  const LegalTarget(this.to, this.promotion);
}

/// Drives a single active game screen: board state (derived from the
/// server's FEN), square selection + legal-move highlighting, move
/// submission, and the turn/game-over notification streams the UI reacts
/// to. One instance is created per game and disposed when the game screen
/// closes.
class GameProvider extends ChangeNotifier {
  final SocketService _socket;
  final String myUsername;

  ServerGame game;
  String? selectedSquare;
  List<LegalTarget> legalTargets = [];
  bool opponentDisconnected = false;

  final StreamController<void> _yourTurnController = StreamController.broadcast();
  Stream<void> get yourTurnPings => _yourTurnController.stream;

  final StreamController<GameResult> _gameOverController = StreamController.broadcast();
  Stream<GameResult> get gameOverEvents => _gameOverController.stream;

  late final void Function(dynamic) _onState;
  late final void Function(dynamic) _onYourTurn;
  late final void Function(dynamic) _onOver;
  late final void Function(dynamic) _onDisconnected;

  GameProvider(this._socket, this.myUsername, this.game) {
    _onState = (data) {
      game = ServerGame.fromJson(Map<String, dynamic>.from(data as Map));
      selectedSquare = null;
      legalTargets = [];
      if (game.status == 'active') opponentDisconnected = false;
      notifyListeners();
    };
    _onYourTurn = (data) {
      final incomingId = (data is Map) ? data['gameId'] as String? : null;
      if (incomingId == null || incomingId == game.id) {
        _yourTurnController.add(null);
      }
    };
    _onOver = (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final incomingId = map['gameId'] as String?;
      if (incomingId != null && incomingId != game.id) return;
      _gameOverController.add(GameResult.fromJson(map));
    };
    _onDisconnected = (data) {
      opponentDisconnected = true;
      notifyListeners();
    };
    _socket.on('game:state', _onState);
    _socket.on('game:your_turn', _onYourTurn);
    _socket.on('game:over', _onOver);
    _socket.on('game:opponent_disconnected', _onDisconnected);
  }

  String? get myColor => game.colorFor(myUsername);

  bool get isMyTurn => myColor != null && game.turn == myColor && game.status == 'active';

  List<List<String?>> get board => parseFenBoard(game.fen);

  Set<String> get legalTargetSquares => legalTargets.map((t) => t.to).toSet();

  List<String?> promotionChoicesFor(String to) =>
      legalTargets.where((t) => t.to == to).map((t) => t.promotion).toList();

  Future<void> selectSquare(String square) async {
    if (!isMyTurn) return;
    final row = 8 - int.parse(square[1]);
    final col = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final piece = board[row][col];
    if (piece == null || isWhitePiece(piece) != (myColor == 'w')) {
      clearSelection();
      return;
    }
    selectedSquare = square;
    legalTargets = [];
    notifyListeners();
    final res = await _socket.emitAck('game:legal_moves', {'gameId': game.id, 'square': square});
    if (res['ok'] == true && selectedSquare == square) {
      legalTargets = (res['moves'] as List)
          .map((m) => LegalTarget(m['to'] as String, m['promotion'] as String?))
          .toList();
      notifyListeners();
    }
  }

  void clearSelection() {
    selectedSquare = null;
    legalTargets = [];
    notifyListeners();
  }

  Future<Map<String, dynamic>> attemptMove(String to, {String? promotion}) async {
    final from = selectedSquare;
    if (from == null) return {'ok': false, 'error': 'No piece selected'};
    clearSelection();
    return _socket.emitAck('game:move', {
      'gameId': game.id,
      'from': from,
      'to': to,
      if (promotion != null) 'promotion': promotion,
    });
  }

  void resign() {
    _socket.emit('game:resign', {'gameId': game.id});
  }

  Future<Map<String, dynamic>> restart() {
    return _socket.emitAck('game:restart', {'gameId': game.id});
  }

  @override
  void dispose() {
    _socket.off('game:state', _onState);
    _socket.off('game:your_turn', _onYourTurn);
    _socket.off('game:over', _onOver);
    _socket.off('game:opponent_disconnected', _onDisconnected);
    _yourTurnController.close();
    _gameOverController.close();
    super.dispose();
  }
}
