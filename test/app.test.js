const { describe, it, before, after } = require('node:test');
const assert = require('node:assert/strict');
const supertest = require('supertest');
const app = require('../src/app');

let request;
before(() => { request = supertest(app); });

describe('Health check', () => {
  it('GET /health returns 200 with {status:"ok"}', async () => {
    const res = await request.get('/health');
    assert.equal(res.status, 200);
    assert.equal(res.body.status, 'ok');
  });
});

describe('Unknown routes', () => {
  it('GET /unknown returns 404', async () => {
    const res = await request.get('/unknown-path-that-does-not-exist');
    assert.equal(res.status, 404);
  });

  it('GET /api/nonexistent returns 404', async () => {
    const res = await request.get('/api/nonexistent');
    assert.equal(res.status, 404);
  });
});
