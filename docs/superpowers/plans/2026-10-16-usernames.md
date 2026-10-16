# Unique username setup

Implement the user's requested first-login username gate in the existing local application.

Design: require a username before entering Home for a new account. Normalize by trimming and lowercasing; allow 3–20 ASCII letters, digits and underscores. Reject duplicates at save time and prohibit changing an already claimed username. Stable account IDs continue to own friendships and messages. Search uses the saved username and excludes unconfigured accounts. Returning configured accounts bypass setup.

The local controller represents session-only accounts, not Google authentication. Firebase integration must later derive UID from verified auth, atomically create usernames/{normalizedUsername} and update users/{uid}, and enforce ownership with server-side rules. An availability hint alone must never authorize a claim. No global reservation or persistence is claimed now.

- Write controller tests for normalization, collision, invalid input, and search/friend requests.
- Implement guarded local claims and a dedicated username setup form.
- Gate shell entry and cover first/returning account behavior with widget tests.
- Run full tests, analyzer, and web build; inspect localhost; push verified changes.
