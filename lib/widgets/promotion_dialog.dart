import 'package:flutter/material.dart';

/// Shows a piece picker for pawn promotion. Returns the chosen promotion
/// letter ('q','r','b','n'), or null if dismissed.
Future<String?> showPromotionDialog(BuildContext context, String color) {
  final isWhite = color == 'w';
  final options = <String, String>{
    'q': isWhite ? '♕' : '♛',
    'r': isWhite ? '♖' : '♜',
    'b': isWhite ? '♗' : '♝',
    'n': isWhite ? '♘' : '♞',
  };
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Promote pawn to'),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.entries
            .map(
              (e) => IconButton(
                iconSize: 40,
                onPressed: () => Navigator.of(context).pop(e.key),
                icon: Text(e.value, style: const TextStyle(fontSize: 32)),
              ),
            )
            .toList(),
      ),
    ),
  );
}
