const { onDocumentWritten } = require('firebase-functions/v2/firestore');
const { onRequest } = require('firebase-functions/v2/https');
const { getFirestore } = require('firebase-admin/firestore');
const { createHmac, timingSafeEqual } = require('node:crypto');
const { incidentKey, configuration, locationFacts, instructions } = require('./ai-policy');

const secrets = ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'OPENAI_API_KEY'];
const terminal = new Set(['completed', 'busy', 'failed', 'no-answer', 'canceled']);
const xml = (value) => String(value).replace(/[<>&"']/g, (char) => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&apos;' }[char]));
const end = (message) => `<Response><Say>${xml(message)}</Say><Hangup/></Response>`;

async function twilio(path, data) {
  const response = await fetch(`https://api.twilio.com/2010-04-01/Accounts/${process.env.TWILIO_ACCOUNT_SID}/${path}.json`, {
    method: 'POST',
    headers: { Authorization: `Basic ${Buffer.from(`${process.env.TWILIO_ACCOUNT_SID}:${process.env.TWILIO_AUTH_TOKEN}`).toString('base64')}`, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(data), signal: AbortSignal.timeout(12000),
  });
  if (!response.ok) throw new Error('provider_failed');
  return response.json();
}

exports.aiSosCall = onDocumentWritten({ document: 'sosAlerts/{id}', secrets }, async (event) => {
  const alert = event.data.after.exists ? event.data.after.data() : event.data.before.data();
  if (!alert || typeof alert.sender !== 'string' || typeof alert.eventId !== 'string') return;
  const db = getFirestore();
  const ref = db.doc(`aiCalls/${incidentKey(alert.sender, alert.eventId)}`);
  if (!event.data.after.exists || alert.status !== 'active') {
    const old = await ref.get();
    if (!old.exists) return;
    await ref.update({ cancelRequested: true });
    if (old.get('sid') && !terminal.has(old.get('status'))) {
      await twilio(`Calls/${old.get('sid')}`, { Status: 'completed' });
      await ref.update({ status: 'canceled' });
    }
    return;
  }
  let config;
  try { config = configuration(process.env); } catch (_) { return; }
  const enrolled = (process.env.AI_TEST_SENDERS || '').split(',').map((value) => value.trim());
  if (!enrolled.includes(alert.sender)) return;
  const now = Date.now();
  if (!alert.createdAt?.toMillis || now - alert.createdAt.toMillis() > 120000 || alert.createdAt.toMillis() > now + 10000) return;
  const quota = db.doc(`aiCallLimits/${Math.floor(now / 3600000)}`);
  const claimed = await db.runTransaction(async (tx) => {
    const [current, limit, latest] = await Promise.all([tx.get(ref), tx.get(quota), tx.get(event.data.after.ref)]);
    if (current.exists || !latest.exists || latest.get('status') !== 'active') return false;
    const count = limit.get('count') || 0;
    tx.create(ref, { sender: alert.sender, eventId: alert.eventId, alertPath: event.data.after.ref.path,
      status: count >= 3 ? 'rate-limited' : 'requesting', createdAt: new Date(), cancelRequested: false });
    if (count >= 3) return false;
    tx.set(quota, { count: count + 1 });
    return true;
  });
  if (!claimed) return;
  try {
    const latest = await event.data.after.ref.get();
    if (!latest.exists || latest.get('status') !== 'active' || (await ref.get()).get('cancelRequested')) {
      await ref.update({ status: 'canceled' }); return;
    }
    const call = await twilio('Calls', { To: config.to, From: config.from,
      Url: `${config.base}/aiVoice?id=${ref.id}&turn=0`, Method: 'POST',
      StatusCallback: `${config.base}/aiCallStatus?id=${ref.id}`, StatusCallbackMethod: 'POST',
      Timeout: '20', TimeLimit: '180' });
    await db.runTransaction(async (tx) => {
      const current = await tx.get(ref);
      tx.update(ref, { sid: call.sid, ...(current.get('status') === 'requesting' ? { status: 'queued' } : {}) });
    });
    if ((await ref.get()).get('cancelRequested')) {
      await twilio(`Calls/${call.sid}`, { Status: 'completed' });
      await ref.update({ status: 'canceled' });
    }
  } catch (_) {
    await ref.update({ status: 'unknown', detail: 'Provider request failed or timed out. No automatic retry to avoid duplicate calls.' });
  }
});

function authorized(req, endpoint) {
  if (req.method !== 'POST') return false;
  const url = `${process.env.AI_WEBHOOK_BASE?.replace(/\/$/, '')}/${endpoint}${req.originalUrl.includes('?') ? req.originalUrl.slice(req.originalUrl.indexOf('?')) : ''}`;
  const payload = url + Object.keys(req.body || {}).sort().map((key) => key + req.body[key]).join('');
  const expected = createHmac('sha1', process.env.TWILIO_AUTH_TOKEN || '').update(payload).digest('base64');
  const actual = req.get('x-twilio-signature') || '';
  return actual.length === expected.length && timingSafeEqual(Buffer.from(actual), Buffer.from(expected));
}

exports.aiVoice = onRequest({ secrets, timeoutSeconds: 30 }, async (req, res) => {
  if (!authorized(req, 'aiVoice') || !/^[a-f0-9]{64}$/.test(req.query.id || '')) { res.sendStatus(403); return; }
  res.type('text/xml');
  try {
    const config = configuration(process.env);
    const ref = getFirestore().doc(`aiCalls/${req.query.id}`);
    const state = await ref.get();
    if (!state.exists || state.get('cancelRequested') || (state.get('sid') && state.get('sid') !== req.body.CallSid)) { res.send(end('This test has ended.')); return; }
    const alert = await getFirestore().doc(state.get('alertPath')).get();
    if (!alert.exists || alert.get('status') !== 'active') { res.send(end('The SOS is no longer active.')); return; }
    const turn = Number(req.query.turn);
    if (!Number.isInteger(turn) || turn < 0 || turn >= 6) { res.send(end('Test call limit reached. Goodbye.')); return; }
    let reply = `This is a SafeHer AI assistant test call, not a police call. A user sent an SOS. Their exact situation is unconfirmed. ${locationFacts(alert.data())}`;
    if (turn > 0 && req.body.SpeechResult) {
      const response = await fetch('https://api.openai.com/v1/responses', { method: 'POST',
        headers: { Authorization: `Bearer ${process.env.OPENAI_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ model: process.env.AI_CHAT_MODEL, instructions: instructions(alert.data()),
          input: String(req.body.SpeechResult).slice(0, 1500), max_output_tokens: 180, store: false }),
        signal: AbortSignal.timeout(8000) });
      if (!response.ok) throw new Error('model_failed');
      const result = await response.json();
      reply = (result.output || []).flatMap((item) => item.content || []).filter((part) => part.type === 'output_text').map((part) => part.text).join(' ').slice(0, 1200);
      if (!reply) throw new Error('empty_reply');
    } else if (turn > 0) reply = 'I did not hear a question. Please ask about the reported SOS or location.';
    res.send(`<Response><Gather input="speech" language="en-US" timeout="5" speechTimeout="auto" actionOnEmptyResult="true" method="POST" action="${xml(`${config.base}/aiVoice?id=${ref.id}&turn=${turn + 1}`)}"><Say>${xml(reply)}</Say></Gather><Hangup/></Response>`);
  } catch (_) {
    await getFirestore().doc(`aiCalls/${req.query.id}`).update({ voiceError: true }).catch(() => {});
    res.send(end('The AI service is unavailable. This test call is ending.'));
  }
});

exports.aiCallStatus = onRequest({ secrets }, async (req, res) => {
  if (!authorized(req, 'aiCallStatus') || !/^[a-f0-9]{64}$/.test(req.query.id || '')) { res.sendStatus(403); return; }
  const allowed = new Set(['queued', 'initiated', 'ringing', 'in-progress', ...terminal]);
  if (!allowed.has(req.body.CallStatus)) { res.sendStatus(400); return; }
  const ref = getFirestore().doc(`aiCalls/${req.query.id}`);
  await getFirestore().runTransaction(async (tx) => {
    const current = await tx.get(ref);
    if (!current.exists || (current.get('sid') && current.get('sid') !== req.body.CallSid) || terminal.has(current.get('status'))) return;
    tx.update(ref, { status: req.body.CallStatus, updatedAt: new Date() });
  });
  res.sendStatus(204);
});
