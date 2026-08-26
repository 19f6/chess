import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../utils/fen.dart';
import 'chess_piece_painter.dart';
import 'promotion_dialog.dart';

// A warm walnut/ivory palette instead of the default chess.com-style
// green -- reads as more considered, and gives white pieces a light square
// that isn't near-white itself.
const _lightSquare = Color(0xFFF1E4D0);
const _darkSquare = Color(0xFF7A5A42);
const _boardFrameDark = Color(0xFF3B2416);
const _boardFrameLight = Color(0xFF5C3A22);
const _selectionGlow = Color(0xFFE0B84D);
const _lastMoveTint = Color(0xFFF3D27A);
const _checkGlow = Color(0xFFE0544A);
const _targetDotOnEmpty = Color(0x8C3B2416);

// Soft gold-accent outline: ties the pieces into the board's existing gold
// selection/last-move highlight and the app's amber accent color.
const _whitePieceFill = Color(0xFFFFF6E0);
const _whitePieceOutline = Color(0xFFB8863E);
const _blackPieceFill = Color(0xFF241505);
const _blackPieceOutline = Color(0xFFE0B84D);

class ChessBoardWidget extends StatelessWidget {
  const ChessBoardWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final board = provider.board;
    final flipped = provider.myColor == 'b';
    final targets = provider.legalTargetSquares;
    final kingInCheckSquare = provider.game.isCheck ? _findKingSquare(board, provider.game.turn) : null;
    final lastFrom = provider.game.lastMoveFrom;
    final lastTo = provider.game.lastMoveTo;

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_boardFrameLight, _boardFrameDark],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cell = constraints.maxWidth / 8;
              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                itemCount: 64,
                itemBuilder: (context, index) {
                  final displayRow = index ~/ 8;
                  final displayCol = index % 8;
                  final row = flipped ? 7 - displayRow : displayRow;
                  final col = flipped ? 7 - displayCol : displayCol;
                  final square = squareAt(row, col);
                  final piece = board[row][col];
                  final isDark = (row + col) % 2 == 1;
                  final isSelected = provider.selectedSquare == square;
                  final isTarget = targets.contains(square);
                  final isKingInCheck = square == kingInCheckSquare;
                  final isLastMove = square == lastFrom || square == lastTo;

                  final baseColor = isDark ? _darkSquare : _lightSquare;

                  return GestureDetector(
                    onTap: () => _handleTap(context, provider, square),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: baseColor),
                        if (isLastMove) Container(color: _lastMoveTint.withValues(alpha: 0.55)),
                        if (isKingInCheck)
                          Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [_checkGlow.withValues(alpha: 0.85), _checkGlow.withValues(alpha: 0.15)],
                              ),
                            ),
                          ),
                        if (isSelected)
                          Container(
                            decoration: BoxDecoration(
                              color: _selectionGlow.withValues(alpha: 0.55),
                              border: Border.all(color: _selectionGlow, width: 2.5),
                            ),
                          ),
                        if (displayCol == 0)
                          Positioned(
                            left: 3,
                            top: 2,
                            child: _CoordinateLabel(text: '${row == 7 ? 1 : 8 - row}', dark: !isDark),
                          ),
                        if (displayRow == 7)
                          Positioned(
                            right: 3,
                            bottom: 1,
                            child: _CoordinateLabel(
                              text: String.fromCharCode('a'.codeUnitAt(0) + col),
                              dark: !isDark,
                            ),
                          ),
                        Center(
                          child: piece != null
                              ? _ChessPieceBadge(piece: piece, size: cell * 0.78)
                              : (isTarget
                                  ? Container(
                                      width: cell * 0.32,
                                      height: cell * 0.32,
                                      decoration: const BoxDecoration(
                                        color: _targetDotOnEmpty,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : null),
                        ),
                        if (isTarget && piece != null)
                          Container(
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: _targetDotOnEmpty, width: 3.5),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String? _findKingSquare(List<List<String?>> board, String turnColor) {
    final kingChar = turnColor == 'w' ? 'K' : 'k';
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        if (board[row][col] == kingChar) return squareAt(row, col);
      }
    }
    return null;
  }

  Future<void> _handleTap(BuildContext context, GameProvider provider, String square) async {
    final isTarget = provider.legalTargetSquares.contains(square);
    if (isTarget && provider.selectedSquare != null) {
      final choices = provider.promotionChoicesFor(square);
      String? promotion;
      if (choices.length > 1) {
        promotion = await showPromotionDialog(context, provider.myColor ?? 'w');
        if (promotion == null) return; // user cancelled
      } else if (choices.isNotEmpty) {
        promotion = choices.first;
      }
      final res = await provider.attemptMove(square, promotion: promotion);
      if (res['ok'] != true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['error']?.toString() ?? 'Illegal move')),
        );
      }
    } else {
      await provider.selectSquare(square);
    }
  }
}

/// A piece rendered as hand-drawn vector artwork (see [ChessPiecePainter])
/// instead of a font glyph or a letter badge -- genuinely pictorial, and
/// both colors share the exact same path so there's no risk of them
/// looking like mismatched piece styles.
class _ChessPieceBadge extends StatelessWidget {
  final String piece;
  final double size;

  const _ChessPieceBadge({required this.piece, required this.size});

  @override
  Widget build(BuildContext context) {
    final isWhite = isWhitePiece(piece);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ChessPiecePainter(
          pieceType: piece,
          fill: isWhite ? _whitePieceFill : _blackPieceFill,
          outline: isWhite ? _whitePieceOutline : _blackPieceOutline,
          strokeWidth: size * 0.045,
        ),
      ),
    );
  }
}

class _CoordinateLabel extends StatelessWidget {
  final String text;
  final bool dark;
  const _CoordinateLabel({required this.text, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: dark ? _darkSquare.withValues(alpha: 0.75) : _lightSquare.withValues(alpha: 0.85),
      ),
    );
  }
}
