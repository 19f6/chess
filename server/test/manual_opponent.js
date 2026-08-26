// Interactive CLI "second player" for manually exercising multiplayer flows
// against the real running server while watching the Flutter app on the
// simulator. Usage:
//   node test/manual_opponent.js <username>
// Then type commands at the prompt:
//   games                 list open public games
//   join <gameId>         join a public game
//   invite <username>     send that user a private invite (auto-accepts none)
//   move <from> <to> [promo]
//   resign
//   state                 print current fen/turn/status
const readline = require('readline');
const { io } = require('socket.io-client');

const username = process.argv[2];
if (!username) {
  console.error('Usage: node test/manual_opponent.js <username>');
  process.exit(1);
}

const socket = io('http://localhost:3000', { transports: ['websocket'] });
let currentGameId = null;

function ack(event, data) {
  return new Promise((resolve) => socket.emit(event, data, resolve));
}

socket.on('connect', async () => {
  const res = await ack('identify', { username });
  console.log('[identify]', res);
  await ack('lobby:enter', {});
  console.log(`Connected as ${username}. Type "help" for commands.`);
  rl.prompt();
});

socket.on('lobby:update', (data) => console.log('\n[lobby:update]', JSON.stringify(data)));
socket.on('game:invite', (data) => {
  console.log('\n[game:invite]', data);
  currentGameId = data.gameId;
});
socket.on('game:state', (data) => {
  currentGameId = data.id;
  console.log(`\n[game:state] turn=${data.turn} status=${data.status} check=${data.isCheck} fen=${data.fen}`);
});
socket.on('game:your_turn', (data) => console.log('\n[game:your_turn]', data));
socket.on('game:over', (data) => console.log('\n[game:over]', data));
socket.on('game:opponent_disconnected', (data) => console.log('\n[game:opponent_disconnected]', data));

const rl = readline.createInterface({ input: process.stdin, output: process.stdout, prompt: `${username}> ` });

rl.on('line', async (line) => {
  const [cmd, ...args] = line.trim().split(/\s+/);
  switch (cmd) {
    case 'help':
      console.log('games | join <id> | invite <username> | move <from> <to> [promo] | resign | state');
      break;
    case 'games': {
      const res = await ack('lobby:enter', {});
      console.log(res.openGames);
      break;
    }
    case 'join': {
      const res = await ack('game:join', { gameId: args[0] });
      console.log(res);
      break;
    }
    case 'invite': {
      const res = await ack('game:create', { isPublic: false, opponentUsername: args[0] });
      console.log(res);
      break;
    }
    case 'move': {
      const res = await ack('game:move', { gameId: currentGameId, from: args[0], to: args[1], promotion: args[2] });
      console.log(res.ok ? 'OK' : res);
      break;
    }
    case 'resign':
      socket.emit('game:resign', { gameId: currentGameId });
      break;
    case 'state':
      console.log({ currentGameId });
      break;
    default:
      if (cmd) console.log('Unknown command. Type "help".');
  }
  rl.prompt();
});
