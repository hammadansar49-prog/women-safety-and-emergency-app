# SafeHer

Android women safety and emergency coordination FYP. Requirements: `SafeHer_FYP_Complete_Project_Specification_for_Codex.pdf`.

## Current implementation

Phase 1 foundation: Material 3 onboarding, home, contacts explanation, activity and settings. A clearly labelled local demo supports configurable SOS countdown, cancellation, duplicate activation prevention and resolution. Activity is in memory only. No real alert, tracking, media or authentication is performed.

## Run

Toolchain inspected: Flutter 3.41.9 / Dart 3.11.5. Android application ID: `com.safeher.safeher` (provisional).

```sh
flutter pub get
flutter run -d chrome
flutter run
```

Use Explore demo on onboarding. Android requires a configured SDK/JDK and a connected phone or emulator.

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

- `dart format lib test`: completed; final run changed no files.
- `flutter analyze`: no issues found.
- `flutter test`: all 4 tests passed.
- `flutter build apk --debug`: succeeded, output `build/app/outputs/flutter-apk/app-debug.apk`.
- No physical Android device testing has been performed. Android doctor reports missing command-line tools despite this successful debug build.
