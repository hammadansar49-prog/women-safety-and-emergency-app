# Friends, chat and favorite SOS contacts

User clarification: send friend requests; open chats with audio/video call controls; hold a friend for 1.5 seconds to offer Add to favorite SOS contact; route SOS only to selected favorite contacts. User explicitly deferred Firebase. Build an interactive in-process preview, not network communication.

Use three labelled demo profiles and a profile switcher so request acceptance, replies and SOS receipt can be exercised honestly without a server. Friendship requires acceptance. A sender can favorite an accepted friend using the 1.5-second gesture or accessible menu; this creates a separate SOS permission request. Recipient approval enables emergency routing. Unselected friends never receive SOS; revocation removes active access. Explain pending consent clearly.

Split domain state, contacts UI and chat UI. Local chat stores timestamped messages shared by the two demo profiles. Audio/video buttons open a preview call screen explicitly saying no media connection exists; do not claim connected or activate camera/mic. Profile switches expose only the selected profile's conversations and requests. UI state is memory-only until persistence/backend work.

SOS uses the favorite/approved recipients at activation, records an immutable recipient snapshot, and offers visible state/stop controls outside Home. No favorites means a clear setup message instead of starting an empty SOS. Incoming local SOS is visible when switching to a recipient profile. Cancellation/resolution updates recipients' event state. Existing countdown and duplicate protection remain.

Test friend request authorization/duplicates, mutual confirmation, favorite-only recipients, revocation, message isolation, exact long-hold timing and cancellation, and end-to-end local SOS. Run analyzer, tests and build; update localhost and push the verified implementation.
