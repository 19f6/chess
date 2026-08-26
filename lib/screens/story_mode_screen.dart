import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../utils/game_launch.dart';

class _StoryLevel {
  final String title;
  final String description;
  final int botDepth;
  const _StoryLevel({required this.title, required this.description, required this.botDepth});
}

const _levels = [
  _StoryLevel(title: 'Level 1 — The Novice', description: 'A cautious opponent, prone to mistakes.', botDepth: 1),
  _StoryLevel(title: 'Level 2 — The Challenger', description: 'Plays sound, straightforward chess.', botDepth: 2),
  _StoryLevel(title: 'Level 3 — The Grandmaster', description: 'Calculates several moves ahead.', botDepth: 3),
];

/// Bonus: single-player mode against progressively stronger bots. Levels
/// unlock in order; completion is tracked locally per-device.
class StoryModeScreen extends StatelessWidget {
  const StoryModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final completed = context.watch<UserProvider>().completedStoryLevels;

    return Scaffold(
      appBar: AppBar(title: const Text('Story Mode')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _levels.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final level = _levels[index];
          final isDone = completed.contains(index);
          final isUnlocked = index == 0 || completed.contains(index - 1);
          return Card(
            child: ListTile(
              enabled: isUnlocked,
              leading: CircleAvatar(
                backgroundColor: isDone
                    ? Colors.green
                    : isUnlocked
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                child: Icon(
                  isDone ? Icons.check : (isUnlocked ? Icons.play_arrow : Icons.lock),
                  color: Colors.white,
                ),
              ),
              title: Text(level.title),
              subtitle: Text(level.description),
              onTap: isUnlocked ? () => _play(context, index, level) : null,
            ),
          );
        },
      ),
    );
  }

  Future<void> _play(BuildContext context, int index, _StoryLevel level) async {
    await startBotGameAndNavigate(context, level.botDepth, storyLevelIndex: index);
  }
}
