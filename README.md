# SafeHer

Android women safety and emergency coordination FYP. Requirements: `SafeHer_FYP_Complete_Project_Specification_for_Codex.pdf`.

## Current implementation

Material 3 onboarding, home, friends/chat, activity and settings. The local preview now supports sending/accepting/declining/cancelling friend requests, two-way messages between demo profiles, audio/video call preview screens, and favorite SOS contacts selected by a deliberate 1.5-second hold (or accessible options menu). SOS requires recipient approval and goes only to approved favorites. Requests, messages, preferences, profile photos and activity are saved in a local Hive database; there is no real network delivery, authentication, live media or tracking yet. The user has deferred Firebase integration.

### Try the current interface

Choose **Get started**, select a unique username, and open Contacts to search `ayesha` or `sara` and send a local friend request. The avatar opens Profile; Settings opens appearance and SOS preferences. System appearance follows device brightness; Light/Dark overrides are saved on this device.

The account-switching dropdown has been removed for the product interface. Two-sided acceptance, chat, consent and recipient routing are covered by controller/widget tests until real authentication and separate devices are connected. Holding an accepted friend for **1.5 seconds** opens favorite SOS options. A separate recipient approval is required before SOS can start. Removing favorites or revoking consent removes recipient access; SOS cancellation remains available inside chat and profile.

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

Firebase-backed functionality is not implemented yet; supplying credentials alone will not enable live delivery. Call screens explicitly remain previews with inactive camera/microphone. The next phases require both code and project configuration.

## Verification

```sh
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Controller tests cover duplicate activation, cancellation and resolution. The widget test covers onboarding and settings navigation. These tests do not verify real alerts or device permissions.

## Next implementation phases

1. Firebase Authentication and profiles, including username uniqueness, sign-out and account deletion.
2. Friend requests and separate mutual trusted-contact consent with authorization tests.
3. Privileged Cloud Functions for idempotent SOS and FCM notifications; deny-by-default Firestore rules.
4. Permission-aware location, freshness indicators and map navigation.
5. Visible, consent-based WebRTC sessions with authenticated signaling.
6. Real-device shortcut research, security checks and FYP documentation.

## Owner configuration required

Create a Firebase project and configure Android app `com.safeher.safeher`, Google sign-in and Android SHA fingerprints. Enable Authentication, Firestore, Cloud Functions and Cloud Messaging, then generate client options with FlutterFire. Do not place service-account keys in the app. Configure restricted Maps keys only if embedding Maps; navigation intents are an alternative. TURN credentials are needed for reliable WebRTC relay. Physical sender and recipient devices are needed for end-to-end testing.

Android doctor currently reports missing SDK command-line tools. No Android phone was connected during the initial audit. Background camera/microphone startup and universal power-button shortcuts must not be promised. Notification processing is distinct from confirmed delivery.

## Initial verification results (2026-10-16)

Friends/chat follow-up: `flutter analyze` clean; all **24 tests passed**; `flutter build web` succeeded. Browser verification exercised friend-request acceptance, a local chat message and the video-call preview. Automated tests verify exact 1.5-second hold timing, favorite-only routing, approval revocation, sender identity, and SOS cancellation from chat. These are local simulations, not live service tests. The previously built APK below predates this follow-up; use localhost for the current UI.

- `dart format lib test`: completed; final run changed no files.
- `flutter analyze`: no issues found.
- `flutter test`: all 4 tests passed.
- `flutter build apk --debug`: succeeded, output `build/app/outputs/flutter-apk/app-debug.apk`.
- No physical Android device testing has been performed. Android doctor reports missing command-line tools despite this successful debug build.

## Product presentation

The header avatar opens Profile (saved username, Google email connection status, and local logout). Settings contains appearance and SOS preferences. Appearance defaults to System and follows OS brightness, with explicit Light/Dark overrides. Logout returns to onboarding and is unavailable during an SOS; Google sign-out will be wired with authentication. Theme selection is saved on this device. The old local account-switch dropdown has been removed from the product UI; controller tests still exercise multiple account flows.

First entry now asks for a unique username before Home. Usernames are normalized to lowercase, use 3–20 letters/digits/underscores, and are checked again when saved. Friends search finds the saved username; existing configured accounts skip setup. The 26-test suite covers duplicate rejection, normalization, invalid names, setup and search-to-request behavior.

Google sign-in and global username reservation are not connected. Local accounts survive refresh and logout on the same device/browser origin. Firebase integration must atomically reserve `usernames/{normalizedUsername}` for the authenticated UID together with the user profile. Security rules/server validation must prevent overwrites and impersonation; a client-side availability check alone is insufficient.

The UI uses normal SafeHer branding without Demo or Preview labels. Profile is separate from Settings; the local account-switching selector is no longer shown. The backend remains disconnected: calls show Unable to connect, SOS delivery is marked not delivered, and message status states that no connection exists. Networking remains disconnected; local persistence is now implemented.

## Local data and profile photos

Tap the animated profile photo circle to open a centered Upload photo dialog. Once a photo exists, the same circle offers Change photo and Remove photo. Upload/Change opens the device gallery/file picker, followed by a crop screen with drag, pinch/slider zoom, circular preview, Reset, Save photo and Cancel. Confirmed crops are square; cancelling preserves the previous photo. Images are automatically resized to a maximum 512px edge while preserving aspect ratio, then saved as the smaller of high-quality JPEG (quality 92, full chroma) and PNG. Transparent images remain PNG. There is no arbitrary 10 MB rejection. The original photo remains unchanged; the optimized bytes are saved, not a temporary picker path. Unsupported/corrupt images or device resource/storage failures still report actionable errors. Android lost-picker data is recovered at startup. Android and web are the current targets; no physical-phone verification has been performed.

Every social-state change queues an ordered database write. Saving errors show a Retry action; logout waits for writes. Startup loads the database before rendering the account and refuses to silently overwrite unreadable data. Logout preserves the account and returns to onboarding; this is not authenticated sign-in yet. Active local SOS records recover their stop controls after restart; a countdown interrupted before activation is not resumed.

Data is local, not a cloud backup or end-to-end encrypted service. Clearing app/site data, uninstalling, private browsing expiry, or browser storage eviction can remove it. Another device/browser/origin has separate storage. Production integration requires Firebase Auth UID-scoped Firestore data and Cloud Storage photos, with authorization rules and sync.

## Configurable SOS button shortcut

Settings saves Volume Up or Volume Down as the preferred double-press key. In the native Android app, Test shortcut listens for two short releases within 600ms without sending SOS. A successful test allows Enable shortcut; changing the key or restarting requires another test. The selected key replaces normal volume adjustment only while enabled/test mode in the visible, unlocked app. It starts the configured SOS countdown and still requires approved favorite contacts. Logout disables it.

Power combinations, lock-screen/background activation and automatic background permission grants are not implemented. Browser settings allow preference selection only and explicitly state Android is required for testing/enabling. Native hardware reliability requires physical-device verification; a foreground test is not evidence of background support.
