# Automatic SOS AI test calls

Implemented in the SafeHer Firebase functions, rather than the separate website starter: the app's existing SOS writes automatically trigger the backend, without an extra tap. Only server-enrolled consenting testers are eligible. Existing buddy approval is still required to create SOS alerts. This is a test-number prototype, not operational emergency dispatch.

## Owner setup

1. Use a Firebase project with billing and permission to deploy Cloud Functions. Install dependencies in `functions` with `npm install`.
2. Obtain a Twilio account, an outbound-capable provider number and a consenting test recipient's full international number. Enable the destination geography; trial accounts may require verified recipients. Never configure an emergency-service destination as the test number.
3. Run `firebase functions:secrets:set TWILIO_ACCOUNT_SID`, `firebase functions:secrets:set TWILIO_AUTH_TOKEN`, and `firebase functions:secrets:set OPENAI_API_KEY`. Enter secrets in the terminal, not in chat or Git.
4. Copy `functions/.env.example` to the Firebase project-specific environment file. Set the full test number, provider number, comma-separated SafeHer tester usernames, an available OpenAI text model ID, and the deployed function URL base. Leave mode disabled until all values are checked.
5. Deploy Firestore rules and functions. Set `AI_CALL_MODE=test` and redeploy when the consenting tester is ready. The first eligible new SOS calls the configured test number automatically.
6. Answer the test call, ask about the location, end the SOS, and verify call termination and app status on physical devices. Validate busy/no-answer, denied GPS, canceled countdown, repeated events and provider downtime. Do not test against 15.

## What runs

GPS preparation starts during the existing SOS countdown, without an additional calling delay. A cached fix no older than two minutes and a fresh fix are requested concurrently; the newer valid result wins. If ready at activation, coordinates and timestamp are included in the initial Firebase alert before the call trigger. Otherwise the call proceeds with location unavailable, and subsequent GPS updates are read at each voice turn. This is best-effort, not a one-second GPS guarantee. Setup location permission before testing. Position accuracy is not yet included in the alert schema.

The first alert for a sender/event claims one server-only call record transactionally. A global cap permits at most three attempts/hour. Events over two minutes old are not called. A failed/ambiguous submission is never automatically retried, to avoid duplicate telephone calls. A provider timeout can mean the call exists even when status says unknown; check the provider console before retrying anything.

Twilio speaks a test introduction, captures the tester's question with speech recognition, sends the text and current GPS facts to OpenAI, and speaks the reply. This first version uses English speech recognition/TTS, six turns maximum and a three-minute call cap. It is turn-based, not a simultaneous realtime audio bridge. Only the current question is sent; conversational history is not stored. The model cannot execute actions.

Provider webhooks require Twilio HMAC signatures; status is scoped to the sender in Firestore. GPS is device-reported, timestamped and may be stale. Missing coordinates are explicitly unknown. No address/geocoding or name/phone inference is performed. Status `completed` means the provider ended the call, not that help was sent. Raw operator speech is sent to the AI provider; obtain tester consent to this data processing.

## Still required

- Real credentials, deployment, funded provider account and end-to-end physical-device tests. No live call was made during development.
- Provider/authority agreement and supported routing for Pakistan 15. Production/emergency mode is intentionally rejected by code; it needs a separately reviewed integration.
- Urdu speech recognition and synthesis verification with the selected provider.
- Optional user-to-call audio bridging with prior consent and platform support. This code does not transmit the phone microphone to the tester or police. Existing buddy media remains separately consented.
- Durable worker/reconciliation for abandoned requesting/unknown states, stronger per-user abuse controls, operational monitoring and security review before production. Cancellation attempts terminate known calls; a crash or provider outage may delay termination until the hard call limit.

References: https://www.twilio.com/docs/voice/twiml/gather and https://developers.openai.com/api/reference/resources/responses/methods/create
