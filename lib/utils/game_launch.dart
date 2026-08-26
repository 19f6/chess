import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chess_models.dart';
import '../providers/lobby_provider.dart';
import '../screens/game_board_screen.dart';

/// Shared by Main Menu ("Play vs Bot") and Story Mode (levels) since both
/// just start a bot game at a given search depth and jump straight to the
/// board -- no waiting room needed for offline/bot play.
Future<void> startBotGameAndNavigate(
  BuildContext context,
  int botDepth, {
  int? storyLevelIndex,
}) async {
  final lobby = context.read<LobbyProvider>();
  final res = await lobby.createBotGame(botDepth);
  if (res['ok'] != true) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not start game')),
      );
    }
    return;
  }
  final game = ServerGame.fromJson(res['game'] as Map);
  if (!context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => GameBoardScreen(initialGame: game, storyLevelIndex: storyLevelIndex),
    ),
  );
}
