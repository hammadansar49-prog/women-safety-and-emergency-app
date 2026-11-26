# SOS emergency flow

The home screen exposes an emergency dialer action independently of buddy approval. It requests the external handler for `tel:15`; the user completes the call in their phone dialer. Failure shows a manual-dial fallback. It does not initiate an AI telephone conversation, detect call connection or confirm police dispatch.

The existing SOS countdown, approved-buddy routing and permission-aware GPS tracking remain in place. Live Firebase delivery requires configured services and separate-device validation.

SOS no longer automatically starts camera/microphone streaming. During an active SOS, a cloud-connected user can explicitly allow camera and microphone sharing with approved buddies. OS permissions still apply. The UI reports that sharing is requested, not that recipients are connected. Stop sharing leaves SOS active; ending SOS stops media and tracking. Police audio relay is not implemented.

The agent-starter repository remains separate. Outbound AI telephony, supported emergency routing and audio bridging require a provider integration and controlled test-number validation before deployment. No real emergency calls are part of automated testing.
