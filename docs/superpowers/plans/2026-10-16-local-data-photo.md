# Profile photo and local persistence

User asks to upload a phone photo and retain messages/activity/photo across logout and login. Firebase remains deferred. Implement local persistence, explicitly distinguish it from cross-device authenticated sync.

Use gallery-only image_picker, decode bounded images to a 384px thumbnail, store image content per stable account ID, and offer remove/replace. Recover Android lost-picker data. Save a versioned snapshot of profiles, directed permissions, requests, messages, SOS events, settings and session state in Hive. Serialize writes to prevent stale snapshots winning; show save errors/retry, wait on logout, load before account UI, and preserve unreadable data instead of resetting it. Restore active local SOS owner controls without sending alerts. Keep all payloads local.

Verification: failing tests first, snapshot logout/reload tests, ordered save/error retry behavior, real database close/reopen test, valid thumbnail/invalid image tests, full regression suite, analysis, compiled web build and browser reload/logout verification. Device hardware picker verification remains outstanding until an Android phone is connected.
