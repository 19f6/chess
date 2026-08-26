const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');

const routes = require('./routes');
const registerSocketHandlers = require('./socketHandlers');

const app = express();
app.use(cors());
app.use(express.json());
app.use('/api', routes);

const server = http.createServer(app);
const io = new Server(server, { cors: { origin: '*' } });

registerSocketHandlers(io);

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Chess server listening on :${PORT}`);
});
