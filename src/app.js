const express = require('express');
const path = require('path');
const requestLogger = require('./middleware/requestLogger');
const errorHandler  = require('./middleware/errorHandler');

const app = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(requestLogger);

// Serve static files from public/
app.use(express.static(path.join(__dirname, '..', 'public')));

// Health check
app.get('/health', (_req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Explicit 404 for all other paths
app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.use(errorHandler);

module.exports = app;
