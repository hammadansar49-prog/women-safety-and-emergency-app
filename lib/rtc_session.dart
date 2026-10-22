import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_signaling.dart';

/// STUN discovers direct routes. Carrier/strict NAT networks require an
/// authenticated TURN relay with short-lived credentials from a backend.
/// No public relay credentials are bundled in the application.
const iceServers = <Map<String, dynamic>>[
  {'urls': 'stun:stun.l.google.com:19302'},
  {'urls': 'stun:stun1.l.google.com:19302'},
];

enum RtcState { connecting, connected, ended }

/// One peer-to-peer connection for a call or an SOS live view.
///
/// The caller offers and sends media; the callee answers. In an SOS live view
/// the caller (the person in danger) only sends and the buddy only watches, and
/// the buddy can ask the sender's phone to switch cameras over a small control
/// channel.
class RtcSession extends ChangeNotifier {
  RtcSession._({
    required this.callId,
    required this.me,
    required this.peer,
    required this.kind,
    required this.isCaller,
    required CallSignaling signaling,
  }) : _signaling = signaling;

  final String callId;
  final String me;
  final String peer;
  final CallKind kind;
  final bool isCaller;
  final CallSignaling _signaling;

  RTCPeerConnection? _pc;
  MediaStream? local;
  MediaStream? remote;
  RTCDataChannel? _control;
  final _subs = <StreamSubscription<dynamic>>[];
  final _pendingCandidates = <RTCIceCandidate>[];
  bool _remoteSet = false;
  bool _disposed = false;
  bool _ownsLocal = true;
  bool _published = false;
  final _localCandidates = <Map<String, dynamic>>[];
  Timer? _ringTimeout;
  String? error;

  RtcState state = RtcState.connecting;
  bool micOn = true;
  bool cameraOn = true;
  bool get hasVideo => kind != CallKind.audio;

  /// Messages from the other side's control channel ("switch").
  final _controlIn = StreamController<String>.broadcast();
  Stream<String> get controlMessages => _controlIn.stream;

  void _setState(RtcState next) {
    if (state == next || _disposed) return;
    state = next;
    notifyListeners();
  }

  /// Opens the camera and microphone for [kind]; null if that is not possible.
  static Future<MediaStream?> captureFor(CallKind kind) =>
      _capture(kind: kind, audio: true, video: kind != CallKind.audio);

  static Future<MediaStream?> _capture({
    required CallKind kind,
    required bool audio,
    required bool video,
  }) async {
    if (!audio && !video) return null;
    try {
      return await navigator.mediaDevices.getUserMedia({
        'audio': audio
            ? {'echoCancellation': true, 'noiseSuppression': true}
            : false,
        'video': video
            ? {
                // SOS shows the surroundings first; a buddy can flip it.
                'facingMode': kind == CallKind.sos ? 'environment' : 'user',
                'width': {'ideal': 640},
                'height': {'ideal': 480},
                'frameRate': {'ideal': 24},
              }
            : false,
      });
    } catch (_) {
      // Capture callers decide whether media is required. Ordinary call
      // setup reports this as a permission/device error instead of silently
      // placing a call without a microphone.
      return null;
    }
  }

  Future<void> _createPc() async {
    final pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });
    if (_disposed) {
      try {
        await pc.close();
      } finally {
        await pc.dispose();
      }
      throw StateError('Call cancelled');
    }
    _pc = pc;
    pc.onIceCandidate = (c) {
      if (c.candidate == null || _disposed) return;
      // Firestore rules require the parent call to exist before candidates.
      if (!_published) {
        _localCandidates.add(c.toMap() as Map<String, dynamic>);
        return;
      }
      _signaling
          .addCandidate(callId, me, c.toMap() as Map<String, dynamic>)
          .catchError((Object _) {});
    };
    pc.onTrack = (event) {
      if (_disposed) return;
      if (event.streams.isNotEmpty) {
        remote = event.streams.first;
        notifyListeners();
      }
    };
    pc.onConnectionState = (s) {
      switch (s) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _ringTimeout?.cancel();
          _setState(RtcState.connected);
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          _fail('The call could not connect. Try another network.');
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _setState(RtcState.ended);
        default:
      }
    };
    pc.onDataChannel = _attachControl;
  }

  void _attachControl(RTCDataChannel channel) {
    if (_disposed) {
      unawaited(channel.close());
      return;
    }
    _control = channel;
    channel.onMessage = (m) {
      if (!m.isBinary && !_disposed) _controlIn.add(m.text);
    };
  }

  void _listenSignaling() {
    _subs.add(
      _signaling.candidatesFrom(callId, peer).listen(
        (c) async {
          if (_disposed) return;
          try {
            final candidate = RTCIceCandidate(
              c['candidate'] as String?,
              c['sdpMid'] as String?,
              c['sdpMLineIndex'] as int?,
            );
            if (_remoteSet) {
              await _pc?.addCandidate(candidate);
            } else {
              _pendingCandidates.add(candidate);
            }
          } catch (_) {
            _fail('Call network information could not be exchanged.');
          }
        },
        onError: (Object _) =>
            _fail('Call signaling disconnected. Check your connection.'),
      ),
    );
    _subs.add(
      _signaling.watch(callId).listen(
        (doc) async {
          if (doc == null || _disposed) return;
          try {
            if (isCaller &&
                doc.answer != null &&
                !_remoteSet &&
                doc.status == CallStatus.active) {
              await _pc?.setRemoteDescription(
                RTCSessionDescription(doc.answer!['sdp'], doc.answer!['type']),
              );
              await _remoteReady();
            }
            if (doc.status == CallStatus.ended ||
                doc.status == CallStatus.declined) {
              _setState(RtcState.ended);
              unawaited(close());
            }
          } catch (_) {
            _fail('The call could not connect. Please try again.');
          }
        },
        onError: (Object _) =>
            _fail('Call signaling disconnected. Check your connection.'),
      ),
    );
  }

  void _fail(String message) {
    if (_disposed) return;
    error = message;
    _setState(RtcState.ended);
    unawaited(hangUp());
  }

  void _ensureOpen() {
    if (_disposed) throw StateError('Call cancelled');
  }

  Future<void> _captureLocal() async {
    var media = await captureFor(kind);
    // A blocked or busy camera must not take the whole call down: a video
    // call that can still be heard is worth far more than no call at all.
    if (media == null && kind == CallKind.video) {
      media = await _capture(kind: kind, audio: true, video: false);
      if (media != null) cameraOn = false;
    }
    if (_disposed) {
      for (final track in media?.getTracks() ?? <MediaStreamTrack>[]) {
        await track.stop();
      }
      await media?.dispose();
      throw StateError('Call cancelled');
    }
    if (media == null) throw StateError('Microphone unavailable');
    local = media;
    // Apply controls tapped while permission/native setup was pending.
    setMic(micOn);
    setCamera(cameraOn);
  }

  Future<void> _publishCandidates() async {
    _published = true;
    for (final candidate in _localCandidates) {
      _ensureOpen();
      await _signaling.addCandidate(callId, me, candidate);
    }
    _localCandidates.clear();
  }

  factory RtcSession.outgoing({
    required String callId,
    required String me,
    required String peer,
    required CallKind kind,
    required CallSignaling signaling,
  }) => RtcSession._(
    callId: callId,
    me: me,
    peer: peer,
    kind: kind,
    isCaller: true,
    signaling: signaling,
  );

  factory RtcSession.incoming({
    required CallDoc doc,
    required String me,
    required CallSignaling signaling,
  }) => RtcSession._(
    callId: doc.id,
    me: me,
    peer: doc.caller,
    kind: doc.kind,
    isCaller: false,
    signaling: signaling,
  );

  Future<void> startOutgoing({MediaStream? shared}) =>
      _startOutgoing(shared: shared).timeout(const Duration(seconds: 30));

  Future<void> _startOutgoing({MediaStream? shared}) async {
    await _createPc();
    _ensureOpen();
    if (shared != null) {
      local = shared;
      _ownsLocal = false;
    } else {
      await _captureLocal();
    }
    _ensureOpen();
    for (final track in local?.getTracks() ?? <MediaStreamTrack>[]) {
      _ensureOpen();
      await _pc!.addTrack(track, local!);
    }
    if (kind == CallKind.sos) {
      final channel = await _pc!.createDataChannel(
        'ctl',
        RTCDataChannelInit()..ordered = true,
      );
      _ensureOpen();
      _attachControl(channel);
    }
    final offer = await _pc!.createOffer({
      'offerToReceiveAudio': kind != CallKind.sos,
      'offerToReceiveVideo': kind == CallKind.video,
    });
    _ensureOpen();
    await _pc!.setLocalDescription(offer);
    _ensureOpen();
    await _signaling.create(
      id: callId,
      caller: me,
      callee: peer,
      kind: kind,
      offer: {'sdp': offer.sdp!, 'type': offer.type!},
    );
    if (_disposed) {
      // An offline Firestore write can finish after the user cancels.
      await _signaling.setStatus(callId, CallStatus.ended);
      throw StateError('Call cancelled');
    }
    await _publishCandidates();
    _ensureOpen();
    _listenSignaling();
    if (kind != CallKind.sos && state != RtcState.connected) {
      _ringTimeout = Timer(const Duration(seconds: 60), () {
        _fail('The call was not answered.');
      });
    }
  }

  Future<void> startIncoming(CallDoc doc) =>
      _startIncoming(doc).timeout(const Duration(seconds: 30));

  Future<void> _startIncoming(CallDoc doc) async {
    if (doc.offer == null || doc.status != CallStatus.ringing) {
      throw StateError('Call no longer available');
    }
    await _createPc();
    _ensureOpen();
    _published = true; // The caller has already created this document.
    if (doc.kind != CallKind.sos) {
      await _captureLocal();
      for (final track in local!.getTracks()) {
        _ensureOpen();
        await _pc!.addTrack(track, local!);
      }
    }
    _ensureOpen();
    await _pc!.setRemoteDescription(
      RTCSessionDescription(doc.offer!['sdp'], doc.offer!['type']),
    );
    _ensureOpen();
    await _remoteReady();
    final answer = await _pc!.createAnswer();
    _ensureOpen();
    await _pc!.setLocalDescription(answer);
    _ensureOpen();
    _listenSignaling();
    await _signaling.answer(doc.id, {'sdp': answer.sdp!, 'type': answer.type!});
    _ensureOpen();
  }

  Future<void> _remoteReady() async {
    _remoteSet = true;
    for (final c in _pendingCandidates) {
      await _pc?.addCandidate(c);
    }
    _pendingCandidates.clear();
  }

  /// Starts a call (or an SOS live view) and rings [peer].
  static Future<RtcSession> dial({
    required String callId,
    required String me,
    required String peer,
    required CallKind kind,
    required CallSignaling signaling,

    /// An already open camera/microphone to send, shared between several
    /// connections. The caller then stops it, not this session.
    MediaStream? shared,
  }) async {
    final s = RtcSession.outgoing(
      callId: callId,
      me: me,
      peer: peer,
      kind: kind,
      signaling: signaling,
    );
    try {
      await s.startOutgoing(shared: shared);
      return s;
    } catch (_) {
      await s.hangUp();
      rethrow;
    }
  }

  /// Picks up a ringing call, or joins an SOS live view as a watcher.
  static Future<RtcSession> answer({
    required CallDoc doc,
    required String me,
    required CallSignaling signaling,
  }) async {
    final s = RtcSession.incoming(doc: doc, me: me, signaling: signaling);
    try {
      await s.startIncoming(doc);
      return s;
    } catch (_) {
      await s.hangUp();
      rethrow;
    }
  }

  // --- Controls -------------------------------------------------------------

  void setMic(bool on) {
    micOn = on;
    for (final t in local?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = on;
    }
    notifyListeners();
  }

  void setCamera(bool on) {
    cameraOn = on;
    for (final t in local?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      t.enabled = on;
    }
    notifyListeners();
  }

  Future<void> switchCamera() async {
    final tracks = local?.getVideoTracks() ?? [];
    if (tracks.isNotEmpty) await Helper.switchCamera(tracks.first);
  }

  /// A watcher asking the sender's phone to flip front/back.
  void requestSwitch() => _control?.send(RTCDataChannelMessage('switch'));

  /// Hangs up, tells the other side, and releases the camera and microphone.
  Future<void> hangUp({bool declined = false}) async {
    final publishEnd = _published;
    // Release local resources immediately, including a pending setup. Network
    // writes may wait for connectivity and must not keep a call alive.
    await close();
    if (publishEnd) {
      try {
        await _signaling
            .setStatus(
              callId,
              declined ? CallStatus.declined : CallStatus.ended,
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
  }

  Future<void> close() async {
    if (_disposed) return;
    _disposed = true;
    _ringTimeout?.cancel();
    // Candidates buffered for a flush belong to a connection that is over.
    _signaling.forget(callId);
    _localCandidates.clear();
    state = RtcState.ended;
    notifyListeners();
    Future<void> release(Future<void> Function() action) async {
      try {
        await action();
      } catch (_) {
        // A platform resource may already be gone; release the others too.
      }
    }

    for (final s in _subs) {
      await release(s.cancel);
    }
    _subs.clear();
    if (_ownsLocal) {
      for (final t in local?.getTracks() ?? <MediaStreamTrack>[]) {
        await release(t.stop);
      }
      if (local != null) await release(local!.dispose);
    }
    if (remote != null) await release(remote!.dispose);
    if (_control != null) await release(_control!.close);
    if (_pc != null) {
      await release(_pc!.close);
      await release(_pc!.dispose);
    }
    await _controlIn.close();
  }
}
