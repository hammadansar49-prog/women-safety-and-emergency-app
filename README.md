# SafeHer

Android women safety and emergency coordination FYP. Requirements: `SafeHer_FYP_Complete_Project_Specification_for_Codex.pdf`.

## Current implementation

Flutter (Android + web) app backed by Firebase:

- **Accounts:** Firebase Auth (email / Google), unique usernames (`usernames/`, Bloom-filter pre-check), profiles and PIN lock.
- **Social:** friend requests, end-to-end encrypted chat (photos, voice notes, shared places), read receipts, presence via Realtime Database.
- **Calls:** WebRTC audio/video with Firestore signaling.
- **SOS:** countdown, approved-favourite "SOS buddies", live location by movement, siren / spoken alert, FCM push through the `pushSosAlert` Cloud Function.
- **Backup:** client-side encrypted cloud backup (`backups/`).
- **Security rules:** `firestore.rules`, `database.rules.json`, `storage.rules` (storage deny-all), tested in `backend-tests/`.

## Run

Toolchain inspected: Flutter 3.41.9 / Dart 3.11.5. Android application ID: `com.safeher.safeher` (provisional).

```sh
flutter pub get
flutter run -d chrome
flutter run
```

Use Get started on onboarding. Android requires a configured SDK/JDK and a connected phone or emulator.

### Browser preview without installing the APK

Double-click `preview.cmd`, keep its terminal open, and visit **http://localhost:8080** once Flutter reports that the app is being served. Alternatively run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preview.ps1` from the project folder. To use another port, append `-Port 8081`.

The launcher builds and serves the web app using Python, so the in-app browser needs no debug extension. Keep the terminal open; Ctrl+C stops it. Rerun the launcher after code edits, then refresh your browser. Reopen it after restarting your computer. For Flutter development hot reload, append `-Development` (use Chrome with the Dart debug extension if required); `r` reloads and `R` restarts. This previews the same Flutter UI; Android background services, hardware shortcuts and push delivery still require physical-device testing.

Android background services, hardware shortcuts and push delivery still need real-device testing.

## Verification

```sh
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Controller tests cover duplicate activation, cancellation and resolution. The widget test covers onboarding and settings navigation. These tests do not verify real alerts or device permissions.

## Deploy backend

```sh
firebase deploy --only firestore,database,storage,functions
```

Rules tests: `cd backend-tests && npm install && npm test` (requires the Firebase emulators).
