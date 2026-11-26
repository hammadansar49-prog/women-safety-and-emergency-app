const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const crypto = require('node:crypto');

function fixture() {
  const handlers = {};
  const updates = [];
  let data = { status: 'queued', sid: 'CA-test' };
  const ref = {};
  const db = { doc: () => ref, runTransaction: async (callback) => callback({
    get: async () => ({ exists: true, get: (key) => data[key] }),
    update: (_, change) => { updates.push(change); data = { ...data, ...change }; },
  }) };
  const env = { AI_WEBHOOK_BASE: 'https://example.com', TWILIO_AUTH_TOKEN: 'secret' };
  vm.runInNewContext(fs.readFileSync(require.resolve('./ai-calling'), 'utf8'), {
    exports: handlers, process: { env }, Buffer, URLSearchParams, AbortSignal,
    require: (name) => name === 'firebase-functions/v2/firestore' ? { onDocumentWritten: (_, handler) => handler }
      : name === 'firebase-functions/v2/https' ? { onRequest: (_, handler) => handler }
      : name === 'firebase-admin/firestore' ? { getFirestore: () => db }
      : name === 'node:crypto' ? crypto : require(name),
  });
  const id = 'a'.repeat(64);
  function request(body, signed = true) {
    const payload = `https://example.com/aiCallStatus?id=${id}` + Object.keys(body).sort().map((key) => key + body[key]).join('');
    return { method: 'POST', body, query: { id }, originalUrl: `/aiCallStatus?id=${id}`,
      get: () => signed ? crypto.createHmac('sha1', 'secret').update(payload).digest('base64') : 'forged' };
  }
  return { handlers, updates, request };
}

test('rejects forged provider callbacks', async () => {
  const setup = fixture();
  let status;
  await setup.handlers.aiCallStatus(setup.request({ CallSid: 'CA-test', CallStatus: 'completed' }, false), { sendStatus: (value) => { status = value; } });
  assert.equal(status, 403);
  assert.equal(setup.updates.length, 0);
});

test('signed status callback cannot overwrite terminal state or another call', async () => {
  const setup = fixture();
  const response = { sendStatus: () => {} };
  await setup.handlers.aiCallStatus(setup.request({ CallSid: 'other', CallStatus: 'completed' }), response);
  assert.equal(setup.updates.length, 0);
  await setup.handlers.aiCallStatus(setup.request({ CallSid: 'CA-test', CallStatus: 'completed' }), response);
  await setup.handlers.aiCallStatus(setup.request({ CallSid: 'CA-test', CallStatus: 'ringing' }), response);
  assert.equal(setup.updates.length, 1);
  assert.equal(setup.updates[0].status, 'completed');
});
