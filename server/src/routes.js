const express = require('express');
const { findPublicOpenGames } = require('./gameStore');

const router = express.Router();

router.get('/health', (req, res) => {
  res.json({ ok: true });
});

router.get('/games', (req, res) => {
  const games = findPublicOpenGames().map((g) => ({
    id: g.id,
    host: g.players.white ? g.players.white.username : null,
    createdAt: g.createdAt,
  }));
  res.json({ games });
});

module.exports = router;
