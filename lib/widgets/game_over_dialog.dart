import 'package:flutter/material.dart';

import '../models/chess_models.dart';

Future<void> showGameOverDialog(
  BuildContext context,
  GameResult result, {
  required VoidCallback onRestart,
  required VoidCallback onLeave,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      icon: Icon(
        result.isDraw ? Icons.handshake : Icons.emoji_events,
        size: 40,
        color: result.isDraw ? Colors.blueGrey : Colors.amber,
      ),
      title: Text(result.isDraw ? 'Draw' : 'Game Over'),
      content: Text(
        '${result.headline}\n${result.detail}',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onLeave();
          },
          child: const Text('Leave'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onRestart();
          },
          child: const Text('Restart'),
        ),
      ],
    ),
  );
}
