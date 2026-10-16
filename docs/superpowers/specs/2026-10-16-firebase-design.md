# SafeHer Firebase integration design

## Verified target

Firebase CLI is authenticated as theottdeals49@gmail.com. Project safeher-cfb5a, number 794636415951, is ACTIVE. No Firebase apps are registered. Existing Android application ID is com.safeher.safeher. Current application uses a local Hive account and seeded social records, without authentication or network delivery.

## Approach

Use Firebase Authentication, Firestore, Cloud Storage and server-side Functions/FCM. Prefer Firestore over Realtime Database for transactional username reservation, structured queries and document-level access rules. A custom server would add unnecessary operations at this stage. Firebase does not itself provide audio/video transport; that remains a separate WebRTC/media-provider integration.

## Delivery order

1. Register Android/Web apps, initialize FlutterFire, configure Google sign-in and authorized localhost origins. Preserve the working local build until configuration succeeds. Never commit CLI tokens or service-account credentials.
2. Authenticate before opening cloud account state. Display authenticated email/name. Scope caches and subscriptions by Firebase UID; cancel subscriptions and clear visible state on logout/account changes. Existing seeded contacts, messages and SOS records must not be silently uploaded into real accounts.
3. Reserve usernames atomically with profile creation. usernames/{normalized} maps to exactly one UID. Lowercase 3-20 letters/digits/underscores, immutable after claim; security rules enforce claim/profile consistency with getAfter. Authenticated users may look up a username, with directory responses limited to public profile fields. Private email/settings are owner-only.
4. Implement real friend request state transitions and participant-only chat subscriptions. Sender may create/cancel a pending request; recipient may accept/decline. Friendship must derive from mutual acceptance, never a unilateral client assertion. Messages have immutable sender/recipient, bounded text and server timestamps; only participants can read them.
5. Persist optimized cropped profile photos under avatars/{uid}/profile, owner-only writes, validated image content type and bounded optimized payload. Authenticated reads match username discovery visibility. Avoid publishing permanent bearer download URLs for private media. Keep settings/private activity owner-scoped.
6. SOS consent is separate from friendship. Recipient grants/revokes consent. Sender chooses favorites only among approved recipients. Server validates consent and friendship when activating SOS and fixes the authorized recipient list. FCM is dispatched by trusted server code using private device tokens, not arbitrary client-provided destinations. Status distinguishes queued/sent from acknowledged; offline actions never claim delivered. Test alerts use test accounts only.

## Rules and deployment

Default deny for unmatched paths. Enforce authentication, ownership, field allowlists/types, immutable identities and allowed state transitions. No public test-mode rules. Rule tests cover unauthenticated access, impersonation, cross-account reads, duplicate username race, unauthorized friend acceptance, revoked SOS consent and invalid media. Deploy only tested rules consistent with the client schema; preserve/export existing rules before replacement if any exist.

## Configuration decisions

Inspect existing databases, providers, buckets and billing first. Retain existing region/resources. If no database exists, select a region appropriate for the Pakistan user base after checking supported service regions; document the choice before provisioning because location is persistent. Do not enable paid billing or accept a paid plan without the user's decision. If Storage/Functions require billing, implement and test with emulators while clearly reporting deployment limits.

## Validation and completion evidence

Run analyzer and relevant Flutter tests, emulator authorization tests, web release build, and actual localhost Google sign-in through user-controlled authentication when required. Verify two real test accounts cannot access unrelated private data; test username conflict, requests/chat and logout/login persistence. Android physical-device Google sign-in and FCM delivery need a device and signing fingerprints; do not mark them verified based on web tests. Provide per-stage implemented/deployed/tested status rather than claiming all Firebase services work merely because initialization succeeds.
