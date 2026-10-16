# Firebase Implementation Plan

> Execute with superpowers:subagent-driven-development. User approved design 2026-10-16.

**Goal:** Connect SafeHer to its authorized Firebase project with authenticated, isolated accounts and tested rules.
**Architecture:** FlutterFire auth gate and cloud repository; Firestore participant-based social documents; Storage owner uploads; callable SOS server plus FCM. Local preview data stays local.
**Tech stack:** Flutter, Firebase Auth/Firestore/Storage/Functions/Messaging, Node rule tests and emulator.

- [ ] Provision Android/Web app registrations, inspect Auth, billing and database, enable required free APIs, record non-secret Firebase options. Retain all unrelated projects.
- [ ] Implement and test Firestore/Storage rules and server SOS endpoint. Canonical schema documented alongside rules; emulator tests deny cross-account actions and duplicate usernames.
- [ ] Implement Flutter auth gate, unique username transaction, account-scoped streams, friends/chat/consent and profile photo persistence. Add tests before changing account boundaries. Keep unavailable delivery states explicit.
- [ ] Configure providers, deploy tested rules/functions where account services permit, and verify actual Google sign-in via user-controlled browser authentication.
- [ ] Run analyzer, relevant/full Flutter tests, emulator tests and release web build. Inspect actual localhost. Commit/push verified changes and report external blockers exactly.

Use separate owners for backend rules/server files and Flutter client files. Root handles cloud provisioning and integration review. Coordinate schema before edits. Test anonymous access, account isolation, username claim atomicity, request recipient-only acceptance and message spoofing before rule deployment. Never bypass failing rules by opening access.
