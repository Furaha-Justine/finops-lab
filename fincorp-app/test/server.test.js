const test = require('node:test');
const assert = require('node:assert');
const { app } = require('../src/server');

test('GET / returns service info', async () => {
  const server = app.listen(0);
  const port = server.address().port;
  try {
    const res = await fetch(`http://localhost:${port}/`);
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.service, 'fincorp-app');
  } finally {
    server.close();
  }
});

test('GET /health returns ok', async () => {
  const server = app.listen(0);
  const port = server.address().port;
  try {
    const res = await fetch(`http://localhost:${port}/health`);
    assert.strictEqual(res.status, 200);
    const body = await res.json();
    assert.strictEqual(body.status, 'ok');
  } finally {
    server.close();
  }
});

test('GET /db-check fails gracefully without DB env vars', async () => {
  const server = app.listen(0);
  const port = server.address().port;
  try {
    const res = await fetch(`http://localhost:${port}/db-check`);
    assert.strictEqual(res.status, 500);
    const body = await res.json();
    assert.strictEqual(body.status, 'error');
  } finally {
    server.close();
  }
});
