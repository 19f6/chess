/// Parses the piece-placement field of a FEN string into an 8x8 grid.
///
/// Row 0 is rank 8 (black's back rank) and row 7 is rank 1 (white's back
/// rank) -- i.e. this is already in top-to-bottom display order for a board
/// drawn with white at the bottom. Each cell is either null (empty) or a
/// single FEN piece letter, uppercase for white ('P','N','B','R','Q','K')
/// and lowercase for black.
List<List<String?>> parseFenBoard(String fen) {
  final boardPart = fen.split(' ').first;
  return boardPart.split('/').map((row) {
    final squares = <String?>[];
    for (final char in row.split('')) {
      final emptyCount = int.tryParse(char);
      if (emptyCount != null) {
        squares.addAll(List<String?>.filled(emptyCount, null));
      } else {
        squares.add(char);
      }
    }
    return squares;
  }).toList();
}

/// Converts a (row, col) grid position (see [parseFenBoard]) to algebraic
/// square notation, e.g. (0, 0) -> 'a8', (7, 7) -> 'h1'.
String squareAt(int row, int col) {
  final file = String.fromCharCode('a'.codeUnitAt(0) + col);
  final rank = 8 - row;
  return '$file$rank';
}

bool isWhitePiece(String pieceChar) => pieceChar == pieceChar.toUpperCase();
