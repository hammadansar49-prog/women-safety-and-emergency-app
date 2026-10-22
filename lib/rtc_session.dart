import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_signaling.dart';

/// Public STUN servers. Phones on strict networks may also need a TURN relay;
/// add one here (or load it from the backend) when that shows up in testing.
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
  static Future<MediaStream?> captureFor(CallKind kind) => _capture(
    kind: kind,
    audio: true,
    video: kind != CallKind.audio,
  );

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
      // No camera or no permission: carry on without our own media, so the
      // other side can still be heard or seen.
      return null;
    }
  }

  Future<void> _createPc() async {
    final pc = await createPeerConnection({
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    });
    _pc = pc;
    pc.onIceCandidate = (c) {
      if (c.candidate == null) return;
      _signaling
          .addCandidate(callId, me, c.toMap() as Map<String, dynamic>)
          .catchError((Object _) {});
    };
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remote = event.streams.first;
        notifyListeners();
      }
    };
    pc.onConnectionState = (s) {
      switch (s) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _setState(RtcState.connected);
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _setState(RtcState.ended);
        default:
      }
    };
    pc.onDataChannel = _attachControl;
  }

  void _attachControl(RTCDataChannel channel) {
    _control = channel;
    channel.onMessage = (m) {
      if (!m.isBinary) _controlIn.add(m.text);
    };
  }

  void _listenSignaling() {
    _subs.add(
      _signaling.candidatesFrom(callId, peer).listen((c) async {
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
      }, onError: (Object _) {}),
    );
    _subs.add(
      _signaling.watch(callId).listen((doc) async {
        if (doc == null) return;
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
        }
      }, onError: (Object _) {}),
    );
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
    final s = RtcSession._(
      callId: callId,
      me: me,
      peer: peer,
      kind: kind,
      isCaller: true,
      signaling: signaling,
    );
    await s._createPc();
    if (shared != null) {
      s.local = shared;
      s._ownsLocal = false;
    } else {
      s.local = await captureFor(kind);
    }
    for (final track in s.local?.getTracks() ?? <MediaStreamTrack>[]) {
      await s._pc!.addTrack(track, s.local!);
    }
    if (kind == CallKind.sos) {
      final channel = await s._pc!.createDataChannel(
        'ctl',
        RTCDataChannelInit()..ordered = true,
      );
      s._attachControl(channel);
    }
    final offer = await s._pc!.createOffer({
      'offerToReceiveAudio': kind != CallKind.sos,
      'offerToReceiveVideo': kind == CallKind.video,
    });
    await s._pc!.setLocalDescription(offer);
    await signaling.create(
      id: callId,
      caller: me,
      callee: peer,
      kind: kind,
      offer: {'sdp': offer.sdp!, 'type': offer.type!},
    );
    s._listenSignaling();
    return s;
  }

  /// Picks up a ringing call, or joins an SOS live view as a watcher.
  static Future<RtcSession> answer({
    required CallDoc doc,
    required String me,
    required CallSignaling signaling,
  }) async {
    final s = RtcSession._(
      callId: doc.id,
      me: me,
      peer: doc.caller,
      kind: doc.kind,
      isCaller: false,
      signaling: signaling,
    );
    await s._createPc();
    // A watcher of an SOS only receives; a call answerer also sends.
    if (doc.kind != CallKind.sos) {
      s.local = await captureFor(doc.kind);
      for (final track in s.local?.getTracks() ?? <MediaStreamTrack>[]) {
        await s._pc!.addTrack(track, s.local!);
      }
    }
    await s._pc!.setRemoteDescription(
      RTCSessionDescription(doc.offer!['sdp'], doc.offer!['type']),
    );
    await s._remoteReady();
    final answer = await s._pc!.createAnswer();
    await s._pc!.setLocalDescription(answer);
    s._listenSignaling();
    await signaling.answer(doc.id, {
      'sdp': answer.sdp!,
      'type': answer.type!,
    });
    return s;
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
    if (state != RtcState.ended) {
      try {
        await _signaling.setStatus(
          callId,
          declined ? CallStatus.declined : CallStatus.ended,
        );
      } catch (_) {}
    }
    await close();
  }

  Future<void> close() async {
    if (_disposed) return;
    _setState(RtcState.ended);
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    if (_ownsLocal) {
      for (final t in local?.getTracks() ?? <MediaStreamTrack>[]) {
        await t.stop();
      }
      await local?.dispose();
    }
    await remote?.dispose();
    await _control?.close();
    await _pc?.close();
    _disposed = true;
    await _controlIn.close();
  }
}
