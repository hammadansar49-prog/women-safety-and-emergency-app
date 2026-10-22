# SafeHer backend plan (build order and status)

Status as of 2026-10-22. "Verified" means exercised against the live project
`safeher-cfb5a` with real accounts, not only unit tests.

## 0. Prerequisites (owner)
- Done: Authentication enabled (Email/Password). Google sign-in on Android still
  needs the SHA-1 of the signing key added to the Firebase Android app.
- Web app registered in Firebase, so localhost web builds use the real backend.
- Steps 3 (function) and 5 (push) need the Blaze plan.

## 1. Cloud account (data follows the user) - verified
- `backups/{uid}`: AES-GCM sealed snapshot; key wrapped by a recovery code.
- New device: login, enter the recovery code, everything returns (friends,
  chats, SOS permissions, chat identity key).

## 2. Cloud friends + end-to-end encrypted chat - verified
- `friendReqs`, `sosLinks`, `chats/{pair}/messages` with X25519 + HKDF + AES-GCM.
- 43 live rules checks (who can read/write/forge/edit what) pass.
- Two real accounts on two origins exchanged encrypted messages both ways.

## 3. Username Bloom filter - client done, function not deployed
- `lib/bloom_filter.dart` + live "available / taken" line on sign-up and on the
  username step. Hashing matches `functions/index.js` (shared test vector).
- `functions/index.js` fills `meta/usernames` on every new username. Needs
  `firebase deploy --only functions` on the Blaze plan. Without it the line
  still works, using the database check only.

## 4. SOS delivery - verified (app open)
- `sosAlerts/{event_recipient}`: start, live location points, ended state.
- Buddy's app showed the alert, moving location and the "resolved" end.
- Not done: delivery when the buddy's app is closed (needs push).

## 5. Push (FCM) - not built
- Needs Blaze (a function sends on `sosAlerts` create) plus token registration
  and a notification channel on Android. Test on a real phone.

## 6. SOS media - not built
- Foreground service (camera + microphone type, visible notification), clips to
  Storage, buddy-only read; buddy "speak" voice message. Real phones only.

## 7. Calls - not built
- WebRTC audio/video with Firestore signalling and STUN/TURN. Real phones only.
