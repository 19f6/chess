import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/chess_models.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../services/socket_service.dart';
import '../widgets/chess_board.dart';
import '../widgets/game_over_dialog.dart';

class GameBoardScreen extends StatelessWidget {
  final ServerGame initialGame;
  final int? storyLevelIndex;

  const GameBoardScreen({super.key, required this.initialGame, this.storyLevelIndex});

  @override
  Widget build(BuildContext context) {
    final username = context.read<UserProvider>().username!;
    return ChangeNotifierProvider(
      create: (_) => GameProvider(SocketService.instance, username, initialGame),
      child: _GameBoardView(storyLevelIndex: storyLevelIndex),
    );
  }
}

class _GameBoardView extends StatefulWidget {
  final int? storyLevelIndex;
  const _GameBoardView({this.storyLevelIndex});

  @override
  State<_GameBoardView> createState() => _GameBoardViewState();
}

class _GameBoardViewState extends State<_GameBoardView> {
  StreamSubscription<void>? _turnSub;
  StreamSubscription<GameResult>? _overSub;
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<GameProvider>();
    _turnSub = provider.yourTurnPings.listen((_) => _showTurnNotification());
    _overSub = provider.gameOverEvents.listen(_showGameOver);
  }

  @override
  void dispose() {
    _turnSub?.cancel();
    _overSub?.cancel();
    super.dispose();
  }

  void _showTurnNotification() {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("It's your turn to move!"), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _showGameOver(GameResult result) async {
    if (!mounted || _dialogShown) return;
    _dialogShown = true;
    final provider = context.read<GameProvider>();

    final levelIndex = widget.storyLevelIndex;
    if (levelIndex != null && result.winnerColor == provider.myColor) {
      await context.read<UserProvider>().markStoryLevelComplete(levelIndex);
    }

    if (!mounted) return;
    await showGameOverDialog(
      context,
      result,
      onRestart: () {
        _dialogShown = false;
        provider.restart();
      },
      onLeave: () => Navigator.of(context).popUntil((r) => r.isFirst),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final game = provider.game;
    final opponentName = provider.myColor == 'w' ? game.black?.username : game.white?.username;

    return Scaffold(
      appBar: AppBar(
        title: Text(opponentName != null ? 'vs $opponentName' : 'Chess'),
        actions: [
          if (game.status == 'active')
            IconButton(
              icon: const Icon(Icons.flag),
              tooltip: 'Resign',
              onPressed: () => _confirmResign(context, provider),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (provider.opponentDisconnected)
              Container(
                width: double.infinity,
                color: Colors.orange.shade100,
                padding: const EdgeInsets.all(8),
                child: const Text('Opponent disconnected', textAlign: TextAlign.center),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _StatusBar(provider: provider),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: ChessBoardWidget(),
            ),
            const SizedBox(height: 12),
            Expanded(child: _MoveHistory(moves: game.moveHistory)),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmResign(BuildContext context, GameProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Resign?'),
        content: const Text('Are you sure you want to resign this game?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Resign')),
        ],
      ),
    );
    if (confirm == true) provider.resign();
  }
}

class _StatusBar extends StatelessWidget {
  final GameProvider provider;
  const _StatusBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    final game = provider.game;
    String text;
    if (game.status == 'finished' && game.result != null) {
      text = '${game.result!.headline} ${game.result!.detail}';
    } else if (game.status == 'waiting') {
      text = 'Waiting for opponent…';
    } else {
      final turnLabel = game.turn == 'w' ? 'White' : 'Black';
      text = provider.isMyTurn ? 'Your move ($turnLabel)' : '$turnLabel to move';
      if (game.isCheck) text += ' — Check!';
    }
    return Text(text, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center);
  }
}

class _MoveHistory extends StatelessWidget {
  final List<String> moves;
  const _MoveHistory({required this.moves});

  @override
  Widget build(BuildContext context) {
    if (moves.isEmpty) return const SizedBox.shrink();
    final pairs = <String>[];
    for (var i = 0; i < moves.length; i += 2) {
      final num = (i ~/ 2) + 1;
      final white = moves[i];
      final black = (i + 1 < moves.length) ? moves[i + 1] : '';
      pairs.add('$num. $white $black');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: pairs.length,
      itemBuilder: (context, index) => Text(pairs[index]),
    );
  }
}
