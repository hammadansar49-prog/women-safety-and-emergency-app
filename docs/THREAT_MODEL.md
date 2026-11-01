# SafeHer threat model

| # | Threat | Impact | Mitigation now | Still to do |
|---|--------|--------|----------------|-------------|
| 1 | Attacker watches/grabs the phone during SOS | SOS cancelled, user harmed | Silent SOS (no screen, no countdown); hidden cancel gesture; PIN lock | Duress PIN that "unlocks" but keeps SOS live |
| 2 | No internet / push not delivered | Buddies never learn of SOS | FCM high priority + retries + TTL; multi-device tokens; SMS fallback; one-tap helplines | Automatic SMS via a server SMS gateway; delivery acknowledgements from buddy phones |
| 3 | Stranger tracks a user's location | Stalking | Location only goes to buddies who approved (`sosLinks`), enforced in rules | Expire old SOS locations automatically (TTL policy) |
| 4 | Fake SOS spam to a buddy | Harassment, alarm fatigue | Rules: sender must be approved by recipient; recipient can revoke | Server-side rate limit per sender |
| 5 | Account takeover | Impersonation, read chats | Firebase Auth; E2E chat keys on device; backup needs recovery code | Firebase App Check; 2-step verification |
| 6 | Server / Firebase admin reads chats | Privacy | End-to-end encryption; backup sealed on device | — |
| 7 | Username enumeration | Targeting users | `usernames` list denied; profile search capped at 10 | Rate-limit lookups via App Check |
| 8 | Abuse of backend by scripts (not the app) | Cost, spam | Rules validation, size limits | Enforce App Check on Firestore, RTDB, Functions |
| 9 | Expensive rule lookups (`me()` reads `users/{uid}` each time) | Cost/latency | Accepted for FYP scale | Put username in an Auth custom claim set by a Cloud Function |

## Enabling App Check (manual, console + code)

1. Firebase console → App Check → register the Android app with **Play Integrity** (needs the release SHA-256 from your signing key).
2. Add `firebase_app_check` to `pubspec.yaml` and call `FirebaseAppCheck.instance.activate(...)` right after `Firebase.initializeApp`, using the debug provider in debug builds.
3. Watch the metrics for a week, then press **Enforce** for Firestore, Realtime Database and Functions.
