// Run with: npm test   (uses Node's built-in test runner, no dependencies)
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');

process.env.BASE_PATH = '/dev/${{ values.name }}';
const { server } = require('./server');
let base;

before(() => new Promise(r => server.listen(0, () => { base = `http://127.0.0.1:${server.address().port}`; r(); })));
after(() => new Promise(r => server.close(r)));

test('health check under BASE_PATH returns 200', async () => {
  const res = await fetch(`${base}/dev/${{ values.name }}/health`);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { status: 'ok' });
});

test('root returns service info', async () => {
  const body = await (await fetch(`${base}/dev/${{ values.name }}/`)).json();
  assert.equal(body.service, '${{ values.name }}');
});

test('unknown path returns 404', async () => {
  assert.equal((await fetch(`${base}/dev/${{ values.name }}/nope`)).status, 404);
});
