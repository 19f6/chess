import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../services/socket_service.dart';
import '../utils/game_launch.dart';
import 'story_mode_screen.dart';
import 'username_screen.dart';
import 'waiting_room_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final username = context.watch<UserProvider>().username ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Chess')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.tertiary,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text('♚', style: TextStyle(fontSize: 44, color: Colors.white)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome, $username',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 32),
                _MenuButton(
                  icon: Icons.public,
                  label: 'Play Online',
                  subtitle: 'Waiting room, invites & public games',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WaitingRoomScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                _MenuButton(
                  icon: Icons.smart_toy,
                  label: 'Play vs Bot',
                  subtitle: 'Offline match against the AI',
                  onTap: () => _pickBotDifficulty(context),
                ),
                const SizedBox(height: 12),
                _MenuButton(
                  icon: Icons.auto_stories,
                  label: 'Story Mode',
                  subtitle: 'Progress through AI difficulty levels',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StoryModeScreen()),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () async {
                    SocketService.instance.disconnect();
                    await context.read<UserProvider>().clearUsername();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const UsernameScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Switch Player'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickBotDifficulty(BuildContext context) async {
    final depth = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Choose difficulty', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.sentiment_satisfied),
              title: const Text('Easy'),
              onTap: () => Navigator.pop(sheetContext, 1),
            ),
            ListTile(
              leading: const Icon(Icons.sentiment_neutral),
              title: const Text('Medium'),
              onTap: () => Navigator.pop(sheetContext, 2),
            ),
            ListTile(
              leading: const Icon(Icons.sentiment_very_dissatisfied),
              title: const Text('Hard'),
              onTap: () => Navigator.pop(sheetContext, 3),
            ),
          ],
        ),
      ),
    );
    if (depth == null || !context.mounted) return;
    await startBotGameAndNavigate(context, depth);
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: scheme.onPrimaryContainer, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
