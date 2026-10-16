# SafeHer foundation implementation plan

**Goal:** Deliver a runnable, honestly labelled Flutter demonstration foundation before connecting real emergency services.

**Architecture:** Material 3 screens share a local ChangeNotifier controller. The controller owns countdown and emergency transitions; screens render actual local state. Firebase integration follows as a separate phase.

**Tech stack:** Flutter, Dart, Android Kotlin host; Firebase/Auth/Firestore/Functions/FCM, location and WebRTC in subsequent phases.

- [x] Audit Flutter and Android tooling and generate Android/web host files using `flutter create --project-name safeher --org com.safeher --platforms android,web .`.
- [x] Add state tests for countdown cancellation, duplicate activation and resolution; run `flutter test` to establish failing behavior.
- [x] Implement controller and accessible Material UI: onboarding, home, contacts, activity and settings. Label all emergency simulations as tests with no outgoing alerts.
- [x] Run `dart format lib test`, `flutter analyze`, `flutter test`, and `flutter build apk --debug`; document exact failures if tooling is unavailable.
- [x] Write README with run instructions, phase status and Firebase configuration requirements.

## Remaining delivery sequence

Google sign-in/profile â†’ friend requests and mutual consent â†’ authorized SOS backend/FCM â†’ location/maps â†’ consent-based WebRTC â†’ supported native shortcuts â†’ security and real-device evaluation.
