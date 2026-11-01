// SafeHer cloud functions. Deploying them needs the Blaze plan.
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp();

// --- Username Bloom filter --------------------------------------------------
// Same hashing as lib/bloom_filter.dart: FNV-1a (32 bit) over UTF-8 with two
// seeds, position i = (h1 + i * h2) mod m.
const BITS = 1 << 20; // 1,048,576 bits = 128 KB, good for ~80k names at <1% misses
const K = 7;

function fnv(bytes, seed) {
  let h = seed >>> 0;
  for (const b of bytes) {
    h = (h ^ b) >>> 0;
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h;
}

function positions(name) {
  const bytes = Buffer.from(name, 'utf8');
  const h1 = fnv(bytes, 0x811c9dc5);
  const h2 = (fnv(bytes, 0x9747b28c) | 1) >>> 0;
  const out = [];
  for (let i = 0; i < K; i++) out.push((h1 + i * h2) % BITS);
  return out;
}

// Every new reserved username is added to meta/usernames. Clients read that one
// document and use it only as a hint; the sign-up transaction stays the judge.
exports.addUsernameToFilter = onDocumentCreated('usernames/{name}', async (event) => {
  const db = getFirestore();
  const ref = db.doc('meta/usernames');
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const bits = snap.exists
      ? Buffer.from(snap.get('bits'), 'base64')
      : Buffer.alloc(BITS / 8);
    for (const p of positions(event.params.name)) bits[p >> 3] |= 1 << (p & 7);
    tx.set(ref, {
      bits: bits.toString('base64'),
      k: K,
      count: (snap.get('count') || 0) + 1,
      updatedAt: new Date().toISOString(),
    });
  });
});

// --- SOS push -----------------------------------------------------------------
// When an alert is created for a buddy, wake their phone. The notification
// carries no location; the app fetches that itself once opened.
const { getMessaging } = require('firebase-admin/messaging');

// Errors that are worth trying again; anything else would fail the same way.
const TRANSIENT = new Set([
  'messaging/internal-error',
  'messaging/server-unavailable',
  'messaging/quota-exceeded',
  'messaging/unavailable',
]);

// retry: a transient failure rethrows so Cloud Functions runs this again. An
// SOS that silently never arrives is the worst outcome this app can have.
exports.pushSosAlert = onDocumentCreated(
  { document: 'sosAlerts/{id}', retry: true },
  async (event) => {
    const alert = event.data && event.data.data();
    if (!alert || alert.status !== 'active' || alert.pushedAt) return;
    // A retried event older than 10 minutes is no longer useful as a wake-up.
    if (Date.now() - Date.parse(event.time) > 10 * 60 * 1000) return;
    const db = getFirestore();
    // Every phone of the recipient, plus the legacy single-token document.
    const [legacy, devices] = await Promise.all([
      db.doc(`pushTokens/${alert.recipient}`).get(),
      db.collection(`pushTokens/${alert.recipient}/devices`).get(),
    ]);
    const targets = devices.docs.map((d) => ({ ref: d.ref, token: d.get('token') }));
    if (legacy.exists && legacy.get('token')) {
      targets.push({ ref: legacy.ref, token: legacy.get('token') });
    }
    if (!targets.length) return;
    let delivered = 0;
    let transient = null;
    await Promise.all(targets.map(async ({ ref, token }) => {
      try {
        await getMessaging().send({
          token,
          notification: {
            title: `${alert.sender} needs help`,
            body: 'Tap to see their live location.',
          },
          data: { type: 'sos', eventId: String(alert.eventId) },
          android: { priority: 'high', ttl: 600000, notification: { channelId: 'sos_alerts' } },
        });
        delivered++;
      } catch (e) {
        // A dead token is removed so it is not tried again.
        if (e.code === 'messaging/registration-token-not-registered') {
          await ref.delete();
        } else if (TRANSIENT.has(e.code)) {
          transient = e;
        } else {
          console.error('SOS push failed', alert.eventId, e.code || e);
        }
      }
    }));
    if (delivered) {
      // Recorded server side only, so the sender can see it reached FCM.
      await event.data.ref.update({ pushedAt: new Date().toISOString() });
    } else if (transient) {
      throw transient;
    }
  },
);
