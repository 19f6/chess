const { pickBotMove } = require('./chessBot');
const {
  registerUser,
  removeUser,
  getUser,
  getSocketIdForUsername,
  onlineUsernames,
  createGame,
  findPublicOpenGames,
  getGame,
  joinGame,
  removeGame,
} = require('./gameStore');

function serializeGame(game) {
  return {
    id: game.id,
    fen: game.chess.fen(),
    pgn: game.chess.pgn(),
    turn: game.chess.turn(), // 'w' | 'b'
    isCheck: game.chess.isCheck(),
    status: game.status,
    isPublic: game.isPublic,
    vsBot: game.vsBot,
    players: {
      white: game.players.white ? { username: game.players.white.username } : null,
      black: game.players.black ? { username: game.players.black.username } : null,
    },
    moveHistory: game.chess.history(),
    lastMove: game.chess.history({ verbose: true }).slice(-1)[0] || null,
    result: game.result,
  };
}

function serializeGameSummary(game) {
  return {
    id: game.id,
    host: game.players.white ? game.players.white.username : null,
    createdAt: game.createdAt,
  };
}

function lobbySnapshot() {
  return {
    onlineUsers: onlineUsernames(),
    openGames: findPublicOpenGames().map(serializeGameSummary),
  };
}

function checkGameOver(game) {
  const chess = game.chess;
  if (!chess.isGameOver()) return null;
  if (chess.isCheckmate()) {
    // Side to move has no legal moves and is in check -> the other side won.
    const winnerColor = chess.turn() === 'w' ? 'b' : 'w';
    return { reason: 'checkmate', winnerColor };
  }
  if (chess.isStalemate()) return { reason: 'stalemate', winnerColor: null };
  if (chess.isThreefoldRepetition()) return { reason: 'threefold_repetition', winnerColor: null };
  if (chess.isInsufficientMaterial()) return { reason: 'insufficient_material', winnerColor: null };
  if (chess.isDraw()) return { reason: 'draw', winnerColor: null };
  return { reason: 'game_over', winnerColor: null };
}

function colorOf(game, socketId) {
  if (game.players.white && game.players.white.socketId === socketId) return 'w';
  if (game.players.black && game.players.black.socketId === socketId) return 'b';
  return null;
}

module.exports = function registerSocketHandlers(io) {
  function broadcastLobby() {
    io.to('lobby').emit('lobby:update', lobbySnapshot());
  }

  function broadcastState(game) {
    io.to(game.id).emit('game:state', serializeGame(game));
  }

  function notifyTurn(game) {
    const color = game.chess.turn();
    const player = color === 'w' ? game.players.white : game.players.black;
    if (player && player.socketId) {
      io.to(player.socketId).emit('game:your_turn', { gameId: game.id });
    }
  }

  function finishGame(game, overInfo) {
    game.status = 'finished';
    const winnerUsername =
      overInfo.winnerColor === 'w'
        ? game.players.white && game.players.white.username
        : overInfo.winnerColor === 'b'
        ? game.players.black && game.players.black.username
        : null;
    game.result = {
      reason: overInfo.reason,
      winnerColor: overInfo.winnerColor,
      winnerUsername,
    };
    broadcastState(game);
    io.to(game.id).emit('game:over', { gameId: game.id, ...game.result });
    broadcastLobby();
  }

  function maybePlayBotMove(game) {
    if (!game.vsBot || game.status !== 'active' || game.chess.turn() !== 'b') return;
    setTimeout(() => {
      // Game may have finished/restarted while we waited.
      if (game.status !== 'active' || game.chess.turn() !== 'b') return;
      const botMove = pickBotMove(game.chess, game.botDepth);
      if (!botMove) return;
      game.chess.move(botMove);
      broadcastState(game);
      const overInfo = checkGameOver(game);
      if (overInfo) {
        finishGame(game, overInfo);
      } else {
        notifyTurn(game);
      }
    }, 450);
  }

  io.on('connection', (socket) => {
    socket.on('identify', ({ username } = {}, cb) => {
      if (!username || typeof username !== 'string' || !username.trim()) {
        return cb && cb({ ok: false, error: 'Username required' });
      }
      username = username.trim().slice(0, 24);
      if (getSocketIdForUsername(username)) {
        return cb && cb({ ok: false, error: 'Username already taken' });
      }
      registerUser(socket.id, username);
      cb && cb({ ok: true, username });
    });

    socket.on('lobby:enter', (_payload, cb) => {
      socket.join('lobby');
      cb && cb({ ok: true, ...lobbySnapshot() });
    });

    socket.on('lobby:leave', () => {
      socket.leave('lobby');
    });

    socket.on('game:create', ({ isPublic, vsBot, botDepth, opponentUsername } = {}, cb) => {
      const user = getUser(socket.id);
      if (!user) return cb && cb({ ok: false, error: 'Not identified' });
      const game = createGame({
        isPublic: !!isPublic && !vsBot,
        vsBot: !!vsBot,
        botDepth,
        creator: user,
      });
      socket.join(game.id);
      user.currentGameId = game.id;
      cb && cb({ ok: true, game: serializeGame(game) });

      if (game.isPublic) broadcastLobby();

      if (opponentUsername && !vsBot) {
        const targetSocketId = getSocketIdForUsername(opponentUsername);
        if (targetSocketId) {
          io.to(targetSocketId).emit('game:invite', {
            gameId: game.id,
            fromUsername: user.username,
          });
        }
      }

      if (vsBot) {
        notifyTurn(game); // white (the human creator) moves first
      }
    });

    socket.on('game:invite_response', ({ gameId, accept } = {}, cb) => {
      if (!accept) return cb && cb({ ok: true });
      const user = getUser(socket.id);
      if (!user) return cb && cb({ ok: false, error: 'Not identified' });
      const game = joinGame(gameId, user);
      if (!game) return cb && cb({ ok: false, error: 'Game unavailable' });
      socket.join(game.id);
      user.currentGameId = game.id;
      cb && cb({ ok: true, game: serializeGame(game) });
      broadcastState(game);
      broadcastLobby();
      notifyTurn(game);
    });

    socket.on('game:join', ({ gameId } = {}, cb) => {
      const user = getUser(socket.id);
      if (!user) return cb && cb({ ok: false, error: 'Not identified' });
      const game = joinGame(gameId, user);
      if (!game) return cb && cb({ ok: false, error: 'Cannot join game' });
      socket.join(game.id);
      user.currentGameId = game.id;
      cb && cb({ ok: true, game: serializeGame(game) });
      broadcastState(game);
      broadcastLobby();
      notifyTurn(game);
    });

    socket.on('game:legal_moves', ({ gameId, square } = {}, cb) => {
      const game = getGame(gameId);
      if (!game) return cb && cb({ ok: false, error: 'No such game' });
      const moves = game.chess.moves({ square, verbose: true });
      cb &&
        cb({
          ok: true,
          moves: moves.map((m) => ({ to: m.to, promotion: m.promotion || null, flags: m.flags })),
        });
    });

    socket.on('game:move', ({ gameId, from, to, promotion } = {}, cb) => {
      const game = getGame(gameId);
      if (!game || game.status !== 'active') {
        return cb && cb({ ok: false, error: 'Game not active' });
      }
      const color = colorOf(game, socket.id);
      if (!color) return cb && cb({ ok: false, error: 'Not a player in this game' });
      if (game.chess.turn() !== color) return cb && cb({ ok: false, error: 'Not your turn' });

      let move = null;
      try {
        move = game.chess.move({ from, to, promotion: promotion || 'q' });
      } catch (e) {
        move = null;
      }
      if (!move) return cb && cb({ ok: false, error: 'Illegal move' });

      cb && cb({ ok: true, game: serializeGame(game) });
      broadcastState(game);

      const overInfo = checkGameOver(game);
      if (overInfo) {
        finishGame(game, overInfo);
        return;
      }
      notifyTurn(game);
      maybePlayBotMove(game);
    });

    socket.on('game:resign', ({ gameId } = {}) => {
      const game = getGame(gameId);
      if (!game || game.status !== 'active') return;
      const color = colorOf(game, socket.id);
      if (!color) return;
      finishGame(game, { reason: 'resignation', winnerColor: color === 'w' ? 'b' : 'w' });
    });

    socket.on('game:restart', ({ gameId } = {}, cb) => {
      const game = getGame(gameId);
      if (!game) return cb && cb({ ok: false, error: 'No such game' });
      const color = colorOf(game, socket.id);
      if (!color) return cb && cb({ ok: false, error: 'Not a player in this game' });
      game.chess.reset();
      game.status = 'active';
      game.result = null;
      cb && cb({ ok: true, game: serializeGame(game) });
      broadcastState(game);
      notifyTurn(game); // white always starts again
    });

    socket.on('disconnect', () => {
      const user = removeUser(socket.id);
      if (user && user.currentGameId) {
        const game = getGame(user.currentGameId);
        if (game) {
          if (game.status === 'active') {
            io.to(game.id).emit('game:opponent_disconnected', { gameId: game.id });
          } else if (game.status === 'waiting') {
            removeGame(game.id);
          }
        }
      }
      broadcastLobby();
    });
  });
};
