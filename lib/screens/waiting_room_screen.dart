import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chess_models.dart';
import '../providers/lobby_provider.dart';
import '../providers/user_provider.dart';
import 'game_board_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  late final LobbyProvider _lobby;
  StreamSubscription<GameInvite>? _inviteSub;
  StreamSubscription<ServerGame>? _readySub;
  String? _pendingGameId;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Captured once here rather than re-read via context in dispose(): by
    // the time dispose() runs during a pushReplacement navigation, this
    // widget's element can already be deactivated, and an inherited-widget
    // lookup (which context.read still performs) throws in that state.
    _lobby = context.read<LobbyProvider>();
    _lobby.enterLobby();
    _inviteSub = _lobby.invites.listen(_handleInvite);
    _readySub = _lobby.gameReady.listen(_handleGameReady);
  }

  @override
  void dispose() {
    _inviteSub?.cancel();
    _readySub?.cancel();
    _lobby.leaveLobby();
    super.dispose();
  }

  void _handleGameReady(ServerGame game) {
    if (_navigated) return;
    final username = context.read<UserProvider>().username;
    if (username == null || game.colorFor(username) == null) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameBoardScreen(initialGame: game)),
    );
  }

  Future<void> _handleInvite(GameInvite invite) async {
    final accept = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Game Invite'),
        content: Text('${invite.fromUsername} invited you to a game.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    _lobby.respondToInvite(invite.gameId, accept == true);
  }

  Future<void> _createPublicGame() async {
    final res = await _lobby.createPublicGame();
    if (!mounted) return;
    if (res['ok'] == true) {
      setState(() => _pendingGameId = (res['game'] as Map)['id'] as String);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not create game')),
      );
    }
  }

  Future<void> _joinGame(String gameId) async {
    final res = await _lobby.joinGame(gameId);
    if (!mounted) return;
    if (res['ok'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not join game')),
      );
    }
  }

  Future<void> _invite(String username) async {
    final res = await _lobby.createPrivateInvite(username);
    if (!mounted) return;
    if (res['ok'] == true) {
      setState(() => _pendingGameId = (res['game'] as Map)['id'] as String);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invite sent to $username')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['error']?.toString() ?? 'Could not invite')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUsername = context.watch<UserProvider>().username;
    final lobby = context.watch<LobbyProvider>();
    final others = lobby.snapshot.onlineUsers.where((u) => u != myUsername).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Waiting Room')),
      body: Column(
        children: [
          if (_pendingGameId != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.primaryContainer,
              padding: const EdgeInsets.all(16),
              child: const Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Expanded(child: Text('Waiting for an opponent to join…')),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _pendingGameId == null ? _createPublicGame : null,
                icon: const Icon(Icons.add),
                label: const Text('Create Public Game'),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _SectionHeader('Open Games (${lobby.snapshot.openGames.length})'),
                if (lobby.snapshot.openGames.isEmpty)
                  const _EmptyRow('No public games open right now'),
                for (final g in lobby.snapshot.openGames)
                  ListTile(
                    leading: const Icon(Icons.sports_esports),
                    title: Text(g.host ?? 'Unknown host'),
                    trailing: FilledButton(
                      onPressed: () => _joinGame(g.id),
                      child: const Text('Join'),
                    ),
                  ),
                const Divider(),
                _SectionHeader('Online Players (${others.length})'),
                if (others.isEmpty) const _EmptyRow('No one else is online yet'),
                for (final u in others)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(u),
                    trailing: OutlinedButton(
                      onPressed: () => _invite(u),
                      child: const Text('Invite'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _EmptyRow extends StatelessWidget {
  final String text;
  const _EmptyRow(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
}
