// End-to-end smoke test: boots the real server and connects real socket.io
// clients to exercise every behavior called out by the project's audit
// checklist. Run with `npm test`. Each section is labeled with the audit
// question it proves.
const assert = require('assert');
const http = require('http');
const express = require('express');
const cors = require('cors');
const { Server } = require('socket.io');
const { io: ioClient } = require('socket.io-client');

const routes = require('../src/routes');
const registerSocketHandlers = require('../src/socketHandlers');

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function once(socket, event) {
  return new Promise((resolve) => socket.once(event, resolve));
}

function emitAck(socket, event, payload) {
  return new Promise((resolve) => socket.emit(event, payload, resolve));
}

async function main() {
  const app = express();
  app.use(cors());
  app.use(express.json());
  app.use('/api', routes);
  const server = http.createServer(app);
  const io = new Server(server, { cors: { origin: '*' } });
  registerSocketHandlers(io);

  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;
  const url = `http://localhost:${port}`;
  console.log(`test server up on ${url}`);

  const alice = ioClient(url, { transports: ['websocket'] });
  const bob = ioClient(url, { transports: ['websocket'] });
  await Promise.all([once(alice, 'connect'), once(bob, 'connect')]);

  // --- identify ---
  let res = await emitAck(alice, 'identify', { username: 'alice' });
  assert.strictEqual(res.ok, true, 'alice identify should succeed');
  res = await emitAck(bob, 'identify', { username: 'bob' });
  assert.strictEqual(res.ok, true, 'bob identify should succeed');

  const dupe = await emitAck(bob, 'identify', { username: 'alice' });
  assert.strictEqual(dupe.ok, false, 'duplicate username should be rejected');
  console.log('PASS identify + duplicate username rejection');

  // --- lobby ---
  const lobby = await emitAck(alice, 'lobby:enter', {});
  assert.strictEqual(lobby.ok, true);
  assert.ok(lobby.onlineUsers.includes('alice'));
  assert.ok(lobby.onlineUsers.includes('bob'));
  console.log('PASS lobby:enter shows online users');

  // === AUDIT: "backend generates a unique identifier (UUID) for each game
  // session ... ensuring proper identification and management of
  // individual game sessions" ===
  const created = await emitAck(alice, 'game:create', { isPublic: true });
  assert.strictEqual(created.ok, true);
  const gameId = created.game.id;
  assert.match(gameId, UUID_RE, `game id "${gameId}" must be a UUID`);
  assert.strictEqual(created.game.turn, 'w', 'white must move first');
  assert.strictEqual(created.game.status, 'waiting');
  console.log(`PASS game:create -> UUID game id (${gameId}), waiting, white to move`);

  // === AUDIT: "When two players join a game session, does the player
  // with the white pieces play first?" ===
  const aliceYourTurn = once(alice, 'game:your_turn'); // white (alice, the creator) moves first
  const joined = await emitAck(bob, 'game:join', { gameId });
  assert.strictEqual(joined.ok, true);
  assert.strictEqual(joined.game.status, 'active');
  assert.strictEqual(joined.game.turn, 'w');
  await aliceYourTurn;
  console.log('PASS game:join -> active, white (game creator) notified it is their turn first');

  // === AUDIT: "Try performing illegal moves ... Does the app prevent
  // illegal moves?" -- three specific cases called out by the checklist ===

  // 1) Moving a pawn 3 squares up.
  let illegal = await emitAck(alice, 'game:move', { gameId, from: 'e2', to: 'e5' });
  assert.strictEqual(illegal.ok, false, 'pawn moving 3 squares should be rejected');
  console.log('PASS illegal move rejected: pawn 3 squares forward (e2-e5)');

  // 2) Moving a rook diagonally.
  illegal = await emitAck(alice, 'game:move', { gameId, from: 'a1', to: 'b2' });
  assert.strictEqual(illegal.ok, false, 'rook moving diagonally should be rejected');
  console.log('PASS illegal move rejected: rook diagonal (a1-b2)');

  // 3) Castling after the king has already moved (and moved back).
  const castleGame = await emitAck(alice, 'game:create', { isPublic: true });
  const castleId = castleGame.game.id;
  await emitAck(bob, 'game:join', { gameId: castleId });
  const castleMoves = [
    [alice, 'e2', 'e4'], [bob, 'e7', 'e5'],
    [alice, 'g1', 'f3'], [bob, 'b8', 'c6'],
    [alice, 'f1', 'c4'], [bob, 'f8', 'c5'],
    [alice, 'e1', 'f1'], [bob, 'a7', 'a6'], // king steps out, forfeiting castling rights
    [alice, 'f1', 'e1'], [bob, 'a6', 'a5'], // king returns to e1
  ];
  for (const [socket, from, to] of castleMoves) {
    const r = await emitAck(socket, 'game:move', { gameId: castleId, from, to });
    assert.strictEqual(r.ok, true, `setup move ${from}-${to} should be legal`);
  }
  const castleAttempt = await emitAck(alice, 'game:move', { gameId: castleId, from: 'e1', to: 'g1' });
  assert.strictEqual(castleAttempt.ok, false, 'castling after king has moved should be rejected');
  console.log('PASS illegal move rejected: castling after king already moved');

  // === AUDIT: "After a move is played, does the other player receive the
  // move?" ===
  const bobReceivesState = once(bob, 'game:state');
  const aliceMove = await emitAck(alice, 'game:move', { gameId, from: 'e2', to: 'e4' });
  assert.strictEqual(aliceMove.ok, true);
  assert.strictEqual(aliceMove.game.turn, 'b');
  const bobsView = await bobReceivesState;
  assert.strictEqual(bobsView.fen, aliceMove.game.fen, "bob's client must receive alice's move");
  assert.ok(bobsView.moveHistory.includes('e4'));
  console.log('PASS legal move e2-e4 accepted and pushed live to the other player (bob)');

  // out-of-turn move rejected
  const outOfTurn = await emitAck(alice, 'game:move', { gameId, from: 'd2', to: 'd4' });
  assert.strictEqual(outOfTurn.ok, false, 'moving out of turn should be rejected');
  console.log('PASS out-of-turn move rejected');

  await emitAck(bob, 'game:move', { gameId, from: 'e7', to: 'e5' });
  await emitAck(alice, 'game:move', { gameId, from: 'f1', to: 'c4' });
  await emitAck(bob, 'game:move', { gameId, from: 'b8', to: 'c6' });
  await emitAck(alice, 'game:move', { gameId, from: 'd1', to: 'h5' });
  await emitAck(bob, 'game:move', { gameId, from: 'g8', to: 'f6' }); // blunders, allows Qxf7#

  // === AUDIT: "Play the game until one player is mated. Does the game end
  // and the player who mated the other win?" + "does the app send a
  // message to both players indicating the game is over and the reason?" ===
  const gameOverAlice = once(alice, 'game:over');
  const gameOverBob = once(bob, 'game:over');
  const mateMove = await emitAck(alice, 'game:move', { gameId, from: 'h5', to: 'f7' });
  assert.strictEqual(mateMove.ok, true, "Scholar's mate move should be accepted");
  const [overA, overB] = await Promise.all([gameOverAlice, gameOverBob]);
  assert.strictEqual(overA.reason, 'checkmate');
  assert.strictEqual(overA.winnerUsername, 'alice');
  assert.strictEqual(overB.reason, 'checkmate');
  assert.strictEqual(overB.winnerUsername, 'alice');
  console.log("PASS Scholar's mate: game ends, mating player (alice) wins, both players notified with reason='checkmate'");

  // === AUDIT: terminal state coverage for stalemate/draw, not just
  // checkmate ===
  const stalemateGame = await emitAck(alice, 'game:create', { isPublic: true });
  const stalemateId = stalemateGame.game.id;
  await emitAck(bob, 'game:join', { gameId: stalemateId });
  const stalemateLine = [
    [alice, 'e2', 'e3'], [bob, 'a7', 'a5'],
    [alice, 'd1', 'h5'], [bob, 'a8', 'a6'],
    [alice, 'h5', 'a5'], [bob, 'h7', 'h5'],
    [alice, 'a5', 'c7'], [bob, 'a6', 'h6'],
    [alice, 'h2', 'h4'], [bob, 'f7', 'f6'],
    [alice, 'c7', 'd7'], [bob, 'e8', 'f7'],
    [alice, 'd7', 'b7'], [bob, 'd8', 'd3'],
    [alice, 'b7', 'b8'], [bob, 'd3', 'h7'],
    [alice, 'b8', 'c8'], [bob, 'f7', 'g6'],
  ];
  for (const [socket, from, to] of stalemateLine) {
    const r = await emitAck(socket, 'game:move', { gameId: stalemateId, from, to });
    assert.strictEqual(r.ok, true, `stalemate setup move ${from}-${to} should be legal`);
  }
  const stalemateOverAlice = once(alice, 'game:over');
  const stalemateOverBob = once(bob, 'game:over');
  const stalemateMove = await emitAck(alice, 'game:move', { gameId: stalemateId, from: 'c8', to: 'e6' });
  assert.strictEqual(stalemateMove.ok, true);
  const [soA, soB] = await Promise.all([stalemateOverAlice, stalemateOverBob]);
  assert.strictEqual(soA.reason, 'stalemate');
  assert.strictEqual(soA.winnerUsername, null, 'stalemate has no winner');
  assert.strictEqual(soB.reason, 'stalemate');
  console.log("PASS stalemate: game ends in a draw, both players notified with reason='stalemate' and no winner");

  // === "all movement of pieces are correct" -- special-rule moves: pawn
  // promotion and en passant, played out as real legal games (not FEN
  // shortcuts) through the actual server ===

  // Promotion: a real 21-half-move game where white's a-pawn fights through
  // to capture on c8 and promote to a queen.
  const promoGame = await emitAck(alice, 'game:create', { isPublic: true });
  const promoId = promoGame.game.id;
  await emitAck(bob, 'game:join', { gameId: promoId });
  const promoMoves = [
    [alice, 'e2', 'e4'], [bob, 'b8', 'c6'],
    [alice, 'e4', 'e5'], [bob, 'a8', 'b8'],
    [alice, 'e5', 'e6'], [bob, 'b8', 'a8'],
    [alice, 'e6', 'd7'], [bob, 'c8', 'd7'],
    [alice, 'a2', 'a3'], [bob, 'a8', 'b8'],
    [alice, 'a3', 'a4'], [bob, 'b8', 'c8'],
    [alice, 'a4', 'a5'], [bob, 'c8', 'b8'],
    [alice, 'a5', 'a6'], [bob, 'b8', 'c8'],
    [alice, 'a6', 'b7'], [bob, 'c8', 'b8'],
    [alice, 'a1', 'a7'], [bob, 'b8', 'c8'],
  ];
  for (const [socket, from, to] of promoMoves) {
    const r = await emitAck(socket, 'game:move', { gameId: promoId, from, to });
    assert.strictEqual(r.ok, true, `promotion setup move ${from}-${to} should be legal`);
  }
  const promoteMove = await emitAck(alice, 'game:move', {
    gameId: promoId,
    from: 'b7',
    to: 'c8',
    promotion: 'q',
  });
  assert.strictEqual(promoteMove.ok, true);
  assert.strictEqual(
    promoteMove.game.moveHistory.at(-1),
    'bxc8=Q',
    'server should report the promotion move in SAN with the chosen piece'
  );
  assert.ok(promoteMove.game.fen.split(' ')[0].includes('Q'), 'promoted queen should appear in the resulting FEN');
  console.log('PASS pawn promotion: real capture-to-the-back-rank game ends with bxc8=Q');

  // En passant: black's d-pawn double-steps past white's e-pawn, which
  // must be allowed to capture it in passing.
  const epGame = await emitAck(alice, 'game:create', { isPublic: true });
  const epId = epGame.game.id;
  await emitAck(bob, 'game:join', { gameId: epId });
  for (const [socket, from, to] of [
    [alice, 'e2', 'e4'], [bob, 'a7', 'a6'],
    [alice, 'e4', 'e5'], [bob, 'd7', 'd5'],
  ]) {
    const r = await emitAck(socket, 'game:move', { gameId: epId, from, to });
    assert.strictEqual(r.ok, true, `en passant setup move ${from}-${to} should be legal`);
  }
  const epMove = await emitAck(alice, 'game:move', { gameId: epId, from: 'e5', to: 'd6' });
  assert.strictEqual(epMove.ok, true, 'en passant capture should be legal immediately after the double pawn step');
  assert.strictEqual(epMove.game.moveHistory.at(-1), 'exd6', 'en passant should be recorded in SAN as a capture');
  const epBoardRow = epMove.game.fen.split(' ')[0].split('/')[2]; // rank 6
  assert.ok(epBoardRow.includes('P'), "white pawn should have landed on d6");
  console.log('PASS en passant: black pawn double-step captured in passing (exd6)');

  // --- restart ---
  const restarted = await emitAck(alice, 'game:restart', { gameId });
  assert.strictEqual(restarted.ok, true);
  assert.strictEqual(restarted.game.status, 'active');
  assert.strictEqual(restarted.game.turn, 'w');
  assert.strictEqual(restarted.game.moveHistory.length, 0);
  console.log('PASS restart resets board, white to move again');

  // === AUDIT: "Can players invite each other to a game?" ===
  const inviteReceived = once(bob, 'game:invite');
  const inviteCreate = await emitAck(alice, 'game:create', {
    isPublic: false,
    opponentUsername: 'bob',
  });
  assert.strictEqual(inviteCreate.ok, true);
  const invite = await inviteReceived;
  assert.strictEqual(invite.gameId, inviteCreate.game.id);
  assert.strictEqual(invite.fromUsername, 'alice');
  const inviteAccept = await emitAck(bob, 'game:invite_response', { gameId: invite.gameId, accept: true });
  assert.strictEqual(inviteAccept.ok, true);
  assert.strictEqual(inviteAccept.game.status, 'active');
  console.log('PASS private invite: alice invites bob by username, bob receives and accepts it, game becomes active');

  // --- bot game ---
  const botGame = await emitAck(alice, 'game:create', { vsBot: true, botDepth: 1 });
  assert.strictEqual(botGame.ok, true);
  assert.strictEqual(botGame.game.status, 'active');
  const botGameId = botGame.game.id;
  const stateEvents = [];
  const botReplied = new Promise((resolve) => {
    alice.on('game:state', function handler(state) {
      stateEvents.push(state);
      if (stateEvents.length === 2) {
        alice.off('game:state', handler);
        resolve(state);
      }
    });
  });
  const humanMove = await emitAck(alice, 'game:move', { gameId: botGameId, from: 'e2', to: 'e4' });
  assert.strictEqual(humanMove.ok, true);
  const stateAfterBot = await botReplied;
  assert.strictEqual(stateAfterBot.turn, 'w', 'bot should have replied, returning turn to white');
  assert.strictEqual(stateAfterBot.moveHistory.length, 2, 'human move + bot move recorded');
  console.log('PASS vs-bot game: bot auto-replies with a legal move');

  alice.close();
  bob.close();
  server.close();
  console.log('\nALL SMOKE TESTS PASSED');
  process.exit(0);
}

main().catch((err) => {
  console.error('SMOKE TEST FAILED:', err);
  process.exit(1);
});
