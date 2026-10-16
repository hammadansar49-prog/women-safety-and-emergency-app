# Friends, chat and favorite SOS implementation plan

**Goal:** Make the user-requested flow usable locally while Firebase is deferred.

**Architecture:** One session-scoped SocialController owns demo profile identity, friend requests, directed favorite/consent relations, messages and local SOS events. ContactsScreen and ChatScreen render that state. EmergencyController retains countdown lifecycle and calls SocialController when the event activates/finishes.

- [x] Write domain tests for request acceptance, rejected unauthorized actions, favorite/consent-only SOS routing and chat isolation; run to confirm missing implementation.
- [x] Implement `lib/social_controller.dart` with immutable outward collections and validated transitions.
- [x] Implement `lib/contacts_screen.dart` with search, requests, friend list, exact 1500 ms hold recognizer and accessible menu; `lib/chat_screen.dart` with message composer, timestamped bubbles and explicit call preview.
- [x] Integrate profile switching, favorite recipients, incoming alerts and persistent SOS state into app shell. Prevent profile switching during own active countdown/event; allow switching after activation via explicit preview workflow by preserving owner identity.
- [x] Add gesture and full-flow widget tests, adapt existing empty-recipient expectations, then format/analyze/test/build.
- [x] Refresh localhost, verify rendered controls, update README/review status and push to main per user authorization.
