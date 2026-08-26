const { randomUUID } = require('crypto');
const { Chess } = require('chess.js');

// In-memory state. Fine for this app's scope: a single server process,
// no persistence required across restarts.
const games = new Map(); // gameId -> Game
const users = new Map(); // socketId -> { username, socketId, currentGameId }
const usernameToSocket = new Map(); // username -> socketId

function registerUser(socketId, username) {
  usernameToSocket.set(username, socketId);
  const user = { username, socketId, currentGameId: null };
  users.set(socketId, user);
  return user;
}

function removeUser(socketId) {
  const user = users.get(socketId);
  if (user) {
    usernameToSocket.delete(user.username);
    users.delete(socketId);
  }
  return user;
}

function getUser(socketId) {
  return users.get(socketId);
}

function getSocketIdForUsername(username) {
  return usernameToSocket.get(username);
}

function onlineUsernames() {
  return Array.from(users.values()).map((u) => u.username);
}

function createGame({ isPublic, vsBot, botDepth, creator }) {
  const id = randomUUID();
  const chess = new Chess();
  const game = {
    id,
    chess,
    isPublic: !!isPublic,
    vsBot: !!vsBot,
    botDepth: botDepth || 2,
    status: vsBot ? 'active' : 'waiting',
    players: {
      white: { socketId: creator.socketId, username: creator.username },
      black: vsBot ? { socketId: null, username: 'Bot' } : null,
    },
    result: null,
    createdAt: Date.now(),
  };
  games.set(id, game);
  return game;
}

function findPublicOpenGames() {
  return Array.from(games.values()).filter(
    (g) => g.isPublic && g.status === 'waiting' && !g.vsBot
  );
}

function getGame(id) {
  return games.get(id);
}

function joinGame(gameId, user) {
  const game = games.get(gameId);
  if (!game) return null;
  if (game.status !== 'waiting') return null;
  if (game.players.white.socketId === user.socketId) return null;
  game.players.black = { socketId: user.socketId, username: user.username };
  game.status = 'active';
  return game;
}

function removeGame(id) {
  games.delete(id);
}

module.exports = {
  games,
  users,
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
};
