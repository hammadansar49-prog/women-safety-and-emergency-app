# SafeHer code review — 2026-10-16

Reviewed application commit `2fec7bb`, all Dart application/tests, Android build/manifest/Kotlin host, web host, dependencies and project documentation against the supplied specification. An independent reviewer also inspected the source. This is an early Phase 1 local demonstration, not the completed FYP.

## Findings and priorities

1. **Medium: emergency status disappears on other tabs.** `lib/main.dart:69–72` selects tab content while the controller keeps running; cancel/resolve controls only exist in Home (`lib/main.dart:224–234`). Reproduced in the localhost browser: start SOS, switch to Contacts, return Home after the countdown; the event is active, but Contacts showed no active status or stop control. Add a persistent active/countdown banner with a return/cancel action before connecting real emergencies.
2. **Low: configuration copy overstates readiness.** `lib/main.dart:239–245` and `325–327` suggest Firebase configuration enables contacts, notifications and location. `pubspec.yaml:30–38` contains no integration dependencies and there are no backend functions/rules. These features need implementation plus configuration. README now explicitly clarifies this; product copy still needs revision.
3. **Release blocker, acceptable for demo:** `android/app/build.gradle.kts:35–39` uses debug signing for release builds. Production signing must be configured before publishing. The main Android manifest has no network/location/notification/media permission declarations or native services; those belong to the later implementation phases.
4. **Persistence and audit gap:** `lib/emergency_controller.dart:7–10,35–39` holds mutable state and plain history strings in memory. Restart clears onboarding, countdown preference and history; history lacks event IDs/timestamps. This is documented demo behavior, but insufficient for the full specification. Introduce typed events, timestamped history, settings persistence and authenticated storage when implementing the backend.
5. **Maintainability:** all screen rendering lives in `lib/main.dart`. Split screens and repository interfaces before adding integrations. The current controller is suitable for a local simulation, not server authorization or delivery tracking.

The original three controller tests called `tick()` directly, and the original widget test only covered onboarding/settings. This review adds widget tests using elapsed fake time for selected-duration automatic activation, resolution/history, and cancellation past the original deadline. These tests exercise the actual periodic timer, not real device background behavior.

## Implemented versus pending

| Area | Actual state |
| --- | --- |
| Flutter Android/web project | Implemented; debug Android build previously succeeded |
| Onboarding and navigation | Implemented, local demo entry only |
| Home / SOS | Local countdown, duplicate start prevention, activation, cancellation and resolution |
| Countdown settings | 3/5/10 seconds, memory only |
| Activity | In-memory demo outcomes without timestamps |
| Contacts screen | Static explanation and empty state only |
| Google login, profiles, usernames | Not implemented |
| Friend requests, mutual trusted consent/revocation | Not implemented |
| SOS backend, FCM, recipient alert screen | Not implemented |
| Firestore rules / authorization / rate limiting | Not implemented |
| Location, accuracy/staleness, maps/directions | Not implemented |
| WebRTC / signaling / TURN / media consent | Not implemented |
| Permissions, foreground services, native shortcuts | Not implemented |
| Offline retries and persisted event state | Not implemented |
| Account deletion, retention, block/report | Not implemented |
| Real-device / two-user / backend security evaluation | Not performed |

## Local preview

Run `preview.cmd` or `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/preview.ps1`, then open http://localhost:8080. Keep the terminal open. This serves the same Flutter application and avoids repeated APK installation for UI review. The server is local to this computer and must be started again after shutdown. Phone-only capabilities still need Android tests.

## Recommended next sequence

Fix persistent emergency visibility and misleading readiness copy; separate screens/state; implement Google authentication and profiles; implement friend/trusted consent with backend access rules; implement SOS/FCM; then location/maps and visible media. Validate each phase with emulator/rules tests and two real Android devices before claiming real emergency delivery.
