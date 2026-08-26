// Small material+mobility minimax bot. Not a strong engine, just enough to
// give "Play vs Bot" and Story Mode levels a real (if beatable) opponent.
const PIECE_VALUES = { p: 1, n: 3, b: 3, r: 5, q: 9, k: 0 };

function evaluateBoard(chess) {
  const board = chess.board();
  let score = 0;
  for (const row of board) {
    for (const square of row) {
      if (!square) continue;
      const value = PIECE_VALUES[square.type];
      score += square.color === 'w' ? value : -value;
    }
  }
  return score;
}

function minimax(chess, depth, alpha, beta, maximizing) {
  if (depth === 0 || chess.isGameOver()) {
    return evaluateBoard(chess);
  }
  const moves = chess.moves();
  if (maximizing) {
    let best = -Infinity;
    for (const move of moves) {
      chess.move(move);
      best = Math.max(best, minimax(chess, depth - 1, alpha, beta, false));
      chess.undo();
      alpha = Math.max(alpha, best);
      if (beta <= alpha) break;
    }
    return best;
  }
  let best = Infinity;
  for (const move of moves) {
    chess.move(move);
    best = Math.min(best, minimax(chess, depth - 1, alpha, beta, true));
    chess.undo();
    beta = Math.min(beta, best);
    if (beta <= alpha) break;
  }
  return best;
}

// Picks a move for whichever color is currently to move on `chess`.
function pickBotMove(chess, depth = 2) {
  const moves = chess.moves();
  if (moves.length === 0) return null;
  const maximizing = chess.turn() === 'w';
  let bestScore = maximizing ? -Infinity : Infinity;
  let bestMoves = [];
  for (const move of moves) {
    chess.move(move);
    const score = minimax(chess, Math.max(depth - 1, 0), -Infinity, Infinity, !maximizing);
    chess.undo();
    if ((maximizing && score > bestScore) || (!maximizing && score < bestScore)) {
      bestScore = score;
      bestMoves = [move];
    } else if (score === bestScore) {
      bestMoves.push(move);
    }
  }
  return bestMoves[Math.floor(Math.random() * bestMoves.length)];
}

module.exports = { pickBotMove };
