# SafeHer design

The source of requirements is the supplied ten-page SafeHer PDF. The user authorized implementation on 2026-10-16.

Build a Flutter Android application using a violet/navy Material 3 theme and a red emergency action. Phase 1 provides onboarding, home, contacts, emergency history and settings, with an explicitly labelled local demonstration. Demonstration SOS must never imply a real notification or location transmission. A configurable countdown leads to an active demo event, which the sender can resolve or cancel. Contacts require separate friendship and mutual trusted consent.

Later phases add Firebase Authentication, Firestore, privileged Cloud Functions and FCM, then location/navigation, then visible consent-based WebRTC. Use feature boundaries so the local demonstration can be replaced by authenticated repositories. Never embed server credentials. Android shortcuts must be documented and tested on real devices before claiming support.

Validate countdown cancellation, duplicate activation protection, event resolution, and navigation through widget and state tests. Run formatter, analyzer, tests and Android compilation where the installed toolchain permits. Missing Firebase configuration must remain visible to the user.
