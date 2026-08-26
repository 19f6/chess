import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chess_models.dart';
import '../services/socket_service.dart';

/// Waiting-room state: who's online, which public games are open to join,
/// and incoming private invites. Also surfaces when a game this player
/// created/joined/was invited to becomes active, so the Waiting Room
/// screen knows to navigate into the Game Board.
class LobbyProvider extends ChangeNotifier {
  final SocketService _socket;

  LobbySnapshot snapshot = LobbySnapshot.empty;

  final StreamController<GameInvite> _inviteController = StreamController.broadcast();
  Stream<GameInvite> get invites => _inviteController.stream;

  final StreamController<ServerGame> _gameReadyController = StreamController.broadcast();
  Stream<ServerGame> get gameReady => _gameReadyController.stream;

  late final void Function(dynamic) _onLobbyUpdate;
  late final void Function(dynamic) _onInvite;
  late final void Function(dynamic) _onGameState;

  LobbyProvider(this._socket) {
    _onLobbyUpdate = (data) {
      snapshot = LobbySnapshot.fromJson(Map<String, dynamic>.from(data as Map));
      notifyListeners();
    };
    _onInvite = (data) {
      _inviteController.add(GameInvite.fromJson(Map<String, dynamic>.from(data as Map)));
    };
    _onGameState = (data) {
      final game = ServerGame.fromJson(Map<String, dynamic>.from(data as Map));
      if (game.status == 'active') {
        _gameReadyController.add(game);
      }
    };
    _socket.on('lobby:update', _onLobbyUpdate);
    _socket.on('game:invite', _onInvite);
    _socket.on('game:state', _onGameState);
  }

  Future<void> enterLobby() async {
    final res = await _socket.emitAck('lobby:enter');
    if (res['ok'] == true) {
      snapshot = LobbySnapshot.fromJson(res);
      notifyListeners();
    }
  }

  void leaveLobby() => _socket.emit('lobby:leave');

  Future<Map<String, dynamic>> createPublicGame() {
    return _socket.emitAck('game:create', {'isPublic': true});
  }

  Future<Map<String, dynamic>> createPrivateInvite(String opponentUsername) {
    return _socket.emitAck('game:create', {
      'isPublic': false,
      'opponentUsername': opponentUsername,
    });
  }

  Future<Map<String, dynamic>> createBotGame(int botDepth) {
    return _socket.emitAck('game:create', {'vsBot': true, 'botDepth': botDepth});
  }

  Future<Map<String, dynamic>> joinGame(String gameId) {
    return _socket.emitAck('game:join', {'gameId': gameId});
  }

  Future<void> respondToInvite(String gameId, bool accept) {
    return _socket.emitAck('game:invite_response', {'gameId': gameId, 'accept': accept});
  }

  @override
  void dispose() {
    _socket.off('lobby:update', _onLobbyUpdate);
    _socket.off('game:invite', _onInvite);
    _socket.off('game:state', _onGameState);
    _inviteController.close();
    _gameReadyController.close();
    super.dispose();
  }
}
