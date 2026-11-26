# SafeHer handoff - 26 November 2026

## Current work

Active branch: `ai-agent-branch`. Main has not been merged or modified by this work.

- Emergency dialer (`tel:15`) with manual fallback; no automatic SIM call or AI audio injection.
- Explicit camera/microphone consent and stop-sharing controls for approved buddies.
- GPS preparation during the SOS countdown. Recent cached coordinates (maximum two minutes old) and fresh GPS are requested concurrently. Available coordinates/timestamp are included in the initial alert; unavailable GPS does not delay calling. Later updates feed subsequent AI turns. No one-second accuracy or delivery guarantee.
- Firebase automatic TEST-number calling, server-side tester enrollment, incident deduplication, three-attempt hourly global cap, signed provider callbacks and cancellation attempts.
- Turn-based Twilio speech recognition / OpenAI responses / Twilio speech output. English prototype; six turns and three minutes maximum. No conversation history, real police routing, address geocoding or user-to-operator audio bridge.
- App call status and failure display; provider completion does not mean police dispatch.
- FYP PDF for Nimra Zainab with mobile preview screenshots and device frames: `output/pdf/SafeHer_FYP_Nimra_Zainab.pdf`. Report reflects the earlier 70% design milestone, not a certification of the new calling implementation. PDF generation/capture sources and screenshots are under `tmp/pdfs`.

## Resume here: owner setup

1. Finish creating the Twilio account. Obtain an outbound voice number and confirm destination/country availability. Use a consenting personal TEST number, never 15 for testing.
2. Set up OpenAI API billing and a model available to the account.
3. Confirm the existing Firebase project and billing/Blaze deployment access.
4. Follow `docs/ai-calling-setup.md`. Store Twilio SID/token and OpenAI key via Firebase secrets. Do not paste secrets into chat, commit them, or put them in Flutter code.
5. Configure `AI_TEST_NUMBER`, `TWILIO_FROM_NUMBER`, `AI_TEST_SENDERS`, `AI_WEBHOOK_BASE`, `AI_CHAT_MODEL`; leave `AI_CALL_MODE=disabled` until ready. Use `test` only for controlled verification.
6. Deploy rules/functions and install a freshly built debug APK. Existing approved-buddy consent is required for SOS. Enable device location permissions.
7. Test two physical devices and a consenting telephone recipient: normal SOS, GPS unavailable/stale, cancellation, call busy/no-answer, AI failure, duplicate events, account changes and provider outage. No live call was made during coding.

## Remaining engineering / review

- Provider/authority-approved Pakistan 15 routing. Production mode is deliberately rejected; do not bypass it by using an emergency number as a test destination.
- Prior consent/enrollment UI for future production automatic calling and related data processing. Current enrollment is a server-managed test username list.
- Urdu speech recognition/TTS verification and conversational context if needed.
- Optional consented user audio bridge; current buddy media is not connected to telephone calls.
- Add GPS accuracy to the data schema and consider trusted reverse-geocoding. Device location is not independently verified.
- Durable queue/reconciliation for abandoned requesting/unknown calls; monitor cancellation failures, ambiguous provider timeouts and out-of-order events. No automatic retry after ambiguous submission.
- Broader integration tests with Firebase emulators and mocked provider/model calls: fanout deduplication, quotas, cancellation races, restart recovery and status authorization. Existing unit checks are not end-to-end assurance.
- Review per-user abuse controls, access rules, privacy/retention, monitoring and deployment environment before production.
- Remove the remaining `curly_braces_in_flow_control_structures` formatting info in the tracking callback in `lib/main.dart`. Existing unrelated auth/test analyzer warnings were observed earlier.
- Update the FYP report after actual integration/device verification; it currently documents the previous presentation milestone.

## Verification performed

- Six Node policy/webhook unit tests passed (`node --test functions/ai-policy.test.js functions/ai-webhook.test.js`).
- Emergency dialer/widget checks passed; most recent GPS freshness + widget run: three tests passed.
- Latest debug APK build succeeded. Generated APK/build directories are ignored by Git; rebuild with `flutter build apk --debug`.
- No provider calls, production deployment, police contact, live Firebase delivery or physical-device tests were performed.

## Other repositories

- `D:\HAMMAD PROJECTS\agent-starter`: original starter checked out on `ai-agent-branch`; no SafeHer-specific edits. Browser chat/voice reference only. Actual automatic calling implementation is in this SafeHer repo's `functions` directory.
- `D:\HAMMAD PROJECTS\receptionist`: original dental reference on `ai-agent-branch`, superseded by starter and retained unchanged.
- Both reference remotes belong to `ChestPiece`; pushing depends on GitHub write permission. Do not claim those branches are published without successful push output.
- Direct pushes to both ChestPiece remotes returned 403 for the signed-in account. Reference snapshots are instead being published to the owner's SafeHer remote as `ai-agent-starter-reference` and `dental-receptionist-reference`, retaining their original histories separately from the app branch.
