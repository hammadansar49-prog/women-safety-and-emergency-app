// Security-rules tests for the current schema. Run with the emulators:
//   firebase emulators:exec --only firestore,storage --project demo-safeher "cd backend-tests && npm test"
import { before, after, beforeEach, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment, assertFails, assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc, setDoc, getDoc, updateDoc, deleteDoc, serverTimestamp, collection, getDocs,
} from 'firebase/firestore';
import { ref, uploadBytes } from 'firebase/storage';

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-safeher',
    firestore: { host: '127.0.0.1', port: 8180, rules: readFileSync('../firestore.rules', 'utf8') },
    storage: { host: '127.0.0.1', port: 9199, rules: readFileSync('../storage.rules', 'utf8') },
  });
});
after(async () => env.cleanup());
beforeEach(async () => {
  await env.clearFirestore();
  // uid "u_<name>" owns username "<name>".
  for (const n of ['alice', 'bob', 'eve']) {
    await seed(`users/u_${n}`, { username: n });
    await seed(`profiles/${n}`, { uid: `u_${n}`, username: n, name: n, pub: '' });
  }
});

const db = (name) => env.authenticatedContext(`u_${name}`).firestore();
const anon = () => env.unauthenticatedContext().firestore();
const seed = (path, data) =>
  env.withSecurityRulesDisabled((c) => setDoc(doc(c.firestore(), path), data));
const friends = () =>
  seed('friendReqs/alice__bob', { from: 'alice', to: 'bob', status: 'accepted', createdAt: 1 });
const approved = () =>
  seed('sosLinks/alice__bob', { from: 'alice', to: 'bob', status: 'approved' });

test('usernames: claim own valid name once; no listing, no takeover', async () => {
  const a = env.authenticatedContext('u_new').firestore();
  await assertSucceeds(setDoc(doc(a, 'usernames/newbie'), { uid: 'u_new', email: 'x@y.z', createdAt: 1 }));
  await assertFails(setDoc(doc(a, 'usernames/Bad!'), { uid: 'u_new' }));
  await assertFails(setDoc(doc(db('eve'), 'usernames/spoof'), { uid: 'u_alice' }));
  await assertFails(updateDoc(doc(a, 'usernames/newbie'), { uid: 'u_eve' }));
  await assertFails(getDocs(collection(a, 'usernames')));
});

test('profiles: signed-in get only; owner edits name/pub only', async () => {
  await assertSucceeds(getDoc(doc(db('bob'), 'profiles/alice')));
  await assertFails(getDoc(doc(anon(), 'profiles/alice')));
  await assertSucceeds(updateDoc(doc(db('alice'), 'profiles/alice'), { name: 'Alice' }));
  await assertFails(updateDoc(doc(db('eve'), 'profiles/alice'), { name: 'pwned' }));
  await assertFails(updateDoc(doc(db('alice'), 'profiles/alice'), { uid: 'u_eve' }));
});

test('friend requests: only recipient accepts; strangers cannot read', async () => {
  await assertSucceeds(setDoc(doc(db('alice'), 'friendReqs/alice__bob'),
    { from: 'alice', to: 'bob', status: 'pending', createdAt: 1 }));
  await assertFails(setDoc(doc(db('eve'), 'friendReqs/alice__eve'),
    { from: 'alice', to: 'eve', status: 'pending', createdAt: 1 }));
  await assertFails(updateDoc(doc(db('alice'), 'friendReqs/alice__bob'), { status: 'accepted' }));
  await assertFails(getDoc(doc(db('eve'), 'friendReqs/alice__bob')));
  await assertSucceeds(updateDoc(doc(db('bob'), 'friendReqs/alice__bob'), { status: 'accepted' }));
});

test('chat: friends only, ciphertext immutable', async () => {
  const msg = { from: 'alice', to: 'bob', ct: 'sealed', createdAt: serverTimestamp() };
  await assertFails(setDoc(doc(db('alice'), 'chats/alice__bob/messages/m1'), msg));
  await friends();
  await assertSucceeds(setDoc(doc(db('alice'), 'chats/alice__bob/messages/m1'), msg));
  await assertFails(setDoc(doc(db('eve'), 'chats/alice__bob/messages/m2'), { ...msg, from: 'eve' }));
  await assertFails(getDoc(doc(db('eve'), 'chats/alice__bob/messages/m1')));
  await assertFails(updateDoc(doc(db('bob'), 'chats/alice__bob/messages/m1'), { ct: 'changed' }));
  await assertSucceeds(updateDoc(doc(db('bob'), 'chats/alice__bob/messages/m1'), { readAt: 1 }));
});

test('SOS: alert only to an approved buddy; recipient cannot alter it', async () => {
  const alert = { sender: 'alice', recipient: 'bob', eventId: 'e1', status: 'active', createdAt: 1 };
  await friends();
  await assertFails(setDoc(doc(db('alice'), 'sosAlerts/e1_bob'), alert));
  await assertSucceeds(setDoc(doc(db('alice'), 'sosLinks/alice__bob'), { from: 'alice', to: 'bob', status: 'pending' }));
  await assertFails(updateDoc(doc(db('alice'), 'sosLinks/alice__bob'), { status: 'approved' }));
  await assertSucceeds(updateDoc(doc(db('bob'), 'sosLinks/alice__bob'), { status: 'approved' }));
  await assertSucceeds(setDoc(doc(db('alice'), 'sosAlerts/e1_bob'), alert));
  await assertSucceeds(getDoc(doc(db('bob'), 'sosAlerts/e1_bob')));
  await assertFails(getDoc(doc(db('eve'), 'sosAlerts/e1_bob')));
  await assertFails(updateDoc(doc(db('bob'), 'sosAlerts/e1_bob'), { status: 'resolved' }));
  // The buddy may answer, and only with an allowed answer.
  await assertSucceeds(updateDoc(doc(db('bob'), 'sosAlerts/e1_bob'), { response: 'coming', respondedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db('bob'), 'sosAlerts/e1_bob'), { response: 'lol', respondedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(db('eve'), 'sosAlerts/e1_bob'), { response: 'seen', respondedAt: serverTimestamp() }));
  await assertSucceeds(updateDoc(doc(db('alice'), 'sosAlerts/e1_bob'), { status: 'resolved' }));
  await assertFails(updateDoc(doc(db('alice'), 'sosAlerts/e1_bob'), { status: 'active' }));
});

test('trips: only to an approved buddy, visible to the pair only', async () => {
  const t = { sender: 'alice', recipient: 'bob', until: '2099-01-01T00:00:00Z' };
  await assertFails(setDoc(doc(db('alice'), 'trips/alice__bob'), t));
  await approved();
  await assertSucceeds(setDoc(doc(db('alice'), 'trips/alice__bob'), t));
  await assertSucceeds(setDoc(doc(db('alice'), 'trips/alice__bob'), { ...t, lat: 1, lng: 2, locAt: 'x' }));
  await assertSucceeds(getDoc(doc(db('bob'), 'trips/alice__bob')));
  await assertFails(getDoc(doc(db('eve'), 'trips/alice__bob')));
  await assertFails(setDoc(doc(db('eve'), 'trips/eve__bob'), { ...t, sender: 'eve' }));
  await assertSucceeds(deleteDoc(doc(db('alice'), 'trips/alice__bob')));
});

test('SOS medical info is size-limited', async () => {
  await approved();
  const alert = { sender: 'alice', recipient: 'bob', eventId: 'e2', status: 'active', createdAt: 1 };
  await assertSucceeds(setDoc(doc(db('alice'), 'sosAlerts/e2_bob'), { ...alert, medical: 'Blood group O+' }));
  await assertFails(setDoc(doc(db('alice'), 'sosAlerts/e3_bob'), { ...alert, eventId: 'e3', medical: 'x'.repeat(401) }));
});

test('push tokens: per-device docs writable by owner only, never readable', async () => {
  const dev = 'pushTokens/alice/devices/0123456789abcdef0123456789abcdef';
  const t = { token: 'tok', platform: 'android', updatedAt: 1 };
  await assertSucceeds(setDoc(doc(db('alice'), dev), t));
  await assertFails(setDoc(doc(db('eve'), dev), t));
  await assertFails(setDoc(doc(db('alice'), 'pushTokens/alice/devices/NOT-A-HASH'), t));
  await assertFails(getDoc(doc(db('alice'), dev)));
  await assertSucceeds(deleteDoc(doc(db('alice'), dev)));
});

test('unknown collections and storage are denied', async () => {
  await approved();
  await assertFails(setDoc(doc(db('alice'), 'anything/x'), { a: 1 }));
  const st = env.authenticatedContext('u_alice').storage();
  await assertFails(uploadBytes(ref(st, 'avatars/alice'), new Uint8Array([1])));
});
