class PlayerInfo {
  final String username;

  const PlayerInfo(this.username);

  factory PlayerInfo.fromJson(Map<dynamic, dynamic> json) =>
      PlayerInfo(json['username'] as String);
}

class GameResult {
  final String reason;
  final String? winnerColor; // 'w' | 'b' | null (draw)
  final String? winnerUsername;

  const GameResult({required this.reason, this.winnerColor, this.winnerUsername});

  factory GameResult.fromJson(Map<dynamic, dynamic> json) => GameResult(
        reason: json['reason'] as String,
        winnerColor: json['winnerColor'] as String?,
        winnerUsername: json['winnerUsername'] as String?,
      );

  bool get isDraw => winnerColor == null;

  String get headline => isDraw ? 'Draw' : '${winnerUsername ?? 'Opponent'} wins!';

  String get detail {
    switch (reason) {
      case 'checkmate':
        return 'Checkmate.';
      case 'resignation':
        return 'By resignation.';
      case 'stalemate':
        return 'Stalemate.';
      case 'threefold_repetition':
        return 'Threefold repetition.';
      case 'insufficient_material':
        return 'Insufficient material.';
      case 'draw':
        return '50-move rule.';
      default:
        return '';
    }
  }
}

class ServerGame {
  final String id;
  final String fen;
  final String pgn;
  final String turn; // 'w' | 'b'
  final bool isCheck;
  final String status; // waiting | active | finished
  final bool isPublic;
  final bool vsBot;
  final PlayerInfo? white;
  final PlayerInfo? black;
  final List<String> moveHistory;
  final GameResult? result;
  final String? lastMoveFrom;
  final String? lastMoveTo;

  const ServerGame({
    required this.id,
    required this.fen,
    required this.pgn,
    required this.turn,
    required this.isCheck,
    required this.status,
    required this.isPublic,
    required this.vsBot,
    this.white,
    this.black,
    required this.moveHistory,
    this.result,
    this.lastMoveFrom,
    this.lastMoveTo,
  });

  factory ServerGame.fromJson(Map<dynamic, dynamic> json) {
    final players = (json['players'] as Map?) ?? {};
    final lastMove = json['lastMove'] as Map?;
    return ServerGame(
      id: json['id'] as String,
      fen: json['fen'] as String,
      pgn: json['pgn'] as String? ?? '',
      turn: json['turn'] as String,
      isCheck: json['isCheck'] as bool? ?? false,
      status: json['status'] as String,
      isPublic: json['isPublic'] as bool? ?? false,
      vsBot: json['vsBot'] as bool? ?? false,
      white: players['white'] != null ? PlayerInfo.fromJson(players['white'] as Map) : null,
      black: players['black'] != null ? PlayerInfo.fromJson(players['black'] as Map) : null,
      moveHistory: ((json['moveHistory'] as List?) ?? const []).map((e) => e.toString()).toList(),
      result: json['result'] != null ? GameResult.fromJson(json['result'] as Map) : null,
      lastMoveFrom: lastMove?['from'] as String?,
      lastMoveTo: lastMove?['to'] as String?,
    );
  }

  /// The color ('w'/'b') the given username is playing, or null if they are
  /// not a player in this game (e.g. a spectator, or not yet joined).
  String? colorFor(String username) {
    if (white?.username == username) return 'w';
    if (black?.username == username) return 'b';
    return null;
  }
}

class OpenGameSummary {
  final String id;
  final String? host;

  const OpenGameSummary({required this.id, this.host});

  factory OpenGameSummary.fromJson(Map<dynamic, dynamic> json) => OpenGameSummary(
        id: json['id'] as String,
        host: json['host'] as String?,
      );
}

class LobbySnapshot {
  final List<String> onlineUsers;
  final List<OpenGameSummary> openGames;

  const LobbySnapshot({required this.onlineUsers, required this.openGames});

  factory LobbySnapshot.fromJson(Map<dynamic, dynamic> json) => LobbySnapshot(
        onlineUsers: ((json['onlineUsers'] as List?) ?? const []).map((e) => e.toString()).toList(),
        openGames: ((json['openGames'] as List?) ?? const [])
            .map((e) => OpenGameSummary.fromJson(e as Map))
            .toList(),
      );

  static const empty = LobbySnapshot(onlineUsers: [], openGames: []);
}

class GameInvite {
  final String gameId;
  final String fromUsername;

  const GameInvite({required this.gameId, required this.fromUsername});

  factory GameInvite.fromJson(Map<dynamic, dynamic> json) => GameInvite(
        gameId: json['gameId'] as String,
        fromUsername: json['fromUsername'] as String,
      );
}
