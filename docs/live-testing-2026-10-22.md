# Live testing findings — 22 October 2026

User requirement: all users register in Firebase immediately; new profiles must be searchable, buddy requests and encrypted messages must arrive without refresh, visible chats must acknowledge reads, foreground presence must survive navigation, backgrounding must publish last seen. Add live typing, glowing mutual-chat presence, smooth voice waveform, functional camera and immediate audio/video setup screens. Install a verified new build on both test phones without deleting app data or caches.

## Confirmed evidence

- Android log at 14:44:59: Firestore WriteStream returned `RESOURCE_EXHAUSTED`, `Quota exceeded`. User confirmed Spark/free plan. A database-side quota block prevents honest end-to-end latency certification.
- Authenticated server lookup confirms both `anas` and `zz_phone_1022` have public profiles.
- `CloudSocial.start` waited on a profile network update before attaching all listeners.
- Social graph application waited for both SOS-link streams and every peer profile lookup before publishing incoming buddy requests.
- Old receipt snapshots could downgrade read to sent.
- Resume cleared the open conversation; background heartbeat could republish online.
- Call UI only adopted the session after native media and network setup finished; errors were silently discarded.
- Old queued ringing calls lacked expiry.
- Voice waveform only advanced on 120 ms amplitude ticks.
- Camera/photo actions were placeholders; the new path captures/selects, normalizes, seals and displays photos.
- Background push code contains SOS only, no chat/request/call handler. Firebase Functions deployment requires Blaze. Do not enable billing without user action.

## Implemented and verified

- Startup listeners no longer wait on identity upload or unrelated SOS/profile requests. Old session cleanup is bounded, and late profile key publication replays waiting messages.
- Receipts are monotonic, coalesced, and guarded across background/navigation. Repeated unresolved timestamp snapshots cannot trigger repeated successful receipt writes. Quota feedback was a code-supported risk; its contribution to the native quota incident is not directly measured.
- Presence and receipt notifications no longer rewrite the account snapshot or reschedule encrypted cloud backups. A regression first reproduced three saves instead of one; the fix and nine related persistence/search cases passed.
- The chat compares public usernames for reading presence; app navigation preserves online status, backgrounding stops online heartbeats, and resume retains the open conversation. Typing is throttled and expires; online dot glows when the buddy has this conversation open.
- Recording waveform interpolates real microphone samples between 120 ms input ticks with isolated frame repaint and reduced-motion support. Message rows have stable keys to preserve the correct voice player across insertion.
- Camera/gallery photos are bounded to 400 KB and 1280 pixels, metadata stripped, E2EE sealed, displayed with zoom, and restored when omitted from the bounded local media cache. Picker purpose/account guards prevent an interrupted chat photo becoming an avatar.
- Call UI appears before media/network setup, exposes failures/cancel, reconnects incoming listeners and expires old ringing calls. A fixed client expiry prevents delayed server timestamps reviving queued calls.
- Real Firebase signup remains atomic with a searchable profile; search explicitly queries the server. Quota signup failures no longer claim the username is taken.
- Full suite: 106 tests passed. After the final expiry change, 26 focused call/chat tests passed, including five new expiry tests. Ten focused persistence/search/transient-update tests passed after the backup scheduling fix. Final changed-file analyzer reported no issues; git diff --check passed.
- Firestore rules for photo, typing and call expiry compiled and deployed to safeher-cfb5a. Version is 1.0.1+2.

## Build and installation

- Release APK build succeeded with Kotlin 2.4.0 and R8 9.1.29 (757.2 seconds). Artifact: build/app/outputs/flutter-apk/app-release.apk, 58,772,944 bytes. apksigner verify passed. aapt reports com.safeher.safeher, versionCode 2, versionName 1.0.1.
- Installed with adb install -r on e7b3241b / CPH2473. Package manager confirms version 1.0.1 / code 2, lastUpdateTime 2026-10-22 16:17:16. No uninstall, clear-data or cache deletion.
- User prefers installing one phone at a time and explicitly deferred the second phone after the first installation. CPH2127 remains pending reconnection.
- Web release build succeeded (118.7 seconds) with SAFEHER_LOCAL=false. Root and main.dart.js both return HTTP 200 at http://127.0.0.1:8081/. Served JavaScript SHA-256 matches build/web/main.dart.js: 252F588523B26FD7F76637287968F337D7CC82F8711363AB597598E6646A3F1D.
- Updated browser tab visibly opens the existing testing1 conversation with zz_phone_1022, cached messages and call/camera controls. Browser console again confirms resource-exhausted / Quota exceeded at 11:20:27 and 11:21:50 UTC, followed by maximum backend backoff. UI shows a connection error. No new live delivery success is claimed.

## Remaining integration checks

Install on the second phone when reconnected and verify timing/read/audio/camera on hardware. Android release packaging initially failed inside AGP SDK-dependency metadata with missing Tink HybridConfig and then broken transform metadata. Original caches were preserved; a fresh Gradle home on D reuses copied dependency downloads. Final Dart source edits predate the generated release app.so.

Release packaging revealed the existing Kotlin 2.4 / AGP 8.11 R8 8.11.18 mismatch. A Kotlin 2.2.20 attempt failed specifically at firebase_auth:compileReleaseKotlin because Firebase Auth 25.0.0 requires 2.4 metadata. Kotlin therefore remains 2.4.0; settings now pins R8 9.1.29 using Google's documented pluginManagement/buildscript override (https://r8.googlesource.com/r8/+/refs/heads/main/README.md#replacing-r8-in-android-gradle-plugin), matching the Kotlin compatibility requirement (https://developer.android.com/build/kotlin-support?hl=en). No dependency cache was removed.

AGP 8.11 lint's embedded Kotlin reader still printed 2.4-versus-2.2 metadata diagnostics, but the release build completed successfully. Do not describe this as a clean Android lint run; the final Dart changed-file analyzer was clean.

Firestore quota exhaustion is an external blocker for honest end-to-end realtime/SOS certification. Background call/message/request push is still absent, and Firebase Functions needs Blaze for deployment. Authenticated TURN is required where strict carrier NAT prevents peer media. Database migration/billing changes remain deferred at the user's request. Do not call realtime/SOS fixed before two-device verification.

## No-cost architecture research

Recommendation under consideration: retain Firebase Auth and profile directory; use Realtime Database for volatile presence/typing and potentially chat/request/call/SOS transport. Requires explicit implementation scope and secure rules/migration plan, not a blind database swap.

- Firebase RTDB Spark: 100 simultaneous connections, 1 GB stored, 10 GB monthly downloads; server-side `onDisconnect` supports presence. https://firebase.google.com/pricing and https://firebase.google.com/docs/database/web/offline-capabilities
- Firestore free: 50,000 document reads/day, 20,000 writes/day, 1 GiB stored; quotas reset around midnight Pacific. https://cloud.google.com/firestore/pricing
- Supabase free: 200 realtime connections, 2 million realtime events/month, 500 MB database, 5 GB egress; inactivity pause after one week. https://supabase.com/pricing
- Database transport is separate from reliable Android background push and WebRTC media relay. Do not promise unlimited free operation or immediate alarm delivery from a database migration alone.
