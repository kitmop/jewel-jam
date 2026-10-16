'use strict';

const path = require('path');
const express = require('express');

const PORT = Number.parseInt(process.env.PORT, 10) || 3000;
const HOST = process.env.HOST || '0.0.0.0';
const PUBLIC_DIR = path.join(__dirname, 'public');

const app = express();
app.disable('x-powered-by');

// Health check (handy for `curl localhost:3000/healthz` and uptime monitors).
app.get('/healthz', (req, res) => res.type('text/plain').send('ok'));

app.use(
  express.static(PUBLIC_DIR, {
    index: 'index.html',
    etag: true,
    maxAge: '1h',
    setHeaders(res, filePath) {
      // Always revalidate the game page so updates show up immediately.
      if (filePath.endsWith('.html')) {
        res.setHeader('Cache-Control', 'no-cache');
      }
      res.setHeader('X-Content-Type-Options', 'nosniff');
    },
  })
);

// Anything else: plain 404 (no stack traces leaked).
app.use((req, res) => res.status(404).type('text/plain').send('Not found'));

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).type('text/plain').send('Server error');
});

const server = app.listen(PORT, HOST, () => {
  console.log(`Game server listening on http://${HOST}:${PORT}`);
});

server.on('error', (err) => {
  console.error('Failed to start server:', err.message);
  process.exit(1);
});

function shutdown(signal) {
  console.log(`${signal} received, shutting down`);
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(0), 5000).unref();
}
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
