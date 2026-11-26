const { test } = require('node:test');
const assert = require('node:assert/strict');
const { configuration, incidentKey, locationFacts, instructions } = require('./ai-policy');
const valid = { AI_CALL_MODE: 'test', AI_TEST_NUMBER: '+15555550123', TWILIO_FROM_NUMBER: '+15555550124', AI_WEBHOOK_BASE: 'https://example.com', TWILIO_ACCOUNT_SID: 'test', TWILIO_AUTH_TOKEN: 'test', OPENAI_API_KEY: 'test', AI_CHAT_MODEL: 'test' };
test('disabled by default and rejects production mode', () => {
  assert.throws(() => configuration({}));
  assert.throws(() => configuration({ ...valid, AI_CALL_MODE: 'production' }));
});
test('rejects emergency short codes and accepts configured full test number', () => {
  assert.throws(() => configuration({ ...valid, AI_TEST_NUMBER: '15' }));
  assert.equal(configuration(valid).to, valid.AI_TEST_NUMBER);
});
test('deduplication keys distinguish senders and delimiter collisions', () => {
  assert.equal(incidentKey('a', 'b'), incidentKey('a', 'b'));
  assert.notEqual(incidentKey('a_b', 'c'), incidentKey('a', 'b_c'));
});
test('invalid location is never presented as known', () => {
  assert.match(locationFacts({ lat: 91, lng: 0, locAt: '2026-11-26' }), /not available/);
  assert.match(locationFacts({ lat: 0, lng: 0, locAt: 'bad' }), /not available/);
  assert.match(locationFacts({ lat: 30, lng: 71, locAt: '2026-11-26T00:00:00Z' }), /may be stale/);
  assert.match(instructions({}), /TEST call/);
});
